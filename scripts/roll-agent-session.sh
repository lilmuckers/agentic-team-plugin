#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 2 ]; then
  cat >&2 <<'EOF'
Usage:
  scripts/roll-agent-session.sh <agent-id> <message-file>

Example:
  scripts/roll-agent-session.sh orchestrator-musical-statues prompt.md
EOF
  exit 1
fi

AGENT_ID="$1"
MESSAGE_FILE="$2"

if [ ! -f "$MESSAGE_FILE" ]; then
  echo "Message file not found: $MESSAGE_FILE" >&2
  exit 1
fi

MESSAGE="$(cat "$MESSAGE_FILE")"

echo "Starting fresh session for agent: $AGENT_ID"
openclaw agent --agent "$AGENT_ID" --new-session --message "$MESSAGE" --json
