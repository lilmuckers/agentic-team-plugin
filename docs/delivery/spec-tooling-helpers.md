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
