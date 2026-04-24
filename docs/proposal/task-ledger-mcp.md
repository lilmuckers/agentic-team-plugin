# Proposed Task Ledger MCP API and Backing Store

## Status

Proposal only.

This document defines a narrow MCP surface for canonical task state, plus a relational backing schema. It is intentionally separate from the append-only action event stream.

## Purpose

The framework needs two different data surfaces:

1. **Task state** — small, canonical, mutable, used by Orchestrator and UI to answer "what is going on right now?"
2. **Action events** — append-only, high-volume, auditable, used to answer "what actually happened?"

This proposal covers the first surface.

## Scope boundary

The task ledger MCP is:
- the source of truth for current task state
- CRUD-like, but **no hard delete**
- small and boring by design
- primarily owned by Orchestrator
- safe for UI reads and state-transition writes

The task ledger MCP is **not**:
- the full observability system
- the sink for every tool/runtime event
- the source of truth for raw token accounting
- a replacement for append-only action telemetry

If a task must be removed from active use, it is **invalidated**, not deleted.

---

## Canonical project and task model

A **project** is the isolation boundary.
A **task** is the durable unit of orchestration within that project boundary.

### Project identity model

Each project should have four distinct identifiers/credentials:

- `project_id` — canonical relational UUID
- `project_slug` — human-friendly slug used in UI, docs, and agent context
- `ledger_namespace` — explicit ledger namespace string used to segregate event/task surfaces and prevent accidental overlap
- `project_token` — large random hexadecimal write secret used only for mutating operations

Important distinctions:
- `project_id` is the stable internal identity
- `project_slug` is not an authority boundary
- `ledger_namespace` is the explicit storage/telemetry isolation surface
- `project_token` is an authorization secret and must be rotatable

### Task identity model

Task records should use:
- `task_id` — canonical UUID/ULID primary key
- `task_key` — optional human-readable per-project display key for UI and operator workflows

Example:
- canonical id: `550e8400-e29b-41d4-a716-446655440000`
- display key: `DECKY-SECRETS-7`

The canonical relational key should not be a SQL counter-derived string. Human readability belongs in a separate display field.

### Minimum task fields

- `task_id`
- `project_id`
- `task_key` (display key, optional but recommended)
- `kind`
- `title`
- `state`
- `owner_agent_type`
- `owner_agent_id`
- `priority`
- `next_action`
- `expected_callback_at`
- `source_ref`
- `issue_number` and/or `pr_number` where relevant
- `invalidated_at` and `invalidation_reason` instead of hard delete

## Recommended task states

These are the canonical coarse states. Projects may add derived UI groupings, but should not invent incompatible storage states lightly.

- `new`
- `triage`
- `specifying`
- `ready_for_build`
- `building`
- `reviewing`
- `security_review`
- `qa_review`
- `release_pending`
- `blocked`
- `done`
- `invalid`

## Recommended task kinds

- `feature`
- `bug`
- `change`
- `chore`
- `spike`
- `release`
- `triage`
- `meta`

---

## MCP API proposal

The API should stay intentionally small.

## Project bootstrap surface

### `project.create`
Create the canonical project ledger record.

This should normally be called during project bootstrap/onboarding, not ad hoc by normal worker agents.

**Input**
```json
{
  "project_slug": "decky-secrets",
  "display_name": "Decky Secrets"
}
```

**Output**
```json
{
  "project_id": "550e8400-e29b-41d4-a716-446655440001",
  "project_slug": "decky-secrets",
  "ledger_namespace": "ledger.decky-secrets.550e8400",
  "project_token": "9f3a...<large random hex>...7c21",
  "created_at": "2026-04-23T22:39:00Z"
}
```

The `project_token` should be recorded in project config for the operating agents and treated as a write secret.

### `project.get`
Fetch one project by `project_id` or `project_slug`.

### `project.rotate_token`
Rotate the current write secret for a project.

This is why the authorization secret should be treated as a token, not as the canonical project identifier.

### `project.list`
Return known projects and their public metadata. The token itself must never be returned here.

## Task surface

### `task.create`
Create a new task record.

**Write auth required:** `project_token`

**Input**
```json
{
  "project_id": "550e8400-e29b-41d4-a716-446655440001",
  "project_token": "9f3a...<large random hex>...7c21",
  "kind": "bug",
  "title": "Clipboard clear timer fails after suspend",
  "state": "new",
  "priority": "high",
  "source_ref": {
    "kind": "issue",
    "id": "7"
  },
  "issue_number": 7,
  "owner_agent_type": "orchestrator",
  "owner_agent_id": "orchestrator-decky-secrets",
  "next_action": "Route to Triage for repro confirmation"
}
```

**Output**
```json
{
  "task_id": "550e8400-e29b-41d4-a716-446655440000",
  "task_key": "DECKY-SECRETS-7",
  "created_at": "2026-04-23T22:39:00Z"
}
```

### `task.get`
Fetch one task by `task_id`. Read-only, no token required.

### `task.list`
Query tasks. Read-only, no token required.

**Supported filters**
- `project_id`
- `project_slug`
- `state`
- `kind`
- `owner_agent_type`
- `owner_agent_id`
- `priority`
- `overdue`
- `include_invalid`

### `task.update`
Patch mutable descriptive fields without changing lifecycle state.

**Write auth required:** `project_token`

Typical fields:
- `title`
- `priority`
- `next_action`
- `owner_agent_type`
- `owner_agent_id`
- `expected_callback_at`
- `issue_number`
- `pr_number`
- `source_ref`

### `task.transition`
The main lifecycle mutation.

**Write auth required:** `project_token`

**Input**
```json
{
  "project_id": "550e8400-e29b-41d4-a716-446655440001",
  "project_token": "9f3a...<large random hex>...7c21",
  "task_id": "550e8400-e29b-41d4-a716-446655440000",
  "from_state": "triage",
  "to_state": "ready_for_build",
  "reason_code": "builder-ready",
  "summary": "Triage confirmed repro and Spec clarified expected behaviour",
  "next_action": "Route to Builder",
  "owner_agent_type": "orchestrator",
  "owner_agent_id": "orchestrator-decky-secrets"
}
```

This should use optimistic concurrency so stale writers do not silently overwrite state.

### `task.invalidate`
Soft-delete equivalent.

**Write auth required:** `project_token`

Effect:
- sets state to `invalid`
- records invalidation reason
- preserves full history

### `task.add_note`
Add a human-readable note without changing canonical state.

Default proposal: allow without token only if explicitly intended for limited non-Orchestrator use. Otherwise require token. At minimum, normal orchestration writes must still be token-scoped.

### `task.link_artifact`
Attach a durable artifact reference.

Default proposal: same rule as notes. Keep this narrower than full task mutation, but do not let artifact writes become an unbounded cross-project leak path.

Examples:
- GitHub issue
- PR
- branch
- commit
- wiki page
- decision record
- release tracking issue

### `task.history`
Return the authoritative task transition and note history. Read-only, no token required.

This is still task-level history, not the full action-event stream.

---

## Required behaviour

### No hard delete
Tasks are never physically removed through the MCP surface.

### UUID/ULID canonical ids
- `project_id` should be a UUID/ULID, not a slug-derived value
- `task_id` should be a UUID/ULID, not a SQL counter-derived display string
- human-readable keys should remain secondary display fields

### Project-scoped write authorization
- reads may be open by `project_id` or `project_slug`
- writes must validate a correct `project_token`
- the project slug alone must never be accepted as write authority
- task id alone must never be accepted as write authority
- writes should validate both project membership and token validity

### Rotatable secret model
The project write secret should:
- be generated at `project.create`
- be large random hexadecimal text
- be stored in one central rotatable location
- be required for write methods only
- be rotatable in future without changing `project_id`

### Optimistic concurrency
Every mutating write should carry a revision or version number.

### Idempotency
`task.create` should optionally accept an external idempotency key so wrappers do not duplicate tasks on retry.

### Orchestrator-first write ownership
Default operating model:
- Orchestrator uses the project token for canonical task creation and state transitions
- other agents may read directly by project slug/id
- non-Orchestrator mutation methods such as notes/artifacts should remain explicitly limited if enabled

This keeps task truth tight while still allowing broad visibility.

### State changes emit action events
Every successful task mutation should also emit a matching action event:
- `task.created`
- `task.updated`
- `task.transitioned`
- `task.invalidated`
- `task.note.added`
- `task.artifact.linked`

The task ledger MCP owns canonical state. It should not be the only event emitter in the system.

---

## Backing database schema

A relational schema is the simplest sane backing store.

### `projects`
Canonical project isolation and authorization table.

| Column | Type | Notes |
|---|---|---|
| `project_id` | uuid pk | canonical project identity |
| `project_slug` | text unique not null | human-friendly slug |
| `display_name` | text not null | project display name |
| `ledger_namespace` | text unique not null | explicit ledger namespace |
| `project_token_hash` | text not null | hashed write secret |
| `created_at` | timestamptz not null | creation time |
| `updated_at` | timestamptz not null | last mutation time |
| `archived_at` | timestamptz null | soft archive marker |
| `token_rotated_at` | timestamptz null | last token rotation |

### `tasks`
Canonical current-state table.

| Column | Type | Notes |
|---|---|---|
| `task_id` | uuid pk | canonical task id |
| `project_id` | uuid fk | canonical project identity |
| `task_key` | text unique null | human-readable display key |
| `kind` | text not null | feature/bug/change/etc |
| `title` | text not null | human-readable title |
| `state` | text not null | canonical coarse state |
| `priority` | text null | low/medium/high/critical |
| `owner_agent_type` | text null | orchestrator/spec/builder/etc |
| `owner_agent_id` | text null | full agent id |
| `source_kind` | text null | issue/pr/human/callback/release |
| `source_id` | text null | source identifier |
| `issue_number` | integer null | linked GitHub issue |
| `pr_number` | integer null | linked GitHub PR |
| `branch` | text null | working branch where relevant |
| `next_action` | text null | next expected step |
| `expected_callback_at` | timestamptz null | callback SLA target |
| `created_at` | timestamptz not null | creation time |
| `updated_at` | timestamptz not null | last mutation time |
| `completed_at` | timestamptz null | when moved to done |
| `invalidated_at` | timestamptz null | when invalidated |
| `invalidation_reason` | text null | reason code |
| `revision` | bigint not null default 1 | optimistic concurrency token |
| `idempotency_key` | text unique null | optional de-dupe key |

### `task_history`
Authoritative task-level mutation history.

| Column | Type | Notes |
|---|---|---|
| `id` | bigserial pk | row id |
| `project_id` | uuid fk | denormalised project scope for easy filtering |
| `task_id` | uuid fk | parent task |
| `event_type` | text not null | created/updated/transitioned/invalidated/note_added/artifact_linked |
| `from_state` | text null | previous state |
| `to_state` | text null | next state |
| `summary` | text null | human-readable explanation |
| `reason_code` | text null | structured reason |
| `actor_type` | text null | orchestrator/system/human/etc |
| `actor_id` | text null | specific writer |
| `created_at` | timestamptz not null | event time |
| `payload_json` | jsonb not null default '{}'::jsonb | mutation details |

### `task_artifacts`
Linked durable artifacts.

| Column | Type | Notes |
|---|---|---|
| `id` | bigserial pk | row id |
| `project_id` | uuid fk | project scope |
| `task_id` | uuid fk | parent task |
| `artifact_kind` | text not null | issue/pr/branch/commit/wiki/decision-record/release |
| `artifact_ref` | text not null | identifier or path |
| `url` | text null | optional URL |
| `created_at` | timestamptz not null | link time |
| `metadata_json` | jsonb not null default '{}'::jsonb | extra fields |

### `task_notes`
Optional user/agent notes.

| Column | Type | Notes |
|---|---|---|
| `id` | bigserial pk | row id |
| `project_id` | uuid fk | project scope |
| `task_id` | uuid fk | parent task |
| `note` | text not null | free text |
| `author_type` | text null | agent/human/system |
| `author_id` | text null | identifier |
| `created_at` | timestamptz not null | note time |

## Concrete revision brief against the current first-cut implementation

The current implementation direction is good, but the next proposal revision should change these points:

1. Replace project-slug-centered identity with a first-class `projects` table.
2. Replace canonical task ids derived from per-project SQL counters with UUID/ULID task ids.
3. Keep a separate human-readable `task_key` for UI/operator use.
4. Add `project.create`, `project.get`, `project.list`, and `project.rotate_token`.
5. Add `ledger_namespace` as a first-class project field.
6. Require `project_token` for canonical task writes.
7. Keep reads open by `project_id` or `project_slug`.
8. Treat `project_token` as rotatable authorization secret, not as identity.
9. Record the project token in project config for the operating agents.
10. Ensure writes validate both project membership and token validity so context pollution cannot leak writes across projects.

---

## Relationship to action events

The task ledger MCP should be joined to the action-event stream by `task_id`.

That gives the UI two layers:

### Task layer
- current state
- owner
- next action
- due/blocked/done

### Action layer
- dispatch attempts
- repo sync failures
- tests run
- callback validation failures
- PR comments and labels
- merge/release/deploy activity
- token usage and cost at run/event boundaries

In short:
- **task ledger = envelope**
- **action events = contents**

---

## Query examples the MCP should support well

- all open tasks for a project
- all blocked tasks
- all overdue tasks
- all tasks owned by Orchestrator
- all tasks linked to issue 7
- task history for one task
- tasks completed in the last 7 days

---

## Summary

The task ledger MCP should be a narrow task-state service with:
- no hard delete
- explicit invalidation
- optimistic concurrency
- task-level history
- artifact linking
- event emission on mutation

It should remain separate from the append-only action telemetry layer, which is the correct place for detailed audit logs, usage, cost, and duration metrics.
