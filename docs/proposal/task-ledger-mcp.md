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

## Canonical task model

A task is the durable unit of orchestration.

Minimum fields:
- `task_id`
- `project`
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

### `task.create`
Create a new task record.

**Input**
```json
{
  "project": "decky-secrets",
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
  "task_id": "task_decky_secrets_0007",
  "created_at": "2026-04-23T22:39:00Z"
}
```

### `task.get`
Fetch one task by id.

### `task.list`
Query tasks.

**Supported filters**
- `project`
- `state`
- `kind`
- `owner_agent_type`
- `owner_agent_id`
- `priority`
- `overdue`
- `include_invalid`

### `task.update`
Patch mutable descriptive fields without changing lifecycle state.

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

**Input**
```json
{
  "task_id": "task_decky_secrets_0007",
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

**Input**
```json
{
  "task_id": "task_decky_secrets_0007",
  "reason_code": "duplicate-report",
  "summary": "Superseded by task_decky_secrets_0003"
}
```

Effect:
- sets state to `invalid`
- records invalidation reason
- preserves full history

### `task.add_note`
Add a human-readable note without changing canonical state.

### `task.link_artifact`
Attach a durable artifact reference.

Examples:
- GitHub issue
- PR
- branch
- commit
- wiki page
- decision record
- release tracking issue

### `task.history`
Return the authoritative task transition and note history.

This is still task-level history, not the full action-event stream.

---

## Required behaviour

### No hard delete
Tasks are never physically removed through the MCP surface.

### Optimistic concurrency
Every mutating write should carry a revision or version number.

### Idempotency
`task.create` should optionally accept an external idempotency key so wrappers do not duplicate tasks on retry.

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

### `tasks`
Canonical current-state table.

| Column | Type | Notes |
|---|---|---|
| `task_id` | text pk | stable task id |
| `project` | text not null | project slug |
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

### `task_history`
Authoritative task-level mutation history.

| Column | Type | Notes |
|---|---|---|
| `id` | bigserial pk | row id |
| `task_id` | text fk | parent task |
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
| `task_id` | text fk | parent task |
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
| `task_id` | text fk | parent task |
| `note` | text not null | free text |
| `author_type` | text null | agent/human/system |
| `author_id` | text null | identifier |
| `created_at` | timestamptz not null | note time |

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
