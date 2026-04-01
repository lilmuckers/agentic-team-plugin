#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 3 ] || [ $# -gt 6 ]; then
  cat >&2 <<'EOF'
Usage:
  scripts/invoke-named-agent.sh <project> <agent> <message-file> [task-suffix] [thinking] [verbose]

Examples:
  scripts/invoke-named-agent.sh musical-statues orchestrator orchestrator.md
  scripts/invoke-named-agent.sh musical-statues builder issue-2.md issue-2 low on
EOF
  exit 1
fi

PROJECT="$1"
AGENT="$2"
MESSAGE_FILE="$3"
TASK_SUFFIX="${4:-}"
THINKING="${5:-minimal}"
VERBOSE_MODE="${6:-off}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SESSION_GEN="$ROOT_DIR/scripts/agent-session-id.py"

if [ ! -f "$MESSAGE_FILE" ]; then
  echo "Message file not found: $MESSAGE_FILE" >&2
  exit 1
fi

if [ -n "$TASK_SUFFIX" ]; then
  SESSION_ID="$(python3 "$SESSION_GEN" --project "$PROJECT" --agent "$AGENT" --task "$TASK_SUFFIX")"
else
  SESSION_ID="$(python3 "$SESSION_GEN" --project "$PROJECT" --agent "$AGENT")"
fi

MESSAGE="$(cat "$MESSAGE_FILE")"

echo "Invoking named agent: $AGENT"
echo "Session id: $SESSION_ID"
openclaw agent --agent "$AGENT" --session-id "$SESSION_ID" --message "$MESSAGE" --thinking "$THINKING" --verbose "$VERBOSE_MODE" --json
