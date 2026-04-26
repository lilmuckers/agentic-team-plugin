# Spec Tooling Helpers

## Git identity

```bash
scripts/set-agent-git-identity.sh <repo-path> <name> Spec
```
Set repo-local git author identity before committing spec-owned files.

## Issue creation and commenting

```bash
# Create issue with type and routing labels
scripts/create-agent-issue.sh <owner/repo> "<title>" Spec <type-label> <routing-label> <issue-body.md>
# Example:
scripts/create-agent-issue.sh org/repo "Add login flow" Spec feature spec-needed issue.md

scripts/post-agent-comment.sh <owner/repo> issue <issue-number> Spec <comment.md>
```

## Wiki

```bash
scripts/render-agent-wiki-page.py --archetype Spec --input <page.md>
scripts/update-agent-wiki-page.sh <wiki-repo-path> <PageName> Spec <page.md>
```

## Issue readiness

```bash
# Validate an issue meets definition of ready before signalling Orchestrator
scripts/validate-issue-ready.py <issue-number> --repo <owner/repo>
```

## Validation

```bash
# Validate comment body, git identity format
scripts/validate-agent-artifacts.py --comment-file <comment.md> --git-name "Marlowe (Spec)" --git-email "bot-spec@example.com"

# Lint markdown before posting
scripts/lint-agent-markdown.py <file.md>
```

## Specialist spawn

```bash
# Merge base template + task refinement into spawn payload
scripts/prepare-specialist-spawn.py agents/specialists/<template>.md <refinement.md> --output specialist-prompt.md
```

## Task Ledger MCP

Spec reads task state from the MCP ledger for context. Spec may attach spec-owned notes and artifact references when Orchestrator has included the `project_token` in the task packet.

### Read task state (no token required)

```
task_get task_id=<uuid>
task_list project_slug=<slug>
task_list project_slug=<slug> state=specifying
task_history task_id=<uuid>
project_get project_slug=<slug>
```

### Attach a spec note or artifact link (token required)

```
task_add_note
  task_id=<uuid>
  project_id=<uuid>
  project_token=<token>
  note="Spec clarified acceptance criteria: clipboard clear must fire within 500ms of unlock."
  author_type=spec
  author_id=spec-<project>

task_link_artifact
  task_id=<uuid>
  project_id=<uuid>
  project_token=<token>
  artifact_kind=wiki        # issue | pr | branch | commit | wiki | decision-record | release
  artifact_ref=<page-name>
  url=https://github.com/<owner>/<repo>/wiki/<page>
```

Spec does **not** call `task_transition`, `task_update`, or `task_invalidate`. Lifecycle transitions belong to Orchestrator.
