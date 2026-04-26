# QA Tooling Helpers

## Git identity

```bash
scripts/set-agent-git-identity.sh <repo-path> <name> QA
```
Set repo-local git author identity before committing.

## PR and comment posting

```bash
scripts/post-agent-comment.sh <owner/repo> pr <pr-number> QA <comment.md>
scripts/post-pr-line-comment.sh <owner/repo> <pr-number> <commit-sha> <file-path> <line> QA <comment.md>
scripts/post-bug-report.sh <owner/repo> pr <pr-number> <bug-report.md> --archetype QA
```

## Validation

```bash
# Validate README has actionable build/run/verify instructions
scripts/validate-readme-contract.sh <repo-path>

# Validate docker-compose.yml and devcontainer.json are present
scripts/validate-docker-first-project.sh <repo-path>

# Validate comment body, git identity format
scripts/validate-agent-artifacts.py --comment-file <comment.md> --git-name "Quinn (QA)" --git-email "bot-qa@example.com"

# Lint markdown before posting
scripts/lint-agent-markdown.py <file.md>
```

## Specialist spawn

```bash
# Merge base template + task refinement into spawn payload
scripts/prepare-specialist-spawn.py agents/specialists/<template>.md <refinement.md> --output specialist-prompt.md
```

## Task Ledger MCP

QA reads task state from the MCP ledger for context. QA may attach QA findings and artifact references only when Orchestrator has included the `project_token` in the task packet for that purpose. This is a per-task grant, not a standing permission.

### Read task state (no token required)

```
task_get task_id=<uuid>
task_list project_slug=<slug> state=qa_review
task_history task_id=<uuid>
```

### Attach a QA finding note or artifact link (token required)

```
task_add_note
  task_id=<uuid>
  project_id=<uuid>
  project_token=<token>
  note="QA: 3 failing assertions in auth flow. See PR comment #42."
  author_type=qa
  author_id=qa-<project>

task_link_artifact
  task_id=<uuid>
  project_id=<uuid>
  project_token=<token>
  artifact_kind=pr           # issue | pr | branch | commit | wiki | decision-record | release
  artifact_ref=<pr-number>
  url=https://github.com/<owner>/<repo>/pull/<n>
```

QA does **not** call `task_transition`, `task_update`, or `task_invalidate`. Lifecycle transitions belong to Orchestrator.
