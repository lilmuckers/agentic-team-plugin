"""
Task Ledger MCP Server

Implements the canonical task-state surface described in docs/proposal/task-ledger-mcp.md.
Exposes nine MCP tools over SSE transport backed by PostgreSQL.

Tools:
  task_create         — create a new task
  task_get            — fetch one task by id
  task_list           — query tasks with filters
  task_update         — patch mutable descriptive fields (optimistic concurrency)
  task_transition     — lifecycle state transition (optimistic concurrency)
  task_invalidate     — soft-delete (no hard deletes)
  task_add_note       — attach a free-text note
  task_link_artifact  — attach a durable artifact reference
  task_history        — full history for one task
"""

import json
import re
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from typing import Any, Optional

from mcp.server.fastmcp import FastMCP

from . import database as db
from .config import settings

# ---------------------------------------------------------------------------
# Valid enumeration sets (from docs/proposal/schemas/reason-codes.json)
# ---------------------------------------------------------------------------

VALID_STATES = {
    "new", "triage", "specifying", "ready_for_build", "building",
    "reviewing", "security_review", "qa_review", "release_pending",
    "blocked", "done", "invalid",
}
VALID_KINDS = {"feature", "bug", "change", "chore", "spike", "release", "triage", "meta"}
VALID_PRIORITIES = {"low", "medium", "high", "critical"}
VALID_ARTIFACT_KINDS = {
    "issue", "pr", "branch", "commit", "wiki", "decision-record", "release",
}

# ---------------------------------------------------------------------------
# App with lifespan
# ---------------------------------------------------------------------------


@asynccontextmanager
async def lifespan(server: FastMCP):
    await db.get_pool()  # initialises pool and runs schema migrations
    yield
    await db.close_pool()


mcp = FastMCP(
    "Task Ledger MCP",
    lifespan=lifespan,
    host=settings.host,
    port=settings.port,
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _slug(project: str) -> str:
    """Convert a project name to a safe task-id slug."""
    return re.sub(r"[^a-z0-9]+", "_", project.lower().strip()).strip("_")


def _safe(val: Any) -> Any:
    """Recursively convert types that are not JSON-serialisable."""
    if val is None:
        return None
    if isinstance(val, datetime):
        return val.isoformat()
    if isinstance(val, dict):
        return {k: _safe(v) for k, v in val.items()}
    if isinstance(val, (list, tuple)):
        return [_safe(v) for v in val]
    return val


def _row(record) -> dict | None:
    if record is None:
        return None
    return _safe(dict(record))


def _rows(records) -> list[dict]:
    return [_safe(dict(r)) for r in records]


async def _next_task_id(conn, project: str) -> str:
    """Atomically allocate the next sequence number for a project."""
    result = await conn.fetchrow(
        """
        WITH updated AS (
            INSERT INTO task_counters (project, next_seq)
            VALUES ($1, 2)
            ON CONFLICT (project) DO UPDATE
                SET next_seq = task_counters.next_seq + 1
            RETURNING next_seq
        )
        SELECT next_seq - 1 AS seq FROM updated
        """,
        project,
    )
    return f"task_{_slug(project)}_{result['seq']:04d}"


# ---------------------------------------------------------------------------
# Tools
# ---------------------------------------------------------------------------


@mcp.tool()
async def task_create(
    project: str,
    kind: str,
    title: str,
    state: str = "new",
    priority: Optional[str] = None,
    owner_agent_type: Optional[str] = None,
    owner_agent_id: Optional[str] = None,
    source_kind: Optional[str] = None,
    source_id: Optional[str] = None,
    issue_number: Optional[int] = None,
    pr_number: Optional[int] = None,
    branch: Optional[str] = None,
    next_action: Optional[str] = None,
    expected_callback_at: Optional[str] = None,
    idempotency_key: Optional[str] = None,
) -> dict:
    """
    Create a new task in the ledger.

    Returns task_id and created_at. If idempotency_key is provided and a task
    with that key already exists, the existing task_id is returned with
    idempotent=true — no duplicate is created.
    """
    if kind not in VALID_KINDS:
        raise ValueError(f"Invalid kind '{kind}'. Must be one of: {sorted(VALID_KINDS)}")
    if state not in VALID_STATES:
        raise ValueError(f"Invalid state '{state}'. Must be one of: {sorted(VALID_STATES)}")
    if priority and priority not in VALID_PRIORITIES:
        raise ValueError(f"Invalid priority '{priority}'. Must be one of: {sorted(VALID_PRIORITIES)}")

    exp_cb = datetime.fromisoformat(expected_callback_at) if expected_callback_at else None
    pool = await db.get_pool()

    async with pool.acquire() as conn:
        async with conn.transaction():
            if idempotency_key:
                existing = await conn.fetchrow(
                    "SELECT task_id, created_at FROM tasks WHERE idempotency_key = $1",
                    idempotency_key,
                )
                if existing:
                    return {
                        "task_id": existing["task_id"],
                        "created_at": existing["created_at"].isoformat(),
                        "idempotent": True,
                    }

            task_id = await _next_task_id(conn, project)

            record = await conn.fetchrow(
                """
                INSERT INTO tasks (
                    task_id, project, kind, title, state, priority,
                    owner_agent_type, owner_agent_id,
                    source_kind, source_id,
                    issue_number, pr_number, branch,
                    next_action, expected_callback_at, idempotency_key
                ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16)
                RETURNING task_id, created_at
                """,
                task_id, project, kind, title, state, priority,
                owner_agent_type, owner_agent_id,
                source_kind, source_id,
                issue_number, pr_number, branch,
                next_action, exp_cb, idempotency_key,
            )

            await conn.execute(
                """
                INSERT INTO task_history
                    (task_id, event_type, to_state, actor_type, actor_id, payload_json)
                VALUES ($1, 'task.created', $2, $3, $4, $5)
                """,
                task_id, state, owner_agent_type, owner_agent_id,
                {"kind": kind, "title": title, "priority": priority},
            )

    return {
        "task_id": record["task_id"],
        "created_at": record["created_at"].isoformat(),
    }


@mcp.tool()
async def task_get(task_id: str) -> dict:
    """Fetch a single task by ID, including all fields."""
    pool = await db.get_pool()
    async with pool.acquire() as conn:
        record = await conn.fetchrow("SELECT * FROM tasks WHERE task_id = $1", task_id)
    if not record:
        raise ValueError(f"Task not found: {task_id}")
    return _row(record)


@mcp.tool()
async def task_list(
    project: Optional[str] = None,
    state: Optional[str] = None,
    kind: Optional[str] = None,
    owner_agent_type: Optional[str] = None,
    owner_agent_id: Optional[str] = None,
    priority: Optional[str] = None,
    issue_number: Optional[int] = None,
    overdue: Optional[bool] = None,
    include_invalid: bool = False,
    limit: int = 100,
    offset: int = 0,
) -> str:
    """
    Query tasks with optional filters. Returns a JSON array string.

    Filters: project, state, kind, owner_agent_type, owner_agent_id, priority,
    issue_number, overdue (expected_callback_at < now and not terminal).
    Invalid tasks are excluded by default; set include_invalid=true to include them.
    """
    clauses: list[str] = []
    params: list[Any] = []
    i = 1

    if not include_invalid:
        clauses.append("state != 'invalid'")

    def add_filter(col: str, val: Any) -> None:
        nonlocal i
        clauses.append(f"{col} = ${i}")
        params.append(val)
        i += 1

    if project is not None:
        add_filter("project", project)
    if state is not None:
        add_filter("state", state)
    if kind is not None:
        add_filter("kind", kind)
    if owner_agent_type is not None:
        add_filter("owner_agent_type", owner_agent_type)
    if owner_agent_id is not None:
        add_filter("owner_agent_id", owner_agent_id)
    if priority is not None:
        add_filter("priority", priority)
    if issue_number is not None:
        add_filter("issue_number", issue_number)
    if overdue:
        clauses.append(
            "expected_callback_at < NOW() AND state NOT IN ('done', 'invalid', 'blocked')"
        )

    where = f"WHERE {' AND '.join(clauses)}" if clauses else ""
    params.extend([limit, offset])
    query = (
        f"SELECT * FROM tasks {where} "
        f"ORDER BY created_at DESC LIMIT ${i} OFFSET ${i + 1}"
    )

    pool = await db.get_pool()
    async with pool.acquire() as conn:
        records = await conn.fetch(query, *params)
    # Return as a JSON string so FastMCP emits a single TextContent block
    # (returning list[dict] produces one TextContent per row)
    return json.dumps(_rows(records))


@mcp.tool()
async def task_update(
    task_id: str,
    revision: int,
    title: Optional[str] = None,
    priority: Optional[str] = None,
    owner_agent_type: Optional[str] = None,
    owner_agent_id: Optional[str] = None,
    next_action: Optional[str] = None,
    expected_callback_at: Optional[str] = None,
    issue_number: Optional[int] = None,
    pr_number: Optional[int] = None,
    branch: Optional[str] = None,
    source_kind: Optional[str] = None,
    source_id: Optional[str] = None,
) -> dict:
    """
    Patch mutable descriptive fields without changing lifecycle state.

    Requires the current revision for optimistic concurrency — if revision does
    not match the stored value the update is rejected.
    """
    sets = ["updated_at = NOW()", "revision = revision + 1"]
    params: list[Any] = []
    i = 1
    changed_fields: list[str] = []

    def add_set(col: str, val: Any) -> None:
        nonlocal i
        sets.append(f"{col} = ${i}")
        params.append(val)
        changed_fields.append(col)
        i += 1

    if title is not None:
        add_set("title", title)
    if priority is not None:
        add_set("priority", priority)
    if owner_agent_type is not None:
        add_set("owner_agent_type", owner_agent_type)
    if owner_agent_id is not None:
        add_set("owner_agent_id", owner_agent_id)
    if next_action is not None:
        add_set("next_action", next_action)
    if expected_callback_at is not None:
        add_set("expected_callback_at", datetime.fromisoformat(expected_callback_at))
    if issue_number is not None:
        add_set("issue_number", issue_number)
    if pr_number is not None:
        add_set("pr_number", pr_number)
    if branch is not None:
        add_set("branch", branch)
    if source_kind is not None:
        add_set("source_kind", source_kind)
    if source_id is not None:
        add_set("source_id", source_id)

    if not changed_fields:
        raise ValueError("No fields to update")

    params.extend([task_id, revision])
    query = (
        f"UPDATE tasks SET {', '.join(sets)} "
        f"WHERE task_id = ${i} AND revision = ${i + 1} RETURNING *"
    )

    pool = await db.get_pool()
    async with pool.acquire() as conn:
        async with conn.transaction():
            record = await conn.fetchrow(query, *params)
            if not record:
                existing = await conn.fetchrow(
                    "SELECT revision FROM tasks WHERE task_id = $1", task_id
                )
                if not existing:
                    raise ValueError(f"Task not found: {task_id}")
                raise ValueError(
                    f"Revision mismatch for {task_id}: "
                    f"expected {revision}, current is {existing['revision']}"
                )
            await conn.execute(
                """
                INSERT INTO task_history
                    (task_id, event_type, actor_type, actor_id, payload_json)
                VALUES ($1, 'task.updated', $2, $3, $4)
                """,
                task_id, owner_agent_type, owner_agent_id,
                {"changedFields": changed_fields},
            )

    return _row(record)


@mcp.tool()
async def task_transition(
    task_id: str,
    from_state: str,
    to_state: str,
    revision: int,
    reason_code: Optional[str] = None,
    summary: Optional[str] = None,
    next_action: Optional[str] = None,
    owner_agent_type: Optional[str] = None,
    owner_agent_id: Optional[str] = None,
) -> dict:
    """
    Transition a task to a new lifecycle state.

    Requires from_state (must match current state) and revision for optimistic
    concurrency. Both checks must pass or the transition is rejected.
    """
    if to_state not in VALID_STATES:
        raise ValueError(f"Invalid to_state '{to_state}'. Must be one of: {sorted(VALID_STATES)}")

    sets = ["state = $1", "updated_at = NOW()", "revision = revision + 1"]
    params: list[Any] = [to_state]
    i = 2

    def add_set(col: str, val: Any) -> None:
        nonlocal i
        sets.append(f"{col} = ${i}")
        params.append(val)
        i += 1

    if next_action is not None:
        add_set("next_action", next_action)
    if owner_agent_type is not None:
        add_set("owner_agent_type", owner_agent_type)
    if owner_agent_id is not None:
        add_set("owner_agent_id", owner_agent_id)
    if to_state == "done":
        add_set("completed_at", datetime.now(timezone.utc))

    params.extend([task_id, from_state, revision])
    query = (
        f"UPDATE tasks SET {', '.join(sets)} "
        f"WHERE task_id = ${i} AND state = ${i + 1} AND revision = ${i + 2} "
        f"RETURNING *"
    )

    pool = await db.get_pool()
    async with pool.acquire() as conn:
        async with conn.transaction():
            record = await conn.fetchrow(query, *params)
            if not record:
                existing = await conn.fetchrow(
                    "SELECT state, revision FROM tasks WHERE task_id = $1", task_id
                )
                if not existing:
                    raise ValueError(f"Task not found: {task_id}")
                raise ValueError(
                    f"Transition rejected for {task_id}: "
                    f"expected state={from_state!r} revision={revision}, "
                    f"got state={existing['state']!r} revision={existing['revision']}"
                )
            await conn.execute(
                """
                INSERT INTO task_history
                    (task_id, event_type, from_state, to_state, summary,
                     reason_code, actor_type, actor_id, payload_json)
                VALUES ($1, 'task.transitioned', $2, $3, $4, $5, $6, $7, $8)
                """,
                task_id, from_state, to_state, summary, reason_code,
                owner_agent_type, owner_agent_id,
                {"nextAction": next_action},
            )

    return _row(record)


@mcp.tool()
async def task_invalidate(
    task_id: str,
    reason_code: str,
    summary: Optional[str] = None,
    actor_type: Optional[str] = None,
    actor_id: Optional[str] = None,
) -> dict:
    """
    Soft-delete a task by marking it invalid.

    Tasks are never hard-deleted. Invalid tasks are excluded from task_list
    by default but remain visible with include_invalid=true.
    """
    pool = await db.get_pool()
    async with pool.acquire() as conn:
        async with conn.transaction():
            record = await conn.fetchrow(
                """
                UPDATE tasks
                SET state = 'invalid',
                    invalidated_at = NOW(),
                    invalidation_reason = $2,
                    updated_at = NOW(),
                    revision = revision + 1
                WHERE task_id = $1 AND state != 'invalid'
                RETURNING *
                """,
                task_id, reason_code,
            )
            if not record:
                existing = await conn.fetchrow(
                    "SELECT state FROM tasks WHERE task_id = $1", task_id
                )
                if not existing:
                    raise ValueError(f"Task not found: {task_id}")
                raise ValueError(f"Task {task_id} is already invalid")

            await conn.execute(
                """
                INSERT INTO task_history
                    (task_id, event_type, to_state, summary, reason_code,
                     actor_type, actor_id, payload_json)
                VALUES ($1, 'task.invalidated', 'invalid', $2, $3, $4, $5, '{}')
                """,
                task_id, summary, reason_code, actor_type, actor_id,
            )

    return _row(record)


@mcp.tool()
async def task_add_note(
    task_id: str,
    note: str,
    author_type: Optional[str] = None,
    author_id: Optional[str] = None,
) -> dict:
    """Add a human-readable note to a task without changing its state."""
    pool = await db.get_pool()
    async with pool.acquire() as conn:
        async with conn.transaction():
            exists = await conn.fetchval(
                "SELECT 1 FROM tasks WHERE task_id = $1", task_id
            )
            if not exists:
                raise ValueError(f"Task not found: {task_id}")

            record = await conn.fetchrow(
                """
                INSERT INTO task_notes (task_id, note, author_type, author_id)
                VALUES ($1, $2, $3, $4)
                RETURNING *
                """,
                task_id, note, author_type, author_id,
            )
            await conn.execute(
                """
                INSERT INTO task_history
                    (task_id, event_type, actor_type, actor_id, payload_json)
                VALUES ($1, 'task.note.added', $2, $3, $4)
                """,
                task_id, author_type, author_id, {"noteId": record["id"]},
            )

    return _row(record)


@mcp.tool()
async def task_link_artifact(
    task_id: str,
    artifact_kind: str,
    artifact_ref: str,
    url: Optional[str] = None,
    metadata_json: Optional[str] = None,
) -> dict:
    """
    Attach a durable artifact reference to a task.

    artifact_kind must be one of: issue, pr, branch, commit, wiki,
    decision-record, release.
    metadata_json is an optional JSON string for extra fields.
    """
    if artifact_kind not in VALID_ARTIFACT_KINDS:
        raise ValueError(
            f"Invalid artifact_kind '{artifact_kind}'. "
            f"Must be one of: {sorted(VALID_ARTIFACT_KINDS)}"
        )
    meta = json.loads(metadata_json) if metadata_json else {}

    pool = await db.get_pool()
    async with pool.acquire() as conn:
        async with conn.transaction():
            exists = await conn.fetchval(
                "SELECT 1 FROM tasks WHERE task_id = $1", task_id
            )
            if not exists:
                raise ValueError(f"Task not found: {task_id}")

            record = await conn.fetchrow(
                """
                INSERT INTO task_artifacts
                    (task_id, artifact_kind, artifact_ref, url, metadata_json)
                VALUES ($1, $2, $3, $4, $5)
                RETURNING *
                """,
                task_id, artifact_kind, artifact_ref, url, meta,
            )
            await conn.execute(
                """
                INSERT INTO task_history
                    (task_id, event_type, actor_type, actor_id, payload_json)
                VALUES ($1, 'task.artifact.linked', 'system', NULL, $2)
                """,
                task_id,
                {"artifactKind": artifact_kind, "artifactRef": artifact_ref},
            )

    return _row(record)


@mcp.tool()
async def task_history(task_id: str) -> str:
    """
    Return the complete history for one task: task record, state transitions,
    notes, and linked artifacts — all in chronological order.
    """
    pool = await db.get_pool()
    async with pool.acquire() as conn:
        task = await conn.fetchrow("SELECT * FROM tasks WHERE task_id = $1", task_id)
        if not task:
            raise ValueError(f"Task not found: {task_id}")

        history = await conn.fetch(
            "SELECT * FROM task_history WHERE task_id = $1 ORDER BY created_at ASC",
            task_id,
        )
        notes = await conn.fetch(
            "SELECT * FROM task_notes WHERE task_id = $1 ORDER BY created_at ASC",
            task_id,
        )
        artifacts = await conn.fetch(
            "SELECT * FROM task_artifacts WHERE task_id = $1 ORDER BY created_at ASC",
            task_id,
        )

    return json.dumps({
        "task": _row(task),
        "history": _rows(history),
        "notes": _rows(notes),
        "artifacts": _rows(artifacts),
    })


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------


def main() -> None:
    mcp.run(transport="sse")
