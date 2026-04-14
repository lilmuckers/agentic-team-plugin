# Orchestrator Watchdog Cron

One watchdog cron job is installed per project at onboarding time, targeting only the project Orchestrator. No separate crons are created for Spec, Security, Release Manager, Builder, or QA — those agents are either ephemeral or receive their nudges from the Orchestrator itself.

## What it does

The watchdog delivers a periodic nudge to `orchestrator-<project>` instructing it to:

1. Run `scripts/check-task-ledger-overdue.py` to find in-flight tasks with overdue callbacks
2. Check visible GitHub artifact state for each overdue task
3. Classify the worker state (done-but-missed-callback / in-progress / stalled / blocked / unknown)
4. Take the appropriate action (accept implicit callback / extend window / nudge worker / escalate)
5. Update the task ledger to reflect the assessment

The watchdog is **not** the primary completion mechanism. Explicit callbacks from workers via `scripts/send-agent-callback.sh` remain authoritative. The cron exists only to catch missed callbacks, stalled sessions, and overdue in-flight work.

## Installation

`scripts/onboard-project.sh` installs the watchdog automatically unless `--no-watchdog` is passed. To install or update manually:

```bash
scripts/install-project-watchdog.sh <project>
scripts/install-project-watchdog.sh <project> --cadence "*/15 * * * *"
```

To verify the cron is installed:
```bash
openclaw cron list | grep <project>-orchestrator-watchdog
```

To remove it:
```bash
scripts/install-project-watchdog.sh <project> --disable
```

## Cron properties

| Property | Value |
|----------|-------|
| Cron name | `<project>-orchestrator-watchdog` |
| Target agent | `orchestrator-<project>` |
| Default schedule | `*/30 * * * *` (every 30 minutes) |
| Thinking level | `low` (watchdog check, not implementation) |

The cron name is project-scoped so multiple projects can coexist in the same OpenClaw instance without collision.

## Idempotency

`install-project-watchdog.sh` removes any existing cron with the same name before recreating it. Re-running onboarding or changing the cadence does not accumulate duplicate jobs.

## Task ledger integration

When Orchestrator delegates work that expects a callback, it should record:

- `owner` — the accountable named agent
- `expected_callback_at` — the latest acceptable callback timestamp in UTC

Example:
```bash
scripts/update-task-ledger.py repo/docs/delivery/task-ledger.md \
  ISSUE-42 "Implement login" in_progress \
  "Builder implementing login flow" \
  "QA review after PR is opened" \
  --owner builder-<project> \
  --expected-callback-at 2026-04-14T14:30:00Z \
  --history-action "Delegated to Builder"
```

Without `expected_callback_at`, the overdue detector skips that task. Tasks without a callback deadline are not watchdogged.

## Overdue detector exit codes

| Exit | Meaning | Orchestrator action |
|------|---------|---------------------|
| 0 | No overdue entries | Stop — nothing to do |
| 1 | Ledger error | Surface to operator immediately |
| 2 | Overdue entries found (JSON on stdout) | Inspect each entry, classify, act |

## Classification default rule

For overdue entries, Orchestrator applies this priority order:

1. Explicit blocker in GitHub artifact → `BLOCKED`
2. Completion artifact (merged PR, closed issue) → `DONE-BUT-MISSED-CALLBACK`
3. Active progress (recent commit, open PR, comment) → `IN-PROGRESS`
4. Named owner, no blocker, no artifact → **`STALLED`** (default)
5. Malformed entry, missing/unresolvable owner → `UNKNOWN`

Absence of visible artifact is **not** grounds for `UNKNOWN`. If a named agent owns the task and the only evidence is silence, classify as `STALLED` and nudge the owner. `UNKNOWN` is reserved for entries where the ledger itself cannot identify a safe nudge target.

## Active-hours scheduling (optional)

To reduce overnight noise, set a schedule that runs only during business hours. For example, UTC business hours:

```bash
scripts/install-project-watchdog.sh <project> --cadence "*/30 8-20 * * 1-5"
```

Adjust the hours and days to match your operator timezone (set in `config/framework.yaml`).

## Repeated stalls

If the same task appears as STALLED or UNKNOWN across consecutive watchdog passes, Orchestrator must escalate to the human operator rather than re-pinging the worker indefinitely. Two consecutive nudges without progress is the threshold for escalation.
