# Orchestrator Tooling Helpers

These tools are for the Orchestrator only. Other agents do not read or write the task ledger and do not need these scripts.

## Dispatch mechanisms

The Orchestrator has two distinct, non-interchangeable dispatch paths. Using the wrong path for the wrong target is the root cause of agents silently spawning wrong-type workers.

### Path A — named-agent dispatch (`scripts/dispatch-named-agent.sh`)

Use this for every project-scoped named agent: `spec-<project>`, `builder-<project>`, `qa-<project>`, `security-<project>`, `release-manager-<project>`.

- Sends work directly into the **existing** named-agent session.
- Does **not** spawn a new session or thread.
- Fails with a clear error and non-zero exit if the named agent is unavailable.
- **Never** falls back to a generic sub-agent. Surface unavailability as a blocker.

```bash
scripts/dispatch-named-agent.sh <project> <archetype> <task-file> [task-suffix] [thinking]

# Examples:
scripts/dispatch-named-agent.sh merlin spec issue-5.md
scripts/dispatch-named-agent.sh merlin builder issue-5.md issue-5
scripts/dispatch-named-agent.sh merlin qa pr-review.md pr-42 low
```

Decision rule: if a named project agent for the target role exists, always use Path A. The named agent routing hard rule applies before anything else. Do not use Path B for a role that has a project-scoped named agent.

### Path B — generic ephemeral worker spawn (`scripts/direct-spawn-archetype.sh`)

Use this **only** when you genuinely need a fresh, disposable worker with no session continuity requirement. Typical uses: specialist sub-agents (typescript-engineer, threat-modeller, etc.), one-shot research tasks, temporary spikes with no ongoing project session.

- Spawns a **new** isolated session.
- Has no persistent session identity.
- Always uses `sessionTarget: isolated`.
- Never the right path for `spec-<project>`, `builder-<project>`, or `qa-<project>`.

```bash
scripts/direct-spawn-archetype.sh <archetype> <project> <task-file> [label]
```

### When Path A is unavailable

If `dispatch-named-agent.sh` exits non-zero:

1. Do not silently route to Path B.
2. Record the blockage in the task ledger with state `blocked`.
3. Report to the human operator: the named agent `<archetype>-<project>` could not be reached; direct dispatch unavailable on this surface or the agent is not running.
4. Wait for operator direction before proceeding.

Substituting a generic worker when a named agent exists breaks session continuity, project context, and ACP identity. It is not a valid fallback.

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
