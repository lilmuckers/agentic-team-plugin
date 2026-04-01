#!/usr/bin/env bash
set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required" >&2
  exit 1
fi

if [ $# -lt 4 ]; then
  cat >&2 <<'EOF'
Usage:
  scripts/update-agent-pr-body.sh <repo> <pr-number> <archetype> <body-file>

Example:
  scripts/update-agent-pr-body.sh owner/repo 42 Builder pr-update.md
EOF
  exit 1
fi

REPO="$1"
PR_NUMBER="$2"
ARCHETYPE="$3"
BODY_FILE="$4"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RENDERER="$ROOT_DIR/scripts/render-agent-pr-body.py"

if [ ! -f "$BODY_FILE" ]; then
  echo "Body file not found: $BODY_FILE" >&2
  exit 1
fi

TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

"$RENDERER" --archetype "$ARCHETYPE" --input "$BODY_FILE" > "$TMP_FILE"

gh pr edit "$PR_NUMBER" --repo "$REPO" --body-file "$TMP_FILE"
