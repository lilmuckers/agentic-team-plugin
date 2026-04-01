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

## Expectations

- comment/post bodies should still be written as GitHub-flavored markdown
- these helpers support the policy; they do not excuse low-quality content
- use repo-local Git identity configuration so different project repos can be authored by different agent archetypes cleanly

## Likely future helpers

- PR body generation helpers
- archetype bootstrap helpers
- markdown lint/render validation for GitHub-visible text
- issue creation helpers that apply taxonomy labels consistently
