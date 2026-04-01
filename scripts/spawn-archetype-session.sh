#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 2 ]; then
  cat >&2 <<'EOF'
Usage:
  scripts/spawn-archetype-session.sh <archetype> <task-file>

Example:
  scripts/spawn-archetype-session.sh orchestrator task.md
EOF
  exit 1
fi

ARCHETYPE="$1"
TASK_FILE="$2"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE_PATH="$($ROOT_DIR/scripts/get-runtime-bundle-path.sh "$ARCHETYPE")"

if [ ! -f "$TASK_FILE" ]; then
  echo "Task file not found: $TASK_FILE" >&2
  exit 1
fi

cat <<EOF
Archetype runtime session wrapper

Archetype: $ARCHETYPE
Runtime bundle: $BUNDLE_PATH
Task file: $TASK_FILE

Use this bundle as the live source of archetype guidance when spawning the ACP session.
Recommended flow:
1. read the runtime bundle
2. read the task file
3. start the archetype session with the bundle as governing context
EOF
