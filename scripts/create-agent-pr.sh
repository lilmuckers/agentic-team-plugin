#!/usr/bin/env bash
set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required" >&2
  exit 1
fi

if [ $# -lt 7 ]; then
  cat >&2 <<'EOF'
Usage:
  scripts/create-agent-pr.sh <repo> <base> <head> <title> <archetype> <body-file> <draft|ready>

Examples:
  scripts/create-agent-pr.sh owner/repo main feat/login "feat(auth): add login flow" Builder pr.md draft
  scripts/create-agent-pr.sh owner/repo main feat/docs "docs(spec): clarify setup" Spec pr.md ready
EOF
  exit 1
fi

REPO="$1"
BASE="$2"
HEAD="$3"
TITLE="$4"
ARCHETYPE="$5"
BODY_FILE="$6"
STATE="$7"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RENDERER="$ROOT_DIR/scripts/render-agent-pr-body.py"

if [ ! -f "$BODY_FILE" ]; then
  echo "Body file not found: $BODY_FILE" >&2
  exit 1
fi

TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

"$RENDERER" --archetype "$ARCHETYPE" --input "$BODY_FILE" > "$TMP_FILE"

ARGS=(--repo "$REPO" --base "$BASE" --head "$HEAD" --title "$TITLE" --body-file "$TMP_FILE")
case "$STATE" in
  draft)
    ARGS+=(--draft)
    ;;
  ready)
    ;;
  *)
    echo "State must be 'draft' or 'ready'" >&2
    exit 1
    ;;
esac

gh pr create "${ARGS[@]}"
