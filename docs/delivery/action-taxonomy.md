# Current Action Surfaces and Auditability

## Purpose

Describe the parts of the framework that are already implemented as concrete, inspectable action surfaces, and separate them from the still-proposed future structured event model.

For the future-state taxonomy and schema proposals, see:
- `docs/proposal/action-taxonomy.md`
- `docs/proposal/schemas/action-event.schema.json`
- `docs/proposal/schemas/action-types.json`
- `docs/proposal/schemas/reason-codes.json`

## What is implemented today

The framework does **not** yet emit a canonical typed event stream for every action.

It **does** already have several concrete, reviewable action surfaces:
- helper scripts with stable CLI contracts
- validator scripts that enforce workflow gates
- durable markdown/json artifacts in project repos
- named-agent role docs that define callback and routing responsibilities

That means the framework is already partly auditable, but through wrappers and artifacts rather than a unified event schema.

## Implemented durable artifacts

### Task ledger
`docs/delivery/task-ledger.md` is the Orchestrator's durable record of delegated work.

What it captures today:
- task id
- state
- current action
- next action
- owner
- branch / PR when relevant
- expected callback deadline
- transition history

Primary helpers:
- `scripts/update-task-ledger.py`
- `scripts/validate-task-ledger.py`
- `scripts/check-task-ledger-overdue.py`

### Release state
`docs/delivery/release-state.md` is the durable release coordination surface.

Primary helpers:
- `scripts/update-release-state.py`
- `scripts/validate-release-state.py`
- `scripts/validate-release-request.py`
- `scripts/guard-final-release.sh`
- `scripts/cut-release-tag.sh`

### Project activation state
`docs/delivery/project-state.md` is the durable activation gate surface for BOOTSTRAPPED, DEFINED, and ACTIVE.

Primary helper:
- `scripts/validate-project-activation.sh`

## Implemented helper-backed actions

### Routing and callbacks
These are the clearest currently implemented workflow actions.

- `scripts/dispatch-named-agent.sh`
  - delivers work to the next named agent
  - enforces important dispatch-time checks such as ACTIVE-gate and release-request validation
  - confirms delivery, not completion
- `scripts/send-agent-callback.sh`
  - sends the authoritative completion/blocker callback back to Orchestrator
- `scripts/validate-callback.py`
  - enforces callback structure before transport

Together, these give the framework a real dispatch/callback control surface even though they do not yet emit structured event objects.

### Issue and PR operations
The framework already has concrete wrappers for the main GitHub side effects:

- `scripts/create-agent-issue.sh`
- `scripts/post-agent-comment.sh`
- `scripts/create-agent-pr.sh`
- `scripts/update-agent-pr-body.sh`
- `scripts/post-pr-line-comment.sh`

These are meaningful action surfaces because they:
- take typed positional inputs
- enforce archetype identity headers
- produce visible GitHub artifacts
- are validated by framework smoke tests and framework validation

### Readiness and release gates
The framework already enforces several important workflow decisions programmatically:

- `scripts/validate-issue-ready.py`
  - definition-of-ready gate before Builder dispatch
- `scripts/validate-release-request.py`
  - release-request validation before Release Manager flow
- `scripts/guard-final-release.sh`
  - hard stop before final release publication without the required human approval

These are implemented gate actions even though they are not yet represented as event-stream entries.

## Implemented role-level action models

### Triage
Triage is now an implemented top-level archetype.

Implemented surfaces include:
- runtime role doc: `agents/triage.md`
- human reference doc: `docs/agents/triage.md`
- tooling helpers: `docs/delivery/triage-tooling-helpers.md`
- routing policy: `policies/named-agent-routing.md`
- deployment/runtime wiring in the framework scripts

What is implemented today:
- Triage as a named-agent role
- a structured triage-report output contract
- callback discipline back to Orchestrator
- routing precedence for `triage-<project>` agents

What is **not** implemented yet:
- a dedicated triage event stream
- a typed triage case id or canonical structured action emitter

## Current auditability model

In practice, the framework is currently auditable through a combination of:
- task-ledger history
- release-state history
- project-state visibility
- GitHub issues / PRs / comments
- named-agent callbacks
- wrapper-script logs and smoke tests

This is enough to inspect real workflow behavior, but it is still a wrapper-and-artifact model rather than a first-class telemetry model.

## What remains proposal-only

The following are still future-state design material, not enforced runtime contracts:
- canonical action event envelope
- canonical action type registry
- canonical reason-code registry
- framework-wide structured event emission from wrappers
- durable correlation ids and parent-child event relationships across the whole swarm

Those remain in `docs/proposal/action-taxonomy.md` and `docs/proposal/schemas/` until the wrappers actually emit them.

## Summary

The framework already has real, implemented action surfaces.
They are just uneven.

Today, the strongest implemented surfaces are:
- dispatch
- callback
- readiness validation
- release validation/guarding
- issue/PR wrapper operations
- durable task/release/project state artifacts

What is still missing is the unified typed event layer that would make all of those surfaces look like one coherent audit stream.
