# Release Manager Tooling Helpers

## Git identity and posting

```bash
scripts/set-agent-git-identity.sh <repo-path> <name> ReleaseManager
scripts/post-agent-comment.sh <owner/repo> issue <issue-number> ReleaseManager <comment.md>
scripts/update-agent-wiki-page.sh <wiki-repo-path> <PageName> ReleaseManager <page.md>
scripts/lint-agent-markdown.py <file.md>
```

## Release-specific tools

### `scripts/update-release-state.py`
Update the `## Current Release` JSON block in `docs/delivery/release-state.md`.

Example:
```bash
scripts/update-release-state.py docs/delivery/release-state.md \
  --version v0.2.0 \
  --stage beta \
  --tracking-issue '#321' \
  --beta-iteration 1 \
  --updated-by release-manager-my-project
```

### `scripts/validate-release-state.py`
Validate `docs/delivery/release-state.md` structure and the current-release JSON payload.

Example:
```bash
scripts/validate-release-state.py docs/delivery/release-state.md
```

### `scripts/check-release-issues.sh`
List GitHub issues carrying a specific release label.

Example:
```bash
scripts/check-release-issues.sh owner/repo release:v0.2.0 --state open
```

### `scripts/generate-release-notes.sh`
Generate two-section release notes from Git history and optionally closed GitHub issues for a release label.

Example:
```bash
scripts/generate-release-notes.sh v0.2.0 v0.1.0 owner/repo
```

### `scripts/cut-release-tag.sh`
Create an annotated Git tag and matching GitHub pre-release or final release.

For **final** stage, `--release-issue` is required. The script calls
`guard-final-release.sh` to verify human approval is recorded before tagging.
It will exit non-zero and block the release if approval is not confirmed.

```bash
scripts/cut-release-tag.sh owner/repo v0.2.0 beta notes.md
scripts/cut-release-tag.sh owner/repo v0.2.0 rc notes.md
scripts/cut-release-tag.sh owner/repo v0.2.0 final notes.md --release-issue 42
```

### `scripts/guard-final-release.sh`
Standalone check: verify explicit human approval is recorded on the release
tracking issue before final publication. Called automatically by
`cut-release-tag.sh` for final stage, but can be run independently.

```bash
scripts/guard-final-release.sh <issue-number> <owner/repo>
```
