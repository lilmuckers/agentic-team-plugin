#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 4 ]; then
  cat >&2 <<'EOF'
Usage:
  scripts/update-agent-wiki-page.sh <wiki-repo-path> <page-name> <archetype> <body-file>

Example:
  scripts/update-agent-wiki-page.sh ../my-repo.wiki Architecture Spec architecture.md
EOF
  exit 1
fi

WIKI_REPO_PATH="$1"
PAGE_NAME="$2"
ARCHETYPE="$3"
BODY_FILE="$4"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RENDERER="$ROOT_DIR/scripts/render-agent-wiki-page.py"
OUTPUT_PATH="$WIKI_REPO_PATH/${PAGE_NAME}.md"

if [ ! -d "$WIKI_REPO_PATH/.git" ]; then
  echo "Not a git repository: $WIKI_REPO_PATH" >&2
  exit 1
fi

if [ ! -f "$BODY_FILE" ]; then
  echo "Body file not found: $BODY_FILE" >&2
  exit 1
fi

mkdir -p "$WIKI_REPO_PATH"
"$RENDERER" --archetype "$ARCHETYPE" --input "$BODY_FILE" > "$OUTPUT_PATH"

echo "Updated wiki page: $OUTPUT_PATH"
echo "Next steps: review, commit, and push the wiki repo changes"
