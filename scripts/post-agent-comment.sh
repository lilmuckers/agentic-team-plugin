#!/usr/bin/env bash
set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required" >&2
  exit 1
fi

if [ $# -lt 4 ]; then
  cat >&2 <<'EOF'
Usage:
  scripts/post-agent-comment.sh <repo> <issue|pr> <number> <archetype> [body-file]

Examples:
  scripts/post-agent-comment.sh owner/repo issue 12 Orchestrator comment.md
  scripts/post-agent-comment.sh owner/repo pr 55 QA review.md
EOF
  exit 1
fi

REPO="$1"
TARGET_KIND="$2"
NUMBER="$3"
ARCHETYPE="$4"
BODY_FILE="${5:-}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RENDERER="$ROOT_DIR/scripts/render-agent-comment.py"

if [ ! -x "$RENDERER" ]; then
  echo "Renderer is not executable: $RENDERER" >&2
  exit 1
fi

TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

if [ -n "$BODY_FILE" ]; then
  "$RENDERER" --archetype "$ARCHETYPE" --input "$BODY_FILE" > "$TMP_FILE"
else
  "$RENDERER" --archetype "$ARCHETYPE" > "$TMP_FILE"
fi

case "$TARGET_KIND" in
  issue)
    gh issue comment "$NUMBER" --repo "$REPO" --body-file "$TMP_FILE"
    ;;
  pr)
    gh pr comment "$NUMBER" --repo "$REPO" --body-file "$TMP_FILE"
    ;;
  *)
    echo "Target kind must be 'issue' or 'pr'" >&2
    exit 1
    ;;
esac
