#!/usr/bin/env bash
set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required" >&2
  exit 1
fi

if [ $# -lt 6 ]; then
  cat >&2 <<'EOF'
Usage:
  scripts/create-agent-issue.sh <repo> <title> <archetype> <type-label> <routing-label> <body-file> [extra-label ...]

Examples:
  scripts/create-agent-issue.sh owner/repo "Add login flow" Spec feature spec-needed issue.md
  scripts/create-agent-issue.sh owner/repo "Try library X" Spec spike spec-needed spike.md architecture-needed
EOF
  exit 1
fi

REPO="$1"
TITLE="$2"
ARCHETYPE="$3"
TYPE_LABEL="$4"
ROUTING_LABEL="$5"
BODY_FILE="$6"
shift 6
EXTRA_LABELS=("$@")
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RENDERER="$ROOT_DIR/scripts/render-agent-comment.py"

if [ ! -f "$BODY_FILE" ]; then
  echo "Body file not found: $BODY_FILE" >&2
  exit 1
fi

TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

"$RENDERER" --archetype "$ARCHETYPE" --input "$BODY_FILE" > "$TMP_FILE"

LABEL_ARGS=(--label "$TYPE_LABEL" --label "$ROUTING_LABEL")
for label in "${EXTRA_LABELS[@]}"; do
  LABEL_ARGS+=(--label "$label")
done

gh issue create \
  --repo "$REPO" \
  --title "$TITLE" \
  --body-file "$TMP_FILE" \
  "${LABEL_ARGS[@]}"
