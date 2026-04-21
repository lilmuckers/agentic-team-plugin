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
