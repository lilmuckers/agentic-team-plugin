# Agent Tooling Helpers

## Purpose

Provide small helper scripts that make the framework's identity and GitHub-posting rules practical.

These helpers do not replace judgment, but they reduce drift in routine execution.

## Included helpers

### `scripts/set-agent-git-identity.sh`
Configure repo-local Git author identity for a specific agent.

Format enforced:
- `<Name> (<Archetype>) <bot-<archetype-slug>@<operator-email-domain>>`

The email domain is sourced from `config/framework.yaml`.

Example:
```bash
scripts/set-agent-git-identity.sh . Orchestrator Orchestrator
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
scripts/create-agent-issue.sh owner/repo "Release v0.2.0" ReleaseManager chore release-tracking release.md
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
  --git-email "bot-orchestrator@example.com"
```

### `scripts/validate-issue-ready.py`
Validate whether a GitHub issue is actually ready for Builder before Orchestrator routes it.

Checks include:
- high-level issue-type label present
- routing/workflow label present
- non-empty `## Acceptance Criteria`
- non-empty `## Test Strategy`
- documented assumptions or linked context
- no unresolved dependencies/blockers
- required usability sections when the issue carries user-facing requirements

Example:
```bash
scripts/validate-issue-ready.py 123 --repo owner/repo
```

### `scripts/prepare-specialist-spawn.py`
Merge a base specialist template with a task-specific refinement file.

Example:
```bash
scripts/prepare-specialist-spawn.py agents/specialists/typescript-engineer.md refinement.md --output specialist-prompt.md
```

### `scripts/validate-specialist-template.py`
Validate a specialist template in `agents/specialists/`.

Example:
```bash
scripts/validate-specialist-template.py agents/specialists/typescript-engineer.md
```

### `scripts/validate-readme-contract.sh`
Validate that a project README has actionable executable guidance.

Checks include:
- non-empty `## Build`
- non-empty `## Verify`
- either non-empty `## Run` or non-empty `## Executable Verification Path`

For application repos, Docker-first local development policy also expects `docker-compose.yml` and `devcontainer.json` at the repo root.

Example:
```bash
scripts/validate-readme-contract.sh /path/to/project-repo
```

### `scripts/validate-docker-first-project.sh`
Validate the Docker-first local-development contract for a project repo.

Checks include:
- `docker-compose.yml`
- `.devcontainer/devcontainer.json`
- README contract via `scripts/validate-readme-contract.sh`

Example:
```bash
scripts/validate-docker-first-project.sh /path/to/project-repo
```

### `scripts/validate-project-bootstrap.sh`
Validate that a downstream project repo has the framework bootstrap files installed.

Checks include:
- required issue templates
- PR template
- merge-gate workflow
- root `SPEC.md`
- `docs/delivery/release-state.md`

Example:
```bash
scripts/validate-project-bootstrap.sh /path/to/project-repo
```

### `scripts/onboard-project.sh`
Run the minimum viable project onboarding flow.

Features:
- creates or reuses project-scoped named agents
- deploys project agent workspaces
- installs repo templates, including `.github/workflows/merge-gate.yml`, into the target repo
- optionally creates GitHub labels and related setup with `--with-github-setup`
- supports `--dry-run`

### `scripts/deploy-agent-workspace-bootstrap.py`
Deploy managed workspace bootstrap files for named agents.

Flags:
- `--dry-run` shows diffs without writing
- `--force` overwrites existing managed files

All operator identity fields and workspace-root defaults come from `config/framework.yaml`.

### `scripts/validate-config.sh`
Validate the framework config before using deployment or onboarding scripts.

Examples:
```bash
scripts/validate-config.sh
scripts/validate-config.sh --file config/framework.yaml.example
```

### `scripts/check-framework-version.sh`
Compare the session's loaded framework SHA from `FRAMEWORK_NOTES.md` against the currently deployed framework SHA and print material-file diffs.

The first argument is the workspace/framework root directory. The script reads `FRAMEWORK_NOTES.md` from that directory — do not pass the file path as the argument. If `deployed-sha.txt` is absent, falls back to the SHA in `FRAMEWORK_NOTES.md`.

Example:
```bash
scripts/check-framework-version.sh .
```

### `scripts/post-pr-line-comment.sh`
Post a line-anchored review comment on a pull request. Renders the body through `render-agent-comment.py`, prepending the standard `> _posted by **<Archetype>**_` header. Body content is submitted as rendered text — never as a file path.

Example:
```bash
scripts/post-pr-line-comment.sh owner/repo 42 abc1234 src/app.tsx 87 Security review-comment.md
```

### `scripts/post-bug-report.sh`
Post a structured bug report to a PR or issue using the standard agent header.

Examples:
```bash
scripts/post-bug-report.sh owner/repo pr 42 bug-report.md
scripts/post-bug-report.sh owner/repo issue 108 bug-report.md --archetype QA
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

