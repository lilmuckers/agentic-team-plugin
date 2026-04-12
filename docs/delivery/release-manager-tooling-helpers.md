# Release Manager Tooling Helpers

These tools are for the Release Manager only.

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

Example:
```bash
scripts/cut-release-tag.sh owner/repo v0.2.0 beta notes.md
scripts/cut-release-tag.sh owner/repo v0.2.0 final notes.md
```
