#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 2 ] || [ $# -gt 4 ]; then
  cat >&2 <<'EOF'
Usage:
  scripts/spawn-archetype-agent.sh <archetype> <task-file> [label] [mode]

Examples:
  scripts/spawn-archetype-agent.sh orchestrator task.md
  scripts/spawn-archetype-agent.sh builder task.md builder-bootstrap ephemeral
EOF
  exit 1
fi

ARCHETYPE="$1"
TASK_FILE="$2"
LABEL="${3:-$ARCHETYPE}"
MODE="${4:-default}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE_PATH="$($ROOT_DIR/scripts/get-runtime-bundle-path.sh "$ARCHETYPE")"

if [ ! -f "$TASK_FILE" ]; then
  echo "Task file not found: $TASK_FILE" >&2
  exit 1
fi

python3 - <<PY
from pathlib import Path
bundle = Path(r'''$BUNDLE_PATH''').read_text()
task = Path(r'''$TASK_FILE''').read_text()
message = f"""Use the following deployed runtime bundle as the governing archetype context for this session.\n\n# Active runtime bundle\n\n{bundle}\n\n# Task\n\n{task}\n"""
Path('/tmp/openclaw-archetype-message.txt').write_text(message)
PY

case "$ARCHETYPE" in
  orchestrator|spec)
    DEFAULT_MODE="persistent-project"
    ;;
  builder|qa)
    DEFAULT_MODE="ephemeral-task"
    ;;
  *)
    DEFAULT_MODE="unspecified"
    ;;
esac

if [ "$MODE" = "default" ]; then
  MODE="$DEFAULT_MODE"
fi

echo "Spawn request prepared for archetype: $ARCHETYPE"
echo "Label: $LABEL"
echo "Mode: $MODE"
echo "Bundle: $BUNDLE_PATH"
echo
echo "Use this file as the agent-turn message payload: /tmp/openclaw-archetype-message.txt"
echo "Recommended OpenClaw integration: sessions_spawn with the generated payload and the matching session lifecycle mode."
