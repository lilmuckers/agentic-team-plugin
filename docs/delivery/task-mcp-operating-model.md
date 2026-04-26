# Task Ledger MCP Operating Model

## Purpose

This document defines how the delivery agents use the task-ledger MCP server as the canonical task-state system. It covers ownership, authority, state management, failure handling, and the relationship between the MCP ledger and the legacy repo markdown file.

The operational contract agents follow is in [`skills/task-ledger-mcp/SKILL.md`](../../skills/task-ledger-mcp/SKILL.md). This document provides the supporting reference.

---

## Canonical source of truth

The task-ledger MCP server is the **single canonical source of mutable task state**.

`docs/delivery/task-ledger.md` in project repos is a **legacy format and optional human snapshot**. It is not a mutable canonical surface. Agents must not treat it as authoritative after this operating model is active.

See the [legacy ledger section](#legacy-repo-ledger) for migration notes.

---

## Project identity and token

Each project in the ledger has:

- `project_id` — canonical UUID, used as the stable identity key in all tool calls
- `project_slug` — human-readable slug, used for display and read-only queries
- `ledger_namespace` — explicit namespace for storage/telemetry isolation
- `project_token` — write secret, required for all task mutations

### Bootstrap

Orchestrator calls `project_create` once per project during framework bootstrap. The returned `project_token` must be:

1. Stored immediately in Orchestrator's workspace config (e.g. `workspace-orchestrator/.env` or equivalent secure config location)
2. Never committed to the project repo
3. Never passed to other agents

If the token is lost, call `project_rotate_token` to generate a new one. The old token is invalidated immediately.

---

## Authority by agent role

### Orchestrator — primary writer

Orchestrator holds the `project_token` and is the only agent that performs lifecycle mutations.

Permitted operations:
- `project_create` — bootstrap only
- `task_create` — when delegating work
- `task_update` — patch descriptive fields (branch, PR number, next_action, etc.)
- `task_transition` — lifecycle state changes
- `task_invalidate` — soft-delete superseded or duplicate tasks
- `task_add_note` — record reasoning, blockers, routing context
- `task_link_artifact` — attach issue, PR, branch, commit, or decision-record references

### Spec, Triage, QA, Security — read-mostly with narrow writes

These agents query task state for context. They do not manage task lifecycle.

Permitted operations (no token required):
- `task_get` — fetch a specific task
- `task_list` — query tasks by project, state, owner, etc.
- `task_history` — read full task history

Permitted writes — only when Orchestrator has included the `project_token` in the task packet for that purpose. This is a per-task grant, not a standing permission:
- `task_add_note` — attach diagnostic, spec, QA, or security findings
- `task_link_artifact` — attach relevant artifact references

### Builder — reader only by default

Builder reads task state for context. Builder does not own canonical task state.

Builder may call `task_link_artifact` only when Orchestrator has included the `project_token` in the task packet for that purpose. This is a per-task grant, not a standing permission.

### Release Manager — reader with narrow artifact writes

Release Manager reads task state and may attach release artifact references. Release Manager may call `task_link_artifact` only when Orchestrator has included the `project_token` in the task packet for that purpose. This is a per-task grant, not a standing permission.

---

## Task states

The canonical state set. Do not invent additional states.

| State | Meaning |
|---|---|
| `new` | Created, not yet acted on |
| `triage` | Under triage diagnosis |
| `specifying` | Spec is defining requirements |
| `ready_for_build` | Spec-approved and ready to implement |
| `building` | Builder has the work |
| `reviewing` | PR is open and under review |
| `security_review` | Security agent is reviewing |
| `qa_review` | QA agent is reviewing |
| `release_pending` | Approved, waiting for release |
| `blocked` | Cannot proceed; reason in notes |
| `done` | Work complete |
| `invalid` | Soft-deleted; excluded from default queries |

Terminal states are `done` and `invalid`. Tasks in these states are not transitioned further.

### Common transition paths

```
new → triage → specifying → ready_for_build → building → reviewing → qa_review → done
new → specifying → ready_for_build → building → reviewing → security_review → qa_review → done
new → ready_for_build → building → reviewing → done
any → blocked  (and back to prior state once unblocked)
```

Orchestrator decides which path applies. The transition must always supply the current `revision` and `from_state` for optimistic concurrency.

---

## Querying task state

### On session start (Orchestrator)

```
task_list project_slug=<slug> state=new,triage,specifying,ready_for_build,building,reviewing,security_review,qa_review,release_pending,blocked
```

Surface any overdue items (`overdue=true`) before taking new work.

### On session start (other agents)

```
task_list project_slug=<slug> owner_agent_type=<archetype>
```

Or fetch the specific task being worked on:

```
task_get task_id=<uuid>
```

### Filtering by owner

Use `owner_agent_type` to see tasks currently assigned to a specific archetype, and `owner_agent_id` to scope to a specific named agent instance.

---

## Optimistic concurrency

Every mutating write (`task_update`, `task_transition`, `task_invalidate`) requires the current `revision`.

If a `revision_mismatch` error is returned:
1. Call `task_get` to read the current state and revision
2. Reconcile — is the transition still valid given the current state?
3. Retry with the updated revision and `from_state`, or report the conflict to Orchestrator

Never retry a failed write without first re-reading the current state.

---

## Failure handling

All tool failures return `isError=true`. The content is a JSON object:

```json
{"error_code": "...", "message": "..."}
```

Agents must check `isError` and parse `error_code` — do not parse the prose `message` field for control flow.

See the skill for the full error code table and required responses.

### MCP unavailability

If the MCP server is unreachable, agents must report `BLOCKED` and halt rather than degrading to markdown-based state tracking. Forking state into ad hoc files creates split truth that cannot be reliably reconciled.

---

## Artifact kinds

When calling `task_link_artifact`, `artifact_kind` must be one of:

`issue` `pr` `branch` `commit` `wiki` `decision-record` `release`

---

## Idempotency

`task_create` accepts an optional `idempotency_key`. Use this when a task may be created by a retried bootstrap or scripted workflow. If a task with the same key already exists in the project, the existing task is returned with `idempotent=true`.

---

## Legacy repo ledger

`docs/delivery/task-ledger.md` in project repos was the previous canonical task surface. It is now a legacy format.

**Status after this operating model is active:**
- Not a mutable canonical surface
- May be kept as a human-readable snapshot or export projection
- Agents must not write to it as a primary record-keeping action
- The three associated scripts (`update-task-ledger.py`, `validate-task-ledger.py`, `check-task-ledger-overdue.py`) are superseded by MCP tool calls

The file format is documented in `docs/delivery/task-ledger.md` for reference and export compatibility. It remains available during migration but should not be treated as authoritative.

---

## MCP server reference

- Transport: SSE at `http://<host>:8000/sse`
- Health check: `GET /health` → `{"status":"ok","database":"ok"}`
- Source: `server/mcp_ledger/`
- Full tool reference: `server/mcp_ledger/README.md`
- Docker Compose: `server/docker-compose.yml`
- Practical access guide (workspace config, tool invocation path): `docs/delivery/task-ledger-mcp-access.md`
