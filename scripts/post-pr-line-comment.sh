#!/usr/bin/env bash
set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required" >&2
  exit 1
fi

if [ $# -lt 7 ]; then
  cat >&2 <<'EOF'
Usage:
  scripts/post-pr-line-comment.sh <repo> <pr-number> <commit-sha> <file-path> <line> <archetype> <body-file>

Example:
  scripts/post-pr-line-comment.sh owner/repo 42 abc1234 src/app.ts 87 Security comment.md
EOF
  exit 1
fi

REPO="$1"
PR_NUMBER="$2"
COMMIT_SHA="$3"
FILE_PATH="$4"
LINE="$5"
ARCHETYPE="$6"
BODY_FILE="$7"

if [ ! -f "$BODY_FILE" ]; then
  echo "Body file not found: $BODY_FILE" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RENDERER="$ROOT_DIR/scripts/render-agent-comment.py"

if [ ! -x "$RENDERER" ]; then
  echo "Renderer is not executable: $RENDERER" >&2
  exit 1
fi

TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

"$RENDERER" --archetype "$ARCHETYPE" --input "$BODY_FILE" > "$TMP_FILE"

BODY_TEXT="$(cat "$TMP_FILE")"

gh api \
  --method POST \
  "/repos/$REPO/pulls/$PR_NUMBER/comments" \
  -f body="$BODY_TEXT" \
  -f commit_id="$COMMIT_SHA" \
  -f path="$FILE_PATH" \
  -F line="$LINE" \
  -f side=RIGHT
