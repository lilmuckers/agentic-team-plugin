# Builder Tooling Helpers

## Git identity

```bash
scripts/set-agent-git-identity.sh <repo-path> <name> <archetype>
```
Set repo-local git author identity before committing.

## PR and comment posting

```bash
scripts/create-agent-pr.sh <owner/repo> <base> <branch> <title> Builder <pr-body.md> draft|ready
scripts/update-agent-pr-body.sh <owner/repo> <pr-number> Builder <pr-update.md>
scripts/post-agent-comment.sh <owner/repo> pr <pr-number> Builder <comment.md>
scripts/post-pr-line-comment.sh <owner/repo> <pr-number> <commit-sha> <file-path> <line> <comment.md>
scripts/post-bug-report.sh <owner/repo> pr <pr-number> <bug-report.md>
```

## Validation

```bash
# Validate README has actionable build/run/verify instructions
scripts/validate-readme-contract.sh <repo-path>

# Validate docker-compose.yml and devcontainer.json are present
scripts/validate-docker-first-project.sh <repo-path>

# Validate comment body, commit subject, git identity format
scripts/validate-agent-artifacts.py --commit-subject "feat(x): ..." --git-name "Reeves (Builder)" --git-email "bot-builder@example.com"

# Lint markdown before posting
scripts/lint-agent-markdown.py <file.md>
```

## Specialist spawn

```bash
# Merge base template + task refinement into spawn payload
scripts/prepare-specialist-spawn.py agents/specialists/<template>.md <refinement.md> --output specialist-prompt.md
```
