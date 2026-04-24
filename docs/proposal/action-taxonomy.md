# Proposed Task, Action, and Usage Telemetry Model

## Status

Proposal only.

This material describes a future telemetry architecture that has not yet been fully implemented in the runtime/tooling.

For the currently implemented helper-backed auditability surface, see `docs/delivery/action-taxonomy.md`.

## Machine-readable proposal artifacts

This document is paired with:
- `docs/proposal/task-ledger-mcp.md` — proposed MCP API for canonical task state
- `docs/proposal/schemas/action-event.schema.json` — proposed append-only event envelope
- `docs/proposal/schemas/action-types.json` — proposed event type registry
- `docs/proposal/schemas/reason-codes.json` — proposed reason/outcome registry

These files are proposals, not enforced runtime contracts.

---

## Executive summary

The framework needs **two different persistence layers**, not one overloaded one:

1. **Task ledger / task MCP**
   - canonical mutable task state
   - used by Orchestrator and UI to answer "what is going on now?"
   - coarse orchestration surface

2. **Append-only action event stream**
   - detailed execution and audit trail
   - used for debugging, metrics, replay, and historical analysis
   - includes runtime usage, token, cost, and duration data where known

The old proposal leaned too hard toward making the action taxonomy itself the whole model.
That was too fuzzy.

The cleaner split is:
- **task state** for orchestration
- **event stream** for auditability and usage

---

## Comparison to the earlier proposal

### What the earlier proposal got right
- actions should be typed
- wrappers are the right initial instrumentation points
- auditability should be incremental
- the framework needs a common envelope and registry

### What was weak in the earlier proposal
- it mixed **task state** and **action telemetry** too much
- it over-indexed on role-specific conceptual verbs rather than the event surfaces the system can actually emit
- it did not model usage/cost/duration strongly enough as first-class telemetry
- it did not clearly separate mutable current state from append-only history

### Updated stance
- the **task ledger MCP** owns current task state
- the **event stream** owns append-only execution telemetry
- the **runtime** should emit run-boundary usage events
- **wrapper scripts** should emit side-effect events
- **task mutations** should emit corresponding task events

---

## Architecture

### Layer 1. Task state
Canonical, mutable, low-volume, and explicitly project-scoped.

Examples:
- `task.created`
- `task.updated`
- `task.transitioned`
- `task.invalidated`
- `task.note.added`
- `task.artifact.linked`

These events mirror task mutations, but the source of truth is still the task ledger backing store.

### Layer 2. Action events
Append-only, higher-volume, auditable.

Examples:
- `agent.dispatch`
- `callback.sent`
- `callback.validated`
- `repo.sync`
- `issue.created`
- `pr.created`
- `pr.body.updated`
- `pr.comment.added`
- `pr.line_comment.added`
- `label.applied`
- `release.tag.cut`
- `framework.deployed`
- `framework.agent_primed`

### Layer 3. Runtime usage events
Append-only run-boundary telemetry.

Examples:
- `agent.run.started`
- `agent.run.completed`
- `agent.run.failed`
- `tool.exec.started`
- `tool.exec.completed`
- `tool.exec.failed`

These are where token usage, cost, model, provider, and duration metrics belong.

---

## Bookending rule

Every meaningful flow should be bookended by task state and filled with action/runtime events.

### Top bookend
A task is created or activated in the task ledger.

### Middle
Action and runtime events accumulate while work happens.

### Bottom bookend
The task is transitioned to `done`, `blocked`, or `invalid`.

In short:
- **task ledger = envelope**
- **event stream = contents**

---

## Event emission strategy

Do **not** make Orchestrator the sole event emitter.

That would be brittle and incomplete.

Use three emitter classes:

### 1. Task service emitter
The task MCP emits task mutation events whenever task state changes. Reads may be open by `project_id` or `project_slug`, but canonical writes should require a valid project-scoped write token so confused agents cannot scribble into the wrong ledger namespace.

### 2. Wrapper/helper emitters
Framework wrappers emit side-effect events.

High-value initial emitters:
- `scripts/dispatch-named-agent.sh`
- `scripts/send-agent-callback.sh`
- `scripts/create-agent-issue.sh`
- `scripts/create-agent-pr.sh`
- `scripts/update-agent-pr-body.sh`
- `scripts/post-agent-comment.sh`
- `scripts/post-pr-line-comment.sh`
- `scripts/update-agent-wiki-page.sh`

### 3. Runtime emitters
Agent/runtime boundaries emit usage and duration events.

Examples:
- agent run start/end
- tool exec start/end
- tool exec failure

---

## Recommended transport

### Preferred v1
Append newline-delimited JSON events to a durable local log.

Examples:
- `state/events/2026-04-23.ndjson`
- `state/projects/decky-secrets/events.ndjson`

Why:
- easy to write from shell/Python wrappers
- append-only
- cheap to tail and ingest
- good failure characteristics
- easy to ingest into Postgres later

### Preferred v2
Keep NDJSON as the write path, then ingest into Postgres asynchronously.

That gives:
- resilient local writes
- better querying for UI and analytics
- reduced coupling between wrappers and the database

### Not recommended as v1
Writing directly from every wrapper into Postgres.

It is viable later, but it couples event emission too tightly to DB availability.

---

## Proposed event envelope

The event stream should use one canonical JSON envelope.

Core required fields:
- `eventId`
- `eventType`
- `eventSource`
- `timestamp`
- `project`
- `status`

Strongly recommended common fields:
- `taskId`
- `runId`
- `correlationId`
- `parentEventId`
- `agentType`
- `agentId`
- `sessionKey`
- `model`
- `provider`
- `durationMs`
- `usage`
- `costUsd`
- `data`

Example:

```json
{
  "eventId": "evt_01HS...",
  "eventType": "agent.dispatch",
  "eventSource": "wrapper",
  "timestamp": "2026-04-23T22:39:00Z",
  "project": "decky-secrets",
  "taskId": "task_decky_secrets_0007",
  "runId": null,
  "correlationId": "corr_issue_7_review",
  "parentEventId": null,
  "agentType": "orchestrator",
  "agentId": "orchestrator-decky-secrets",
  "sessionKey": "agent:orchestrator-decky-secrets:main",
  "model": null,
  "provider": null,
  "status": "succeeded",
  "outcome": "dispatched",
  "durationMs": 381,
  "usage": null,
  "costUsd": null,
  "target": {
    "kind": "named-agent",
    "id": "triage-decky-secrets"
  },
  "artifacts": {
    "issueNumber": 7,
    "prNumber": null,
    "branch": null,
    "commitSha": null,
    "releaseVersion": null,
    "urls": []
  },
  "data": {
    "expectedCallbackAt": "2026-04-23T23:00:00Z",
    "reasonCode": "needs-triage"
  }
}
```

---

## Usage, token, cost, and duration telemetry

Usage telemetry should be captured at the **run boundary**, not inferred only from task state.

Why:
- a task may involve multiple runs
- retries matter
- models may change inside one task
- idle gaps and wall time matter separately

### Minimum usage fields
- `agentType`
- `agentId`
- `sessionKey`
- `model`
- `provider`
- `startedAt`
- `endedAt`
- `durationMs`
- `inputTokens`
- `outputTokens`
- `totalTokens`
- `cacheReadTokens` if available
- `cacheWriteTokens` if available
- `costUsd`
- `status`

### Minimum runtime events
- `agent.run.started`
- `agent.run.completed`
- `agent.run.failed`

If tool-level accounting is available, also:
- `tool.exec.started`
- `tool.exec.completed`
- `tool.exec.failed`

---

## Database projection model

If/when events are ingested into Postgres, keep raw events and derived facts separate.

### Raw event store
- append-only `action_events`

### Derived facts / projections
- `agent_runs`
- `task_metrics_daily`
- `agent_costs_daily`
- `project_costs_daily`
- `dispatch_latency_facts`

This lets the UI support:
- cost by project
- cost by agent type
- cost by model
- token usage over time
- dispatch-to-callback latency
- median run duration by agent type
- expensive failed loops
- release cost versus normal delivery cost

---

## Recommended initial event types

### Task mutation events
- `task.created`
- `task.updated`
- `task.transitioned`
- `task.invalidated`
- `task.note.added`
- `task.artifact.linked`

### Wrapper action events
- `agent.dispatch`
- `callback.sent`
- `callback.validated`
- `issue.created`
- `issue.commented`
- `pr.created`
- `pr.body.updated`
- `pr.comment.added`
- `pr.line_comment.added`
- `label.applied`
- `wiki.updated`
- `repo.sync`
- `release.tag.cut`
- `release.notes.generated`
- `framework.deployed`
- `framework.agent_primed`

### Runtime usage events
- `agent.run.started`
- `agent.run.completed`
- `agent.run.failed`
- `tool.exec.started`
- `tool.exec.completed`
- `tool.exec.failed`

---

## Relationship to existing framework evidence

This proposal matches the conclusion already visible in real project evidence:
- task ledgers are useful for orchestration state
- task ledgers alone are too lossy for audit/debugging
- the missing layer is append-only typed event telemetry

That is why task state and action telemetry should be separated instead of forced into one overloaded ledger.

---

## Summary

The proposed model is:
- **Task MCP** for canonical task state
- **project_id + ledger_namespace + project_token** as the isolation/auth boundary for task writes
- **Append-only event stream** for action auditability
- **Runtime usage events** in the same event pipeline for token/cost/duration telemetry
- **Postgres projections** for UI and analytics

This is cleaner than treating the task ledger as the whole observability model, and cleaner than treating action taxonomy alone as the whole system.
