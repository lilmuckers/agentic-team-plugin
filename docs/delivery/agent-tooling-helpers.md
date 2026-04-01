# Agent Tooling Helpers

## Purpose

Provide small helper scripts that make the framework's identity and GitHub-posting rules practical.

These helpers do not replace judgment, but they reduce drift in routine execution.

## Included helpers

### `scripts/set-agent-git-identity.sh`
Configure repo-local Git author identity for a specific agent.

Format enforced:
- `<Name> (<Archetype>) <bot-<archetype-slug>@patrick-mckinley.com>`

Example:
```bash
scripts/set-agent-git-identity.sh . Cohen Orchestrator
```

### `scripts/render-agent-comment.py`
Render a GitHub-ready markdown body that begins with the required archetype header.

Example:
```bash
scripts/render-agent-comment.py --archetype Orchestrator --input comment.md
```

Output starts with:
```md
> _posted by **Orchestrator**_
```

### `scripts/post-agent-comment.sh`
Post a GitHub issue or PR comment with the required archetype header already applied.

Examples:
```bash
scripts/post-agent-comment.sh owner/repo issue 12 Orchestrator comment.md
scripts/post-agent-comment.sh owner/repo pr 55 QA review.md
```

### `scripts/create-agent-issue.sh`
Create an issue with standardized markdown body rendering and the required high-level type + routing labels.

Examples:
```bash
scripts/create-agent-issue.sh owner/repo "Add login flow" Spec feature spec-needed issue.md
scripts/create-agent-issue.sh owner/repo "Try library X" Spec spike spec-needed spike.md architecture-needed
```

### `scripts/render-agent-pr-body.py`
Render a GitHub-ready PR body that begins with the required archetype header.

Example:
```bash
scripts/render-agent-pr-body.py --archetype Builder --input pr.md
```

### `scripts/create-agent-pr.sh`
Create a PR with standardized markdown rendering and the required archetype header.

Examples:
```bash
scripts/create-agent-pr.sh owner/repo main feat/login "feat(auth): add login flow" Builder pr.md draft
scripts/create-agent-pr.sh owner/repo main feat/docs "docs(spec): clarify setup" Spec pr.md ready
```

### `scripts/update-agent-pr-body.sh`
Update a PR body while keeping the archetype header and GitHub-renderable markdown structure intact.

Example:
```bash
scripts/update-agent-pr-body.sh owner/repo 42 Builder pr-update.md
```

## Expectations

- issue bodies, PR bodies, and comments should still be written as GitHub-flavored markdown
- these helpers support the policy; they do not excuse low-quality content
- use repo-local Git identity configuration so different project repos can be authored by different agent archetypes cleanly
- use the issue/PR creation helpers to reduce formatting and labeling drift across agents

## Likely future helpers

- wiki update helpers
- archetype bootstrap helpers
- markdown lint/render validation for GitHub-visible text
- label validation helpers for existing issues and PRs
