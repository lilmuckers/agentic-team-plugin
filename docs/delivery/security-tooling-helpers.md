# Security Tooling Helpers

## PR and comment posting

```bash
scripts/post-agent-comment.sh <owner/repo> pr <pr-number> Security <comment.md>
scripts/post-pr-line-comment.sh <owner/repo> <pr-number> <commit-sha> <file-path> <line> <comment.md>
scripts/post-bug-report.sh <owner/repo> pr <pr-number> <bug-report.md> --archetype Security
```

## Validation

```bash
# Validate comment body, git identity format
scripts/validate-agent-artifacts.py --comment-file <comment.md>

# Lint markdown before posting
scripts/lint-agent-markdown.py <file.md>
```

## Specialist spawn

```bash
# Merge base template + task refinement into spawn payload
scripts/prepare-specialist-spawn.py agents/specialists/<template>.md <refinement.md> --output specialist-prompt.md
# Relevant templates: threat-modeller.md, dependency-auditor.md, qa-security.md
```
