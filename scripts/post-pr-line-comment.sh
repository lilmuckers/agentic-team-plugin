#!/usr/bin/env bash
set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required" >&2
  exit 1
fi

if [ $# -lt 5 ]; then
  cat >&2 <<'EOF'
Usage:
  scripts/post-pr-line-comment.sh <repo> <pr-number> <commit-sha> <file-path> <line> <body-file>
EOF
  exit 1
fi

REPO="$1"
PR_NUMBER="$2"
COMMIT_SHA="$3"
FILE_PATH="$4"
LINE="$5"
BODY_FILE="$6"

if [ ! -f "$BODY_FILE" ]; then
  echo "Body file not found: $BODY_FILE" >&2
  exit 1
fi

gh api \
  --method POST \
  "/repos/$REPO/pulls/$PR_NUMBER/comments" \
  -f body=@"$BODY_FILE" \
  -f commit_id="$COMMIT_SHA" \
  -f path="$FILE_PATH" \
  -F line="$LINE" \
  -f side=RIGHT
