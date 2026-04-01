#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  cat >&2 <<'EOF'
Usage:
  scripts/get-runtime-bundle-path.sh <archetype>

Examples:
  scripts/get-runtime-bundle-path.sh orchestrator
  scripts/get-runtime-bundle-path.sh spec
EOF
  exit 1
fi

ARCHETYPE="$1"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE_PATH="$ROOT_DIR/.active/framework/.runtime/${ARCHETYPE}.md"

if [ ! -f "$BUNDLE_PATH" ]; then
  echo "Runtime bundle not found: $BUNDLE_PATH" >&2
  exit 1
fi

printf '%s\n' "$BUNDLE_PATH"
