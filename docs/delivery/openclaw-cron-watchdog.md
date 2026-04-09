# OpenClaw Cron Watchdog

Use native OpenClaw cron to detect overdue callbacks from the task ledger and nudge the persistent Orchestrator session.

This is a watchdog only. Normal completion still depends on explicit callbacks.

## Inputs

- Ledger file: `docs/delivery/task-ledger.md`
- Overdue detector: `scripts/check-task-ledger-overdue.py`
- Target session: `session:<project>-orchestrator`

## Ledger expectation

When Orchestrator delegates work that expects a callback, record:

- `owner` — the accountable named agent
- `expected_callback_at` — the latest acceptable callback timestamp in UTC

Example update:

```bash
scripts/update-task-ledger.py docs/delivery/task-ledger.md ISSUE-42 "Implement login" in_progress \
  "Builder implementing login flow" \
  "QA review after PR is opened" \
  --owner builder-my-project \
  --expected-callback-at 2026-04-09T14:30:00Z \
  --history-action "Delegated to Builder"
```

## Suggested cron cadence

Every 30 minutes during active delivery hours.

## Suggested OpenClaw cron action

Run a command equivalent to:

```bash
python3 /data/.openclaw/workspace/scripts/check-task-ledger-overdue.py \
  /data/.openclaw/workspace/docs/delivery/task-ledger.md \
  --grace-minutes 15
```

Interpretation:
- exit `0` — no overdue entries
- exit `2` — overdue entries found; send the JSON payload to the Orchestrator session as the watchdog nudge
- exit `1` — configuration or ledger error; surface to the operator

## Nudge payload guidance

When overdue work is found, the cron-triggered message to Orchestrator should include:

1. task id
2. owning agent
3. state
4. expected callback timestamp
5. overdue duration in minutes
6. current action / next action from the ledger

## Orchestrator follow-through

On receiving a watchdog nudge, Orchestrator should:

1. inspect the linked visible artifact state first
2. determine whether the work is actually done, blocked, or missing
3. re-ping or reassign if needed
4. surface persistent ambiguity or failure to the human
