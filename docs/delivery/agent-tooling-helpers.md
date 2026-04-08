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

### `scripts/render-agent-wiki-page.py`
Render a wiki page body with the required archetype header.

Example:
```bash
scripts/render-agent-wiki-page.py --archetype Spec --input architecture.md
```

### `scripts/update-agent-wiki-page.sh`
Write a standardized markdown page into a checked-out GitHub wiki repository.

Example:
```bash
scripts/update-agent-wiki-page.sh ../my-repo.wiki Architecture Spec architecture.md
```

### `scripts/validate-agent-artifacts.py`
Validate common framework rules for GitHub-facing text and agent identity values.

Checks available include:
- attribution header presence
- empty body detection
- unbalanced code fences
- semantic commit subject format
- git name format
- git email format

Example:
```bash
scripts/validate-agent-artifacts.py \
  --comment-file comment.md \
  --commit-subject "feat(repo): add helper" \
  --git-name "Cohen (Orchestrator)" \
  --git-email "bot-orchestrator@patrick-mckinley.com"
```

### `scripts/validate-issue-ready.py`
Validate whether a GitHub issue is actually ready for Builder before Orchestrator routes it.

Checks include:
- high-level issue-type label present
- routing/workflow label present
- non-empty `## Acceptance Criteria`
- documented assumptions or linked context
- no unresolved dependencies/blockers

Example:
```bash
scripts/validate-issue-ready.py 123 --repo owner/repo
```

### `scripts/validate-task-ledger.py`
Validate `docs/delivery/task-ledger.md` entries that use markdown headings plus embedded JSON payloads.

Checks include:
- one `## Task ...` heading per entry
- exactly one fenced `json` block per entry
- required JSON fields present
- valid task state
- non-empty history items with `at`, `action`, and `by`

Example:
```bash
scripts/validate-task-ledger.py docs/delivery/task-ledger.md
```

### `scripts/validate-decision-record.py`
Validate decision records stored in `docs/decisions/`.

Checks include:
- required markdown sections present and ordered
- valid `# Decision Record: <id>` header
- `## Date` uses `YYYY-MM-DD`
- rationale text is non-empty
- rejected alternatives, constraints, and source pointers all contain at least one bullet item

Example:
```bash
scripts/validate-decision-record.py docs/decisions/DR-001.md
```

### `scripts/lint-agent-markdown.py`
Apply lightweight lint checks to GitHub-facing markdown bodies.

Checks include:
- missing standard header
- tab characters
- very long lines
- unbalanced code fences

Example:
```bash
scripts/lint-agent-markdown.py comment.md pr.md wiki.md
```

## Expectations

- issue bodies, PR bodies, comments, and wiki pages should still be written as GitHub-flavored markdown
- these helpers support the policy; they do not excuse low-quality content
- use repo-local Git identity configuration so different project repos can be authored by different agent archetypes cleanly
- use the issue/PR creation helpers to reduce formatting and labeling drift across agents
- use validation/linting helpers before posting or committing when consistency matters

## Likely future helpers

- archetype bootstrap helpers
- label validation helpers for existing issues and PRs
- standardized draft-to-ready PR transition helpers
- wrappers that combine render + validate + post in one step
