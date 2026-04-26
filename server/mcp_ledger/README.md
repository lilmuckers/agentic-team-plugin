# mcp-ledger

A task-state MCP server backed by PostgreSQL. Exposes 13 tools over SSE transport for canonical task lifecycle management across agent-team projects.

---

## Overview

mcp-ledger is the source of truth for current task state in the agentic framework. It is intentionally small and boring:

- **No hard deletes** — tasks are invalidated, never removed
- **Optimistic concurrency** — every write carries a revision token
- **Project-scoped write auth** — reads are open; writes require a `project_token`
- **UUID-native** — all primary keys are UUIDs; human-readable keys (`PROJECT-7`) are display-only
- **Structured errors** — all tool failures return `{"error_code": "...", "message": "..."}` with `isError=true`

It is separate from the append-only action event stream. The ledger owns current state; action events own history and observability.

---

## Tools

### Project tools

| Tool | Auth | Description |
|---|---|---|
| `project_create` | none | Bootstrap a new project; returns `project_token` (shown once only) |
| `project_get` | none | Fetch project by `project_id` or `project_slug` |
| `project_list` | none | List all projects; tokens are never returned |
| `project_rotate_token` | `project_token` | Rotate the write secret; returns the new token once |

### Task tools

| Tool | Auth | Description |
|---|---|---|
| `task_create` | `project_token` | Create a task; returns UUID `task_id` and display `task_key` |
| `task_get` | none | Fetch one task by `task_id` |
| `task_list` | none | Query tasks with filters (project, state, kind, owner, overdue, …) |
| `task_update` | `project_token` | Patch mutable fields (optimistic concurrency via `revision`) |
| `task_transition` | `project_token` | Move task to a new lifecycle state (optimistic concurrency) |
| `task_invalidate` | `project_token` | Soft-delete a task (sets state `invalid`, never hard-deletes) |
| `task_add_note` | `project_token` | Attach a free-text note |
| `task_link_artifact` | `project_token` | Attach a durable artifact reference (issue, pr, branch, commit, …) |
| `task_history` | none | Full history: task record + events + notes + artifacts |

### HTTP

| Endpoint | Description |
|---|---|
| `GET /health` | Liveness + database probe; returns `{"status":"ok","database":"ok"}` |
| `GET /sse` | SSE stream (MCP session establishment) |
| `POST /messages/` | MCP tool invocation (requires `?session_id=` from SSE handshake) |

---

## Task states

```
new → triage → specifying → ready_for_build → building →
reviewing → security_review → qa_review → release_pending →
done | blocked | invalid
```

## Task kinds

`feature` `bug` `change` `chore` `spike` `release` `triage` `meta`

## Error codes

All tool failures set `isError=true` and return a JSON payload:

```json
{"error_code": "invalid_token", "message": "Invalid project_token"}
```

| Code | Meaning |
|---|---|
| `invalid_token` | `project_token` does not match the stored hash |
| `project_not_found` | No project with that `project_id` or `project_slug` |
| `task_not_found` | No task with that `task_id` |
| `revision_mismatch` | Optimistic concurrency check failed |
| `already_invalid` | Task is already in the `invalid` state |
| `validation_error` | Input value is outside the allowed set |
| `duplicate_slug` | A project with that slug already exists |

---

## Running with Docker Compose

The `docker-compose.yml` at `server/` runs mcp-ledger alongside Postgres:

```bash
cd server/
docker compose up -d
```

The server starts at `http://localhost:8000`. The Postgres volume persists at `server_pgdata`.

```bash
# Verify
curl http://localhost:8000/health
# {"status":"ok","database":"ok"}
```

To rebuild after code changes:

```bash
docker compose up -d --build mcp_ledger
```

To reset all data:

```bash
docker compose down -v && docker compose up -d
```

### Environment variables

| Variable | Default | Description |
|---|---|---|
| `DATABASE_URL` | `postgresql://mcp:mcp@localhost:5432/mcp_ledger` | asyncpg connection string |
| `HOST` | `0.0.0.0` | Bind address |
| `PORT` | `8000` | Bind port |

---

## Project token model

`project_token` is the write secret for a project. It is:

- Generated at `project_create` (64 hex characters, 256 bits)
- Shown **only once** — at creation and at each `project_rotate_token` call
- Stored as a SHA-256 hash; the plaintext is never persisted
- Required for all task write operations
- Rotatable without changing `project_id`

Store the token in your project config immediately after calling `project_create`. If lost, use `project_rotate_token` to issue a new one.

---

## Development

### Install

```bash
pip install -e ".[test]"
```

### Tests

Tests are integration tests against a live server. Start the stack first, then run:

```bash
docker compose up -d          # from server/
cd server/mcp_ledger
python3 -m pytest tests/ -v
```

The suite runs 146 tests (asyncio + trio backends) covering all 13 tools, all error codes, and edge cases including idempotency, optimistic concurrency conflicts, and token rotation.

The `MCP_LEDGER_URL` environment variable overrides the default `http://localhost:8000`.

### Schema

The database schema lives at [mcp_ledger/schema.sql](mcp_ledger/schema.sql). It is applied automatically on first connection. Tables:

- `projects` — project identity, auth, and task sequence counter
- `tasks` — canonical current state (no hard deletes)
- `task_history` — append-only mutation log
- `task_artifacts` — linked artifact references
- `task_notes` — free-text notes

---

## CI

On push to `main`, GitHub Actions builds the Docker image and pushes it to:

```
ghcr.io/lilmuckers/mcp-ledger:latest
ghcr.io/lilmuckers/mcp-ledger:<sha>
```

See [.github/workflows/publish-mcp-ledger.yml](../../.github/workflows/publish-mcp-ledger.yml).
