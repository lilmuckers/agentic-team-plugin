"""
Task Ledger MCP Server

Exposes thirteen MCP tools over SSE transport backed by PostgreSQL.

Project tools:
  project_create       — bootstrap a new project ledger record
  project_get          — fetch one project by id or slug (no token returned)
  project_list         — list all projects (no tokens returned)
  project_rotate_token — rotate the project write secret

Task tools:
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

import hashlib
import json
import secrets
import uuid as _uuid_mod
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from typing import Any, Optional

from mcp.server.fastmcp import FastMCP
from starlette.requests import Request
from starlette.responses import JSONResponse, Response

from . import database as db
from .config import settings

# ---------------------------------------------------------------------------
# Structured error type
# ---------------------------------------------------------------------------


class ToolError(Exception):
    """
    Raise from any tool to produce a structured JSON error payload.

    FastMCP catches this and sets isError=true on the CallToolResult; the
    str() of this exception becomes the text content — a JSON object with
    error_code and message fields that clients can parse without string matching.

    Canonical codes: invalid_token, project_not_found, task_not_found,
    revision_mismatch, already_invalid, validation_error, duplicate_slug.
    """

    def __init__(self, code: str, message: str) -> None:
        self.code = code
        self.message = message
        super().__init__(json.dumps({"error_code": code, "message": message}))


# ---------------------------------------------------------------------------
# Valid enumeration sets
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
    await db.get_pool()
    yield
    await db.close_pool()


mcp = FastMCP(
    "Task Ledger MCP",
    lifespan=lifespan,
    host=settings.host,
    port=settings.port,
)

# ---------------------------------------------------------------------------
# Health endpoint
# ---------------------------------------------------------------------------


@mcp.custom_route("/health", methods=["GET"])
async def health_check(_request: Request) -> Response:
    """Liveness + database-connectivity probe for Docker healthchecks."""
    try:
        pool = await db.get_pool()
        async with pool.acquire() as conn:
            await conn.fetchval("SELECT 1")
        return JSONResponse({"status": "ok", "database": "ok"})
    except Exception as exc:
        return JSONResponse({"status": "error", "detail": str(exc)}, status_code=503)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _safe(val: Any) -> Any:
    """Recursively convert types that are not JSON-serialisable."""
    if val is None:
        return None
    if isinstance(val, datetime):
        return val.isoformat()
    if isinstance(val, _uuid_mod.UUID):
        return str(val)
    if isinstance(val, dict):
        return {k: _safe(v) for k, v in val.items()}
    if isinstance(val, (list, tuple)):
        return [_safe(v) for v in val]
    return val


def _row(record) -> dict:
    return _safe(dict(record))


def _rows(records) -> list[dict]:
    return [_safe(dict(r)) for r in records]


def _hash_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


async def _validate_token(conn, project_id: str, token: str) -> None:
    """Raise ToolError if project_token does not match the stored hash."""
    record = await conn.fetchrow(
        "SELECT project_token_hash FROM projects WHERE project_id = $1",
        _uuid_mod.UUID(project_id),
    )
    if not record:
        raise ToolError("project_not_found", f"Project not found: {project_id}")
    if record["project_token_hash"] != _hash_token(token):
        raise ToolError("invalid_token", "Invalid project_token")


async def _resolve_project_uuid(
    conn, project_id: Optional[str], project_slug: Optional[str]
) -> Optional[_uuid_mod.UUID]:
    """Resolve a project UUID from either project_id string or project_slug."""
    if project_id is not None:
        return _uuid_mod.UUID(project_id)
    if project_slug is not None:
        result = await conn.fetchval(
            "SELECT project_id FROM projects WHERE project_slug = $1", project_slug
        )
        if not result:
            raise ToolError("project_not_found", f"Project not found: {project_slug}")
        return result
    return None


# ---------------------------------------------------------------------------
# Project tools
# ---------------------------------------------------------------------------


@mcp.tool()
async def project_create(project_slug: str, display_name: str) -> dict:
    """
    Create a canonical project ledger record.

    Returns project_id, project_slug, ledger_namespace, and project_token.
    The project_token is the write secret — store it in project config immediately.
    It is only shown once; use project_rotate_token to obtain a new one.
    """
    token = secrets.token_hex(32)
    suffix = secrets.token_hex(4)
    ledger_namespace = f"ledger.{project_slug}.{suffix}"

    pool = await db.get_pool()
    async with pool.acquire() as conn:
        existing = await conn.fetchrow(
            "SELECT project_id FROM projects WHERE project_slug = $1", project_slug
        )
        if existing:
            raise ToolError("duplicate_slug", f"Project slug already exists: {project_slug}")

        record = await conn.fetchrow(
            """
            INSERT INTO projects
                (project_slug, display_name, ledger_namespace, project_token_hash)
            VALUES ($1, $2, $3, $4)
            RETURNING project_id, project_slug, ledger_namespace, created_at
            """,
            project_slug, display_name, ledger_namespace, _hash_token(token),
        )

    return {
        "project_id": str(record["project_id"]),
        "project_slug": record["project_slug"],
        "ledger_namespace": record["ledger_namespace"],
        "project_token": token,
        "created_at": record["created_at"].isoformat(),
    }


@mcp.tool()
async def project_get(
    project_id: Optional[str] = None,
    project_slug: Optional[str] = None,
) -> dict:
    """
    Fetch one project by project_id or project_slug. Read-only, no token required.
    The project_token is never returned.
    """
    if not project_id and not project_slug:
        raise ToolError("validation_error", "Provide project_id or project_slug")

    _PUBLIC_COLS = (
        "project_id, project_slug, display_name, ledger_namespace, "
        "created_at, updated_at, archived_at, token_rotated_at"
    )
    pool = await db.get_pool()
    async with pool.acquire() as conn:
        if project_id:
            record = await conn.fetchrow(
                f"SELECT {_PUBLIC_COLS} FROM projects WHERE project_id = $1",
                _uuid_mod.UUID(project_id),
            )
        else:
            record = await conn.fetchrow(
                f"SELECT {_PUBLIC_COLS} FROM projects WHERE project_slug = $1",
                project_slug,
            )

    if not record:
        raise ToolError("project_not_found", f"Project not found: {project_id or project_slug}")
    return _row(record)


@mcp.tool()
async def project_list() -> str:
    """
    List all projects and their public metadata. Returns a JSON array string.
    The project_token is never included.
    """
    pool = await db.get_pool()
    async with pool.acquire() as conn:
        records = await conn.fetch(
            "SELECT project_id, project_slug, display_name, ledger_namespace, "
            "created_at, updated_at, archived_at, token_rotated_at "
            "FROM projects ORDER BY created_at DESC"
        )
    return json.dumps(_rows(records))


@mcp.tool()
async def project_rotate_token(project_id: str, project_token: str) -> dict:
    """
    Rotate the write secret for a project. Requires the current project_token.
    Returns the new token — store it immediately, it is only shown once.
    """
    new_token = secrets.token_hex(32)
    pool = await db.get_pool()
    async with pool.acquire() as conn:
        async with conn.transaction():
            await _validate_token(conn, project_id, project_token)
            record = await conn.fetchrow(
                """
                UPDATE projects
                SET project_token_hash = $1,
                    token_rotated_at = NOW(),
                    updated_at = NOW()
                WHERE project_id = $2
                RETURNING project_id, project_slug, token_rotated_at
                """,
                _hash_token(new_token), _uuid_mod.UUID(project_id),
            )

    return {
        "project_id": str(record["project_id"]),
        "project_slug": record["project_slug"],
        "project_token": new_token,
        "rotated_at": record["token_rotated_at"].isoformat(),
    }


# ---------------------------------------------------------------------------
# Task tools
# ---------------------------------------------------------------------------


@mcp.tool()
async def task_create(
    project_id: str,
    project_token: str,
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
    Create a new task in the ledger. Requires project_token for write auth.

    Returns task_id (UUID) and task_key (human-readable display key, e.g. MYPROJECT-7).
    If idempotency_key is provided and a matching task already exists, returns
    the existing task with idempotent=true — no duplicate is created.
    """
    if kind not in VALID_KINDS:
        raise ToolError("validation_error", f"Invalid kind '{kind}'. Must be one of: {sorted(VALID_KINDS)}")
    if state not in VALID_STATES:
        raise ToolError("validation_error", f"Invalid state '{state}'. Must be one of: {sorted(VALID_STATES)}")
    if priority and priority not in VALID_PRIORITIES:
        raise ToolError("validation_error", f"Invalid priority '{priority}'. Must be one of: {sorted(VALID_PRIORITIES)}")

    exp_cb = datetime.fromisoformat(expected_callback_at) if expected_callback_at else None
    pid = _uuid_mod.UUID(project_id)
    pool = await db.get_pool()

    async with pool.acquire() as conn:
        async with conn.transaction():
            await _validate_token(conn, project_id, project_token)

            if idempotency_key:
                existing = await conn.fetchrow(
                    "SELECT task_id, task_key, created_at FROM tasks "
                    "WHERE idempotency_key = $1 AND project_id = $2",
                    idempotency_key, pid,
                )
                if existing:
                    return {
                        "task_id": str(existing["task_id"]),
                        "task_key": existing["task_key"],
                        "created_at": existing["created_at"].isoformat(),
                        "idempotent": True,
                    }

            # Atomically allocate sequence number for the human-readable task_key
            proj_rec = await conn.fetchrow(
                """
                UPDATE projects
                SET task_next_seq = task_next_seq + 1
                WHERE project_id = $1
                RETURNING project_slug, task_next_seq - 1 AS seq
                """,
                pid,
            )
            task_key = f"{proj_rec['project_slug'].upper()}-{proj_rec['seq']}"
            task_id = _uuid_mod.uuid4()

            record = await conn.fetchrow(
                """
                INSERT INTO tasks (
                    task_id, project_id, task_key, kind, title, state, priority,
                    owner_agent_type, owner_agent_id,
                    source_kind, source_id,
                    issue_number, pr_number, branch,
                    next_action, expected_callback_at, idempotency_key
                ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17)
                RETURNING task_id, task_key, created_at
                """,
                task_id, pid, task_key, kind, title, state, priority,
                owner_agent_type, owner_agent_id,
                source_kind, source_id,
                issue_number, pr_number, branch,
                next_action, exp_cb, idempotency_key,
            )

            await conn.execute(
                """
                INSERT INTO task_history
                    (project_id, task_id, event_type, to_state, actor_type, actor_id, payload_json)
                VALUES ($1, $2, 'task.created', $3, $4, $5, $6)
                """,
                pid, task_id, state, owner_agent_type, owner_agent_id,
                {"kind": kind, "title": title, "priority": priority},
            )

    return {
        "task_id": str(record["task_id"]),
        "task_key": record["task_key"],
        "created_at": record["created_at"].isoformat(),
    }


@mcp.tool()
async def task_get(task_id: str) -> dict:
    """Fetch a single task by ID, including all fields. Read-only, no token required."""
    pool = await db.get_pool()
    async with pool.acquire() as conn:
        record = await conn.fetchrow(
            "SELECT * FROM tasks WHERE task_id = $1", _uuid_mod.UUID(task_id)
        )
    if not record:
        raise ToolError("task_not_found", f"Task not found: {task_id}")
    return _row(record)


@mcp.tool()
async def task_list(
    project_id: Optional[str] = None,
    project_slug: Optional[str] = None,
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
    Query tasks with optional filters. Returns a JSON array string. Read-only, no token required.

    Filter by project_id (UUID) or project_slug (human slug). Other filters:
    state, kind, owner_agent_type, owner_agent_id, priority, issue_number,
    overdue (expected_callback_at < now and not terminal). Invalid tasks are
    excluded by default; set include_invalid=true to include them.
    """
    clauses: list[str] = []
    params: list[Any] = []
    i = 1

    if not include_invalid:
        clauses.append("t.state != 'invalid'")

    def add_filter(col: str, val: Any) -> None:
        nonlocal i
        clauses.append(f"{col} = ${i}")
        params.append(val)
        i += 1

    pool = await db.get_pool()
    async with pool.acquire() as conn:
        pid = await _resolve_project_uuid(conn, project_id, project_slug)
        if pid is not None:
            add_filter("t.project_id", pid)
        if state is not None:
            add_filter("t.state", state)
        if kind is not None:
            add_filter("t.kind", kind)
        if owner_agent_type is not None:
            add_filter("t.owner_agent_type", owner_agent_type)
        if owner_agent_id is not None:
            add_filter("t.owner_agent_id", owner_agent_id)
        if priority is not None:
            add_filter("t.priority", priority)
        if issue_number is not None:
            add_filter("t.issue_number", issue_number)
        if overdue:
            clauses.append(
                "t.expected_callback_at < NOW() "
                "AND t.state NOT IN ('done', 'invalid', 'blocked')"
            )

        where = f"WHERE {' AND '.join(clauses)}" if clauses else ""
        params.extend([limit, offset])
        query = (
            f"SELECT t.* FROM tasks t {where} "
            f"ORDER BY t.created_at DESC LIMIT ${i} OFFSET ${i + 1}"
        )
        records = await conn.fetch(query, *params)

    return json.dumps(_rows(records))


@mcp.tool()
async def task_update(
    task_id: str,
    project_id: str,
    project_token: str,
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
    Patch mutable descriptive fields without changing lifecycle state. Requires project_token.

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
        raise ToolError("validation_error", "No fields to update")

    tid = _uuid_mod.UUID(task_id)
    params.extend([tid, revision])
    query = (
        f"UPDATE tasks SET {', '.join(sets)} "
        f"WHERE task_id = ${i} AND revision = ${i + 1} RETURNING *"
    )

    pool = await db.get_pool()
    async with pool.acquire() as conn:
        async with conn.transaction():
            await _validate_token(conn, project_id, project_token)
            record = await conn.fetchrow(query, *params)
            if not record:
                existing = await conn.fetchrow(
                    "SELECT revision FROM tasks WHERE task_id = $1", tid
                )
                if not existing:
                    raise ToolError("task_not_found", f"Task not found: {task_id}")
                raise ToolError(
                    "revision_mismatch",
                    f"Revision mismatch for {task_id}: "
                    f"expected {revision}, current is {existing['revision']}",
                )
            await conn.execute(
                """
                INSERT INTO task_history
                    (project_id, task_id, event_type, actor_type, actor_id, payload_json)
                VALUES ($1, $2, 'task.updated', $3, $4, $5)
                """,
                record["project_id"], tid, owner_agent_type, owner_agent_id,
                {"changedFields": changed_fields},
            )

    return _row(record)


@mcp.tool()
async def task_transition(
    task_id: str,
    project_id: str,
    project_token: str,
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
    Transition a task to a new lifecycle state. Requires project_token.

    Requires from_state (must match current state) and revision for optimistic
    concurrency. Both checks must pass or the transition is rejected.
    """
    if to_state not in VALID_STATES:
        raise ToolError("validation_error", f"Invalid to_state '{to_state}'. Must be one of: {sorted(VALID_STATES)}")

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

    tid = _uuid_mod.UUID(task_id)
    params.extend([tid, from_state, revision])
    query = (
        f"UPDATE tasks SET {', '.join(sets)} "
        f"WHERE task_id = ${i} AND state = ${i + 1} AND revision = ${i + 2} "
        f"RETURNING *"
    )

    pool = await db.get_pool()
    async with pool.acquire() as conn:
        async with conn.transaction():
            await _validate_token(conn, project_id, project_token)
            record = await conn.fetchrow(query, *params)
            if not record:
                existing = await conn.fetchrow(
                    "SELECT state, revision FROM tasks WHERE task_id = $1", tid
                )
                if not existing:
                    raise ToolError("task_not_found", f"Task not found: {task_id}")
                raise ToolError(
                    "revision_mismatch",
                    f"Transition rejected for {task_id}: "
                    f"expected state={from_state!r} revision={revision}, "
                    f"got state={existing['state']!r} revision={existing['revision']}",
                )
            await conn.execute(
                """
                INSERT INTO task_history
                    (project_id, task_id, event_type, from_state, to_state, summary,
                     reason_code, actor_type, actor_id, payload_json)
                VALUES ($1, $2, 'task.transitioned', $3, $4, $5, $6, $7, $8, $9)
                """,
                record["project_id"], tid, from_state, to_state, summary, reason_code,
                owner_agent_type, owner_agent_id,
                {"nextAction": next_action},
            )

    return _row(record)


@mcp.tool()
async def task_invalidate(
    task_id: str,
    project_id: str,
    project_token: str,
    reason_code: str,
    summary: Optional[str] = None,
    actor_type: Optional[str] = None,
    actor_id: Optional[str] = None,
) -> dict:
    """
    Soft-delete a task by marking it invalid. Requires project_token.

    Tasks are never hard-deleted. Invalid tasks are excluded from task_list
    by default but remain visible with include_invalid=true.
    """
    tid = _uuid_mod.UUID(task_id)
    pool = await db.get_pool()
    async with pool.acquire() as conn:
        async with conn.transaction():
            await _validate_token(conn, project_id, project_token)
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
                tid, reason_code,
            )
            if not record:
                existing = await conn.fetchrow(
                    "SELECT state FROM tasks WHERE task_id = $1", tid
                )
                if not existing:
                    raise ToolError("task_not_found", f"Task not found: {task_id}")
                raise ToolError("already_invalid", f"Task {task_id} is already invalid")

            await conn.execute(
                """
                INSERT INTO task_history
                    (project_id, task_id, event_type, to_state, summary, reason_code,
                     actor_type, actor_id, payload_json)
                VALUES ($1, $2, 'task.invalidated', 'invalid', $3, $4, $5, $6, '{}')
                """,
                record["project_id"], tid, summary, reason_code, actor_type, actor_id,
            )

    return _row(record)


@mcp.tool()
async def task_add_note(
    task_id: str,
    project_id: str,
    project_token: str,
    note: str,
    author_type: Optional[str] = None,
    author_id: Optional[str] = None,
) -> dict:
    """Add a human-readable note to a task without changing its state. Requires project_token."""
    tid = _uuid_mod.UUID(task_id)
    pid = _uuid_mod.UUID(project_id)
    pool = await db.get_pool()
    async with pool.acquire() as conn:
        async with conn.transaction():
            await _validate_token(conn, project_id, project_token)
            exists = await conn.fetchval(
                "SELECT 1 FROM tasks WHERE task_id = $1 AND project_id = $2", tid, pid
            )
            if not exists:
                raise ToolError("task_not_found", f"Task not found: {task_id}")

            record = await conn.fetchrow(
                """
                INSERT INTO task_notes (project_id, task_id, note, author_type, author_id)
                VALUES ($1, $2, $3, $4, $5)
                RETURNING *
                """,
                pid, tid, note, author_type, author_id,
            )
            await conn.execute(
                """
                INSERT INTO task_history
                    (project_id, task_id, event_type, actor_type, actor_id, payload_json)
                VALUES ($1, $2, 'task.note.added', $3, $4, $5)
                """,
                pid, tid, author_type, author_id, {"noteId": record["id"]},
            )

    return _row(record)


@mcp.tool()
async def task_link_artifact(
    task_id: str,
    project_id: str,
    project_token: str,
    artifact_kind: str,
    artifact_ref: str,
    url: Optional[str] = None,
    metadata_json: Optional[str] = None,
) -> dict:
    """
    Attach a durable artifact reference to a task. Requires project_token.

    artifact_kind must be one of: issue, pr, branch, commit, wiki,
    decision-record, release.
    """
    if artifact_kind not in VALID_ARTIFACT_KINDS:
        raise ToolError(
            "validation_error",
            f"Invalid artifact_kind '{artifact_kind}'. "
            f"Must be one of: {sorted(VALID_ARTIFACT_KINDS)}",
        )
    meta = json.loads(metadata_json) if metadata_json else {}
    tid = _uuid_mod.UUID(task_id)
    pid = _uuid_mod.UUID(project_id)

    pool = await db.get_pool()
    async with pool.acquire() as conn:
        async with conn.transaction():
            await _validate_token(conn, project_id, project_token)
            exists = await conn.fetchval(
                "SELECT 1 FROM tasks WHERE task_id = $1 AND project_id = $2", tid, pid
            )
            if not exists:
                raise ToolError("task_not_found", f"Task not found: {task_id}")

            record = await conn.fetchrow(
                """
                INSERT INTO task_artifacts
                    (project_id, task_id, artifact_kind, artifact_ref, url, metadata_json)
                VALUES ($1, $2, $3, $4, $5, $6)
                RETURNING *
                """,
                pid, tid, artifact_kind, artifact_ref, url, meta,
            )
            await conn.execute(
                """
                INSERT INTO task_history
                    (project_id, task_id, event_type, actor_type, actor_id, payload_json)
                VALUES ($1, $2, 'task.artifact.linked', 'system', NULL, $3)
                """,
                pid, tid,
                {"artifactKind": artifact_kind, "artifactRef": artifact_ref},
            )

    return _row(record)


@mcp.tool()
async def task_history(task_id: str) -> str:
    """
    Return the complete history for one task: task record, state transitions,
    notes, and linked artifacts — all in chronological order. Read-only, no token required.
    """
    tid = _uuid_mod.UUID(task_id)
    pool = await db.get_pool()
    async with pool.acquire() as conn:
        task = await conn.fetchrow("SELECT * FROM tasks WHERE task_id = $1", tid)
        if not task:
            raise ToolError("task_not_found", f"Task not found: {task_id}")

        history = await conn.fetch(
            "SELECT * FROM task_history WHERE task_id = $1 ORDER BY created_at ASC", tid
        )
        notes = await conn.fetch(
            "SELECT * FROM task_notes WHERE task_id = $1 ORDER BY created_at ASC", tid
        )
        artifacts = await conn.fetch(
            "SELECT * FROM task_artifacts WHERE task_id = $1 ORDER BY created_at ASC", tid
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
