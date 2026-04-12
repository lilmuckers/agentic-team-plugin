#!/usr/bin/env bash
set -euo pipefail

# Send a task directly to an existing named project agent session.
#
# This is the ONLY correct dispatch path for project-scoped named agents:
#   spec-<project>, builder-<project>, qa-<project>,
#   security-<project>, release-manager-<project>
#
# IMPORTANT — delivery versus completion:
#   This script confirms task DELIVERY only. It is NOT the callback channel.
#   A successful exit (0) means the task message was accepted by the named
#   agent's session. It does NOT mean the task is complete.
#
#   Task completion is signalled by the named agent sending an explicit
#   callback to orchestrator-<project> using scripts/send-agent-callback.sh.
#   Orchestrator must NOT treat the return value of this script as the
#   authoritative completion report.
#
# Behaviour:
#   - Targets the existing named-agent session by agent name alone.
#   - Does NOT pass a synthetic --session-id unless an explicit task-suffix is
#     provided. OpenClaw routes to the agent's live session by agent name.
#     Generating a synthetic session id (e.g. 'lapwing-spec') and passing it
#     to --session-id can miss the real running session.
#   - Does NOT spawn a new session.
#   - Does NOT fall back to a generic sub-agent if the named agent is
#     unavailable. Instead it exits non-zero with a clear message so the
#     Orchestrator can surface the blockage to the human operator.
#
# Use prepare-archetype-spawn.py / direct-spawn-archetype.sh to spawn a
# fresh disposable worker (always isolated). Those scripts are for
# ephemeral specialists, not for project-scoped named agents.

if [ $# -lt 3 ] || [ $# -gt 5 ]; then
  cat >&2 <<'EOF'
Usage:
  scripts/dispatch-named-agent.sh <project> <archetype> <task-file> [task-suffix] [thinking]

Arguments:
  project      project slug, e.g. merlin
  archetype    agent role: spec | builder | qa | security | release-manager | orchestrator
  task-file    path to the task message file
  task-suffix  optional suffix to disambiguate the session id, e.g. issue-42
  thinking     thinking level: minimal | low | medium | high (default: minimal)

Examples:
  scripts/dispatch-named-agent.sh merlin spec issue-5.md
  scripts/dispatch-named-agent.sh merlin builder issue-5.md issue-5
  scripts/dispatch-named-agent.sh merlin qa pr-review.md pr-42 low
EOF
  exit 1
fi

PROJECT="$1"
ARCHETYPE="$2"
TASK_FILE="$3"
TASK_SUFFIX="${4:-}"
THINKING="${5:-minimal}"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [ ! -f "$TASK_FILE" ]; then
  echo "ERROR: task file not found: $TASK_FILE" >&2
  exit 1
fi

# Agent id is always <archetype>-<project>.
# Route by agent name only — no synthetic session id unless a task-suffix was
# explicitly provided for task isolation. OpenClaw resolves the agent's live
# session internally by agent name.
AGENT_ID="${ARCHETYPE}-${PROJECT}"
MESSAGE="$(cat "$TASK_FILE")"

OPENCLAW_ARGS=(
  --agent "$AGENT_ID"
  --message "$MESSAGE"
  --thinking "$THINKING"
  --json
)

if [ -n "$TASK_SUFFIX" ]; then
  SESSION_GEN="$ROOT_DIR/scripts/agent-session-id.py"
  SESSION_ID="$(python3 "$SESSION_GEN" --project "$PROJECT" --agent "$ARCHETYPE" --task "$TASK_SUFFIX")"
  OPENCLAW_ARGS+=(--session-id "$SESSION_ID")
  echo "Dispatching to named agent: $AGENT_ID (session: $SESSION_ID)"
else
  echo "Dispatching to named agent: $AGENT_ID"
fi

echo "NOTE: This confirms delivery only. Task completion comes via send-agent-callback.sh."

if ! openclaw agent "${OPENCLAW_ARGS[@]}"; then
  cat >&2 <<EOF

ERROR: dispatch to named agent '$AGENT_ID' failed — task was NOT delivered.

This path does NOT fall back to a generic sub-agent.
Possible causes:
  - The named agent session is not running.
  - The OpenClaw runtime on this surface does not support direct named-agent dispatch.
  - The agent id '$AGENT_ID' does not exist in the current namespace.

Required action:
  Surface this as a blocker to the human operator.
  Do not substitute a generic archetype-shaped worker unless the operator
  has explicitly approved that substitution for this task.
EOF
  exit 1
fi

echo "Task delivered to $AGENT_ID. Waiting for callback via send-agent-callback.sh."
