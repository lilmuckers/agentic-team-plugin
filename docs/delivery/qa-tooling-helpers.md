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
