# Orchestrator Tooling Helpers

These tools are for the Orchestrator only. Other agents do not read or write the task ledger and do not need these scripts.

## Task Ledger

The task ledger (`docs/delivery/task-ledger.md` in the project repo) is the Orchestrator's sole durable record of delegated work. It is not a shared coordination surface — agents receive work via ACP packets and report back via callback reports.

### `scripts/update-task-ledger.py`
Create or update a task entry in `docs/delivery/task-ledger.md`.

Supports optional operational metadata for watchdog use:
- `--owner`
- `--expected-callback-at`
- `--branch`
- `--pr`

Example:
```bash
scripts/update-task-ledger.py docs/delivery/task-ledger.md ISSUE-42 "Add login flow" in_progress \
  "Builder implementing auth UI" "QA review after PR is open" \
  --owner builder-my-project \
  --branch feat/issue-42-login \
  --expected-callback-at 2026-04-09T14:30:00Z
```

### `scripts/validate-task-ledger.py`
Validate `docs/delivery/task-ledger.md` entries.

Example:
```bash
scripts/validate-task-ledger.py docs/delivery/task-ledger.md
```

### `scripts/check-task-ledger-overdue.py`
Report overdue task-ledger entries. Used by the OpenClaw watchdog cron — not for ad hoc use by other agents.

Example:
```bash
scripts/check-task-ledger-overdue.py docs/delivery/task-ledger.md --grace-minutes 15
```
