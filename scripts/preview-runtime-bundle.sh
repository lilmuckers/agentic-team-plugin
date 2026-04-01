#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  cat >&2 <<'EOF'
Usage:
  scripts/preview-runtime-bundle.sh <archetype> [lines]

Examples:
  scripts/preview-runtime-bundle.sh orchestrator
  scripts/preview-runtime-bundle.sh spec 80
EOF
  exit 1
fi

ARCHETYPE="$1"
LINES="${2:-120}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE_PATH="$($ROOT_DIR/scripts/get-runtime-bundle-path.sh "$ARCHETYPE")"

sed -n "1,${LINES}p" "$BUNDLE_PATH"
