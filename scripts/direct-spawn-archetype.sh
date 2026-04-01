#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 3 ] || [ $# -gt 4 ]; then
  cat >&2 <<'EOF'
Usage:
  scripts/direct-spawn-archetype.sh <archetype> <project> <task-file> [label]

Examples:
  scripts/direct-spawn-archetype.sh orchestrator musical-statues task.md
  scripts/direct-spawn-archetype.sh builder musical-statues task.md musical-statues-builder-issue-2
EOF
  exit 1
fi

ARCHETYPE="$1"
PROJECT="$2"
TASK_FILE="$3"
LABEL="${4:-}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PREPARE="$ROOT_DIR/scripts/prepare-archetype-spawn.py"

if [ -n "$LABEL" ]; then
  "$PREPARE" --archetype "$ARCHETYPE" --project "$PROJECT" --task-file "$TASK_FILE" --label "$LABEL"
else
  "$PREPARE" --archetype "$ARCHETYPE" --project "$PROJECT" --task-file "$TASK_FILE"
fi
