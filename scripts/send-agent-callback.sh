#!/usr/bin/env bash
set -euo pipefail

# Send an explicit callback report to the Orchestrator for this project.
#
# This is the ONLY correct mechanism for a named agent to report task
# completion or blockage back to Orchestrator. It is completely separate
# from the dispatch mechanism — the dispatch call that delivered the
# original task is NOT the callback channel.
#
# Behaviour:
#   - Validates the callback file against the callback schema before sending.
#   - Sends the callback directly into the orchestrator-<project> named session.
#   - Exits non-zero if validation fails or if the send cannot be confirmed.
#   - Does NOT fall back silently if the Orchestrator session is unreachable.
#
# When to use:
#   Every named agent (spec, builder, qa, security, release-manager) must call
#   this script when a task is complete, blocked, or failed. Do not rely on the
#   dispatch command return value as the callback.

if [ $# -lt 2 ] || [ $# -gt 3 ]; then
  cat >&2 <<'EOF'
Usage:
  scripts/send-agent-callback.sh <project> <callback-file> [thinking]

Arguments:
  project        project slug, e.g. lapwing
  callback-file  path to the validated callback report markdown file
  thinking       thinking level: minimal | low | medium | high (default: minimal)

The callback file must conform to schemas/callback.md.
Run scripts/validate-callback.py on it first, or this script will do it for you.

Examples:
  scripts/send-agent-callback.sh lapwing callback.md
  scripts/send-agent-callback.sh merlin spec-callback.md low
EOF
  exit 1
fi

PROJECT="$1"
CALLBACK_FILE="$2"
THINKING="${3:-minimal}"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VALIDATE="$ROOT_DIR/scripts/validate-callback.py"
SESSION_GEN="$ROOT_DIR/scripts/agent-session-id.py"

if [ ! -f "$CALLBACK_FILE" ]; then
  echo "ERROR: callback file not found: $CALLBACK_FILE" >&2
  exit 1
fi

# Validate before sending — a malformed callback is worse than no callback.
if ! python3 "$VALIDATE" "$CALLBACK_FILE"; then
  echo "ERROR: callback validation failed. Fix the callback file before sending." >&2
  exit 1
fi

ORCHESTRATOR_AGENT="orchestrator-${PROJECT}"
SESSION_ID="$(python3 "$SESSION_GEN" --project "$PROJECT" --agent "orchestrator")"
MESSAGE="$(cat "$CALLBACK_FILE")"

echo "Sending callback to: $ORCHESTRATOR_AGENT (session: $SESSION_ID)"

if ! openclaw agent \
    --agent "$ORCHESTRATOR_AGENT" \
    --session-id "$SESSION_ID" \
    --message "$MESSAGE" \
    --thinking "$THINKING" \
    --json; then
  cat >&2 <<EOF

ERROR: callback delivery to '$ORCHESTRATOR_AGENT' failed.

The task was completed but the callback could not be delivered. This is a
transport or session problem, not a task failure.

Required action:
  - Check that orchestrator-${PROJECT} is running.
  - Retry this script once the Orchestrator session is reachable.
  - If the problem persists, notify the human operator with the callback file
    contents so they can relay it manually.
  - Do NOT discard or rewrite the callback. The work is done.
EOF
  exit 1
fi

echo "Callback delivered successfully to $ORCHESTRATOR_AGENT."
