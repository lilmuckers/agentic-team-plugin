# Callback Report Schema

Callbacks use a compact line-keyed format — not markdown prose. The detail lives in the GitHub artifact. The callback is the routing envelope.

## Format

```
FROM: <agent-id>
TO: <agent-id>
TASK: <task-id>
STATUS: <status>
REF: <url>
CHECKS: <summary>
BLOCKERS: <summary>
NEXT: <instruction>
```

One key per line. No blank lines between keys. No markdown headings. Keys are uppercase. Values are free text on the same line.

## Required keys (all statuses)

| Key | Description |
|-----|-------------|
| `FROM` | Sending agent identity, e.g. `builder-lapwing` |
| `TO` | Receiving agent identity, e.g. `orchestrator-lapwing` |
| `TASK` | Task ledger ID, e.g. `TASK-007` |
| `STATUS` | Exactly one of: `DONE` `BLOCKED` `FAILED` `NEEDS_REVIEW` |
| `BLOCKERS` | Active blockers, or `none` |
| `NEXT` | Explicit recommended next action for the receiver |

## Conditional keys

| Key | Required when | Description |
|-----|--------------|-------------|
| `REF` | STATUS is `DONE` or `NEEDS_REVIEW` | URL to the primary artifact (PR, issue, release, tag). Human-readable detail lives there — do not duplicate it here. |
| `CHECKS` | STATUS is `NEEDS_REVIEW` | One-line summary of validation performed, e.g. `unit pass, lint clean, docker build ok` |

## Two-tier rule

**DONE / NEEDS_REVIEW** — compact only. `REF` is required. Do not write prose summaries of what changed; the artifact has that.

**BLOCKED / FAILED** — compact by default, but `BLOCKERS` must contain enough inline detail to act on without visiting another artifact, because there may not be one. If a PR or issue does exist, include it as `REF` anyway.

## Value discipline

- Each value fits on one line. No multi-line values.
- `NEXT` should be actionable and specific: name the agent, script, or decision. Not "review the PR" — "dispatch qa-lapwing to PR#14".
- `BLOCKERS: none` is valid only for DONE and NEEDS_REVIEW.

## Examples

### NEEDS_REVIEW
```
FROM: builder-lapwing
TO: orchestrator-lapwing
TASK: TASK-007
STATUS: NEEDS_REVIEW
REF: https://github.com/org/lapwing/pull/14
CHECKS: unit pass, lint clean, docker build ok
BLOCKERS: none
NEXT: dispatch qa-lapwing to PR#14
```

### DONE
```
FROM: qa-lapwing
TO: orchestrator-lapwing
TASK: TASK-007
STATUS: DONE
REF: https://github.com/org/lapwing/pull/14
BLOCKERS: none
NEXT: apply qa-approved label and route to spec-lapwing for spec-satisfied check
```

### BLOCKED (no artifact yet)
```
FROM: builder-lapwing
TO: orchestrator-lapwing
TASK: TASK-009
STATUS: BLOCKED
BLOCKERS: push rejected — remote tip 3 commits ahead, local branch diverged; rebase needed before retry
NEXT: human or orchestrator must resolve branch divergence; then re-dispatch builder-lapwing to TASK-009
```

### FAILED (artifact exists)
```
FROM: qa-lapwing
TO: orchestrator-lapwing
TASK: TASK-012
STATUS: FAILED
REF: https://github.com/org/lapwing/pull/22
BLOCKERS: 3 critical findings blocking merge — see PR review; regression in auth session timeout
NEXT: send changes-requested to builder-lapwing; remove qa-approved if present
```

## Rules

- Every required key must appear exactly once, in order.
- `STATUS` must be exactly one of the four valid values.
- `TO` must name a specific agent — `orchestrator-<project>` unless this is an internal sub-agent report to a named parent.
- `REF` must be a URL when present.
- `BLOCKERS` must not be empty — use `none` explicitly when there are none.
- `NEXT` must not be empty.
- The callback must be sent immediately on task completion or blockage — do not wait for a heartbeat or cron prompt.
- A callback is only complete when `scripts/send-agent-callback.sh` exits 0. Writing the file does not constitute a callback.
