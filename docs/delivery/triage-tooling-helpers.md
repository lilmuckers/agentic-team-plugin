# Triage Tooling Helpers

## Git identity

```bash
scripts/set-agent-git-identity.sh <repo-path> <name> Triage
```
Set repo-local git author identity before committing.

## PR and comment posting

```bash
scripts/post-agent-comment.sh <owner/repo> issue <issue-number> Triage <comment.md>
scripts/post-agent-comment.sh <owner/repo> pr <pr-number> Triage <comment.md>
scripts/post-bug-report.sh <owner/repo> issue <issue-number> <triage-report.md> --archetype Triage
```

## Callback

```bash
# Validate callback before sending
scripts/validate-callback.py callback.md

# Send callback to Orchestrator (or Spec if directed)
scripts/send-agent-callback.sh <project> callback.md
```

## Validation

```bash
# Validate comment body, git identity format
scripts/validate-agent-artifacts.py --comment-file <comment.md> --git-name "Triage (Triage)" --git-email "bot-triage@example.com"

# Lint markdown before posting
scripts/lint-agent-markdown.py <file.md>
```

## Task Ledger MCP

Triage reads task state from the MCP ledger. Triage may attach diagnostic notes and artifact links only when Orchestrator has included the `project_token` in the task packet for that purpose. This is a per-task grant, not a standing permission.

### Read current task state (no token required)

```
task_get task_id=<uuid>
task_list project_slug=<slug> state=triage
task_history task_id=<uuid>
```

### Attach a diagnostic note

```
task_add_note
  task_id=<uuid>
  project_id=<uuid>
  project_token=<token>
  note="Reproduced consistently on v1.4.2 with clipboard timer active during suspend."
  author_type=triage
  author_id=triage-<project>
```

### Attach an evidence artifact

```
task_link_artifact
  task_id=<uuid>
  project_id=<uuid>
  project_token=<token>
  artifact_kind=issue        # issue | pr | branch | commit | wiki | decision-record | release
  artifact_ref=<issue-number-or-ref>
  url=https://github.com/<owner>/<repo>/issues/<n>
```

Triage does **not** call `task_transition`, `task_update`, or `task_invalidate`. Lifecycle transitions belong to Orchestrator.
