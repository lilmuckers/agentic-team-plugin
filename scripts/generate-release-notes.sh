#!/usr/bin/env bash
set -euo pipefail

if ! command -v git >/dev/null 2>&1; then
  echo "git is required" >&2
  exit 1
fi

if [ $# -lt 1 ]; then
  cat >&2 <<'EOF'
Usage:
  scripts/generate-release-notes.sh <version> [since-ref] [repo]

Examples:
  scripts/generate-release-notes.sh v0.2.0 v0.1.0
  scripts/generate-release-notes.sh v0.2.0 v0.1.0 owner/repo
EOF
  exit 1
fi

VERSION="$1"
SINCE_REF="${2:-}"
REPO="${3:-}"
RANGE_ARGS=()
if [ -n "$SINCE_REF" ]; then
  RANGE_ARGS+=("${SINCE_REF}..HEAD")
fi

TMP_COMMITS="$(mktemp)"
TMP_ISSUES="$(mktemp)"
trap 'rm -f "$TMP_COMMITS" "$TMP_ISSUES"' EXIT

if [ "${#RANGE_ARGS[@]}" -gt 0 ]; then
  git log --no-merges --pretty=format:'- %s (%h)' "${RANGE_ARGS[@]}" > "$TMP_COMMITS"
else
  git log --no-merges --pretty=format:'- %s (%h)' > "$TMP_COMMITS"
fi

if [ -n "$REPO" ] && command -v gh >/dev/null 2>&1; then
  LABEL="release:${VERSION}"
  gh issue list --repo "$REPO" --limit 200 --state closed --label "$LABEL" --json number,title,url > "$TMP_ISSUES" || echo '[]' > "$TMP_ISSUES"
else
  echo '[]' > "$TMP_ISSUES"
fi

cat <<EOF
# Release ${VERSION}

## Included Changes
EOF

if [ -s "$TMP_COMMITS" ]; then
  cat "$TMP_COMMITS"
else
  echo "- No commits found for the requested range"
fi

cat <<'EOF'

## Closed Issues
EOF

python3 - <<'PY' "$TMP_ISSUES"
import json
import sys
from pathlib import Path
payload = json.loads(Path(sys.argv[1]).read_text())
if not payload:
    print("- No closed issues found for the release label")
else:
    for item in payload:
        print(f"- #{item['number']} {item['title']} ({item['url']})")
PY
