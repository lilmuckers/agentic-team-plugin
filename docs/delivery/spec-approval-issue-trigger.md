# Spec Approval Issue Trigger

## Purpose

Define the concrete GitHub-visible trigger that moves Orchestrator from guided setup mode into autonomous delivery mode.

## Core rule
Automation mode should begin when the designated spec-approval issue is marked completed/closed.

## Why this is better than implicit approval
Using a visible GitHub issue state as the trigger provides:
- a deterministic activation boundary
- a reviewable audit trail
- less ambiguity than informal chat approval
- a project artefact Orchestrator can reason about directly

## Recommended issue characteristics
- owned by Spec
- clearly identified as the project spec approval gate
- contains the approved project definition / acceptance summary
- linked to `SPEC.md` and relevant wiki pages

## Runtime meaning

### If the spec-approval issue is open
- Orchestrator remains in guided mode
- human approval is still required for project-definition boundaries

### If the spec-approval issue is completed/closed
- Orchestrator may move into autonomous delivery mode within the approved project bounds

## Still escalate after activation when
- scope changes materially
- architecture changes materially
- assumptions are invalidated in a way that changes project direction
- release/production approval is needed
- unusual/destructive actions need human judgment
