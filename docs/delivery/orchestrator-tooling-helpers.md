# Orchestrator Tooling Helpers

## Git identity and posting

```bash
scripts/set-agent-git-identity.sh <repo-path> <name> Orchestrator
scripts/post-agent-comment.sh <owner/repo> issue <issue-number> Orchestrator <comment.md>
scripts/create-agent-issue.sh <owner/repo> "<title>" Orchestrator <type-label> <routing-label> <body.md>
scripts/validate-issue-ready.py <issue-number> --repo <owner/repo>
scripts/validate-agent-artifacts.py --comment-file <comment.md>
scripts/lint-agent-markdown.py <file.md>
scripts/validate-project-activation.sh <project-slug> <repo-path> [--require-active]
```

## Dispatch mechanisms

The Orchestrator has two distinct, non-interchangeable dispatch paths. Using the wrong path for the wrong target is the root cause of agents silently spawning wrong-type workers.

### Path A — named-agent dispatch (`scripts/dispatch-named-agent.sh`)

Use this for every project-scoped named agent: `spec-<project>`, `builder-<project>`, `qa-<project>`, `security-<project>`, `release-manager-<project>`.

- Sends work directly into the **existing** named-agent session via `openclaw agent --agent <id>`.
- Routes by **agent name only** — no synthetic `--session-id` unless a `task-suffix` is explicitly provided for task isolation. OpenClaw resolves the agent's live session by agent name internally. Forcing a synthetic session id can miss the real running session.
- Does **not** spawn a new session or thread.
- Fails with a clear error and non-zero exit if the named agent is unavailable.
- **Never** falls back to a generic sub-agent. Surface unavailability as a blocker.

**Do NOT use internal session tools for named-agent dispatch.** The `sessions_send`, `sessions_list`, `session_status`, `sessions_spawn`, and `subagents` tools operate within this agent's own session store and cannot cross agent session boundaries. Using them to dispatch to `builder-lapwing` or receive callbacks from `orchestrator-lapwing` will produce "No session found with label: ..." errors even when the target agent is correctly configured. These tools are for intra-session work only.

```bash
scripts/dispatch-named-agent.sh <project> <archetype> <task-file> [options]

# spec, qa, security — no gate flags required
scripts/dispatch-named-agent.sh merlin spec issue-5.md
scripts/dispatch-named-agent.sh merlin qa pr-review.md --task-suffix pr-42 --thinking low

# builder — --repo-path required; project must be ACTIVE or dispatch is blocked
scripts/dispatch-named-agent.sh merlin builder issue-5.md \
  --repo-path ../merlin --task-suffix issue-5

# release-manager — --release-issue and --release-repo required;
# tracking issue must have valid trigger, version, scale, scope basis
scripts/dispatch-named-agent.sh merlin release-manager release-task.md \
  --release-issue 42 --release-repo org/merlin
```

These gates are enforced in the script — they cannot be bypassed by prompt instruction.

Decision rule: if a named project agent for the target role exists, always use Path A. The named agent routing hard rule applies before anything else. Do not use Path C for a role that has a project-scoped named agent.

### Path A — delivery vs. completion (critical distinction)

A successful `dispatch-named-agent.sh` exit confirms **delivery only** — the task message reached the named agent's session. It does NOT mean the task is complete.

Task completion is confirmed only when the named agent sends an explicit callback using `scripts/send-agent-callback.sh`. Do not treat the dispatch return value as the authoritative completion signal. Do not advance workflow state on dispatch success alone.

### Path B — callback receipt (`scripts/send-agent-callback.sh` — used by named agents, not Orchestrator)

Named agents (Spec, Builder, QA, Security, Release Manager) use this to send their completion callback back to Orchestrator. It is the authoritative completion signal.

```bash
# Run by the named agent (e.g. spec-lapwing) after completing work:
scripts/send-agent-callback.sh <project> callback.md
```

- Validates the callback file against `schemas/callback.md` before sending.
- Routes by **agent name only** (`orchestrator-<project>`) — no synthetic session id. OpenClaw resolves the Orchestrator's live session internally.
- Exits non-zero if delivery fails, with instructions to retry or notify the operator.

### Path C — generic ephemeral worker spawn (`scripts/direct-spawn-archetype.sh`)

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
2. Call `task_transition to_state=blocked` + `task_add_note` with reason `agent-unreachable`.
3. Report to the human operator: the named agent `<archetype>-<project>` could not be reached; direct dispatch unavailable on this surface or the agent is not running.
4. Wait for operator direction before proceeding.

Substituting a generic worker when a named agent exists breaks session continuity, project context, and ACP identity. It is not a valid fallback.

## Task Ledger MCP

The MCP ledger is the canonical source of task state. Orchestrator is the primary writer and holds the `project_token`. See `docs/delivery/task-mcp-operating-model.md` for the full model and `skills/task-ledger-mcp/SKILL.md` for the operational contract.

### Project token

The `project_token` is generated once at `project_create` and stored in Orchestrator's workspace config. Never commit it to the project repo. If lost, rotate it:

```
project_rotate_token project_id=<uuid> project_token=<current-token>
```

### Creating a task (on delegation)

```
task_create
  project_id=<uuid>
  project_token=<token>
  kind=feature          # feature | bug | change | chore | spike | release | triage | meta
  title="Add login flow"
  state=new
  priority=high
  owner_agent_type=builder
  owner_agent_id=builder-<project>
  issue_number=42
  next_action="Builder implementing auth UI"
  expected_callback_at=2026-04-09T14:30:00Z
```

Returns `task_id` (UUID) and `task_key` (e.g. `MYPROJECT-7`). Record the `task_id` for all subsequent calls.

### Updating task fields (branch, PR, next_action)

```
task_update
  task_id=<uuid>
  project_id=<uuid>
  project_token=<token>
  revision=<current-revision>
  branch=feat/issue-42-login
  pr_number=17
  next_action="QA review after PR is open"
  expected_callback_at=2026-04-09T16:00:00Z
```

### Transitioning task state

```
task_transition
  task_id=<uuid>
  project_id=<uuid>
  project_token=<token>
  from_state=building
  to_state=reviewing
  revision=<current-revision>
  reason_code=pr-ready
  summary="PR #17 open and ready for QA"
  next_action="QA review"
  owner_agent_type=qa
  owner_agent_id=qa-<project>
```

Always supply `from_state` and `revision`. If rejected with `revision_mismatch`, call `task_get` to re-read current state before retrying.

### Querying tasks (session start / overdue check)

```
# All open tasks for a project
task_list project_slug=<slug>

# Overdue tasks only
task_list project_slug=<slug> overdue=true

# Tasks blocked
task_list project_slug=<slug> state=blocked

# Tasks owned by a specific agent
task_list project_slug=<slug> owner_agent_id=builder-<project>
```

### Fetching a specific task

```
task_get task_id=<uuid>
```

### Adding a note (blockers, routing context, callbacks)

```
task_add_note
  task_id=<uuid>
  project_id=<uuid>
  project_token=<token>
  note="Builder reported BLOCKED: CI configuration missing. Escalated to human."
  author_type=orchestrator
  author_id=orchestrator-<project>
```

### Linking an artifact (issue, PR, branch, commit)

```
task_link_artifact
  task_id=<uuid>
  project_id=<uuid>
  project_token=<token>
  artifact_kind=pr        # issue | pr | branch | commit | wiki | decision-record | release
  artifact_ref=17
  url=https://github.com/<owner>/<repo>/pull/17
```

### Full history for a task

```
task_history task_id=<uuid>
```

Returns task record, all state transitions, notes, and artifact links in chronological order.

### Soft-deleting a task

```
task_invalidate
  task_id=<uuid>
  project_id=<uuid>
  project_token=<token>
  reason_code=duplicate   # or: superseded | cancelled | out-of-scope
  summary="Superseded by issue #51"
```

Invalid tasks are excluded from `task_list` by default. Pass `include_invalid=true` to include them.

---

### Legacy scripts (superseded)

The following scripts are superseded by MCP tool calls and should not be used for new work:

| Script | Replaced by |
|---|---|
| `scripts/update-task-ledger.py` | `task_create`, `task_update`, `task_transition` |
| `scripts/validate-task-ledger.py` | `task_list` + `task_get` |
| `scripts/check-task-ledger-overdue.py` | `task_list overdue=true` |
