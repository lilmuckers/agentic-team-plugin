#!/usr/bin/env bash
set -euo pipefail

# Two test modes:
#
#   identity (default, used during onboarding)
#     Sends templates/swarm-smoke-test.md — each agent reports its name,
#     purpose, readiness, prerequisites, and any config gaps.
#     Goal: confirm agents are wired up and can respond.
#
#   behavior (used after onboarding, before first sprint)
#     Sends templates/swarm-behavior-test/<agent>.md — each agent performs
#     a concrete role-specific task: reads project state, makes a routing
#     decision, names scripts it would run, and replies in callback format.
#     Goal: confirm agents understand their role and follow framework rules.
#
# Usage:
#   scripts/smoke-test-agent-swarm.sh <project-slug> [options]
#
# Options:
#   --mode identity|behavior   Test mode (default: identity)
#   --agents <comma-list>      Subset of agents to test (default: all six)

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/smoke-test-agent-swarm.sh <project-slug> [--mode identity|behavior] [--agents <comma-list>]

Examples:
  scripts/smoke-test-agent-swarm.sh musical-statues
  scripts/smoke-test-agent-swarm.sh musical-statues --mode behavior
  scripts/smoke-test-agent-swarm.sh musical-statues --mode behavior --agents orchestrator,builder
EOF
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

PROJECT=""
AGENT_SUBSET=""
MODE="identity"

POSITIONAL=()
while [ $# -gt 0 ]; do
  case "$1" in
    --agents)
      shift
      AGENT_SUBSET="$1"
      ;;
    --mode)
      shift
      MODE="$1"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      POSITIONAL+=("$1")
      ;;
  esac
  shift
done

if [ "${#POSITIONAL[@]}" -ne 1 ]; then
  usage
  exit 1
fi

if [ "$MODE" != "identity" ] && [ "$MODE" != "behavior" ]; then
  echo "ERROR: --mode must be 'identity' or 'behavior'" >&2
  exit 1
fi

PROJECT="${POSITIONAL[0]}"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SESSION_GEN="$ROOT_DIR/scripts/agent-session-id.py"

if [ -n "$AGENT_SUBSET" ]; then
  IFS=',' read -ra AGENTS <<< "$AGENT_SUBSET"
else
  AGENTS=(orchestrator spec security release-manager builder qa triage)
fi

PASS=0
FAIL=0
RESULTS=()

for AGENT in "${AGENTS[@]}"; do
  AGENT_ID="${AGENT}-${PROJECT}"
  TASK_SUFFIX="${MODE}-test"
  SESSION_ID="$(python3 "$SESSION_GEN" --project "$PROJECT" --agent "$AGENT" --task "$TASK_SUFFIX")"

  if [ "$MODE" = "identity" ]; then
    MESSAGE_FILE="$ROOT_DIR/templates/swarm-smoke-test.md"
  else
    MESSAGE_FILE="$ROOT_DIR/templates/swarm-behavior-test/${AGENT}.md"
  fi

  if [ ! -f "$MESSAGE_FILE" ]; then
    echo "ERROR: test message not found: $MESSAGE_FILE" >&2
    FAIL=$(( FAIL + 1 ))
    RESULTS+=("FAIL  $AGENT_ID (missing template: $MESSAGE_FILE)")
    continue
  fi

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Agent:   $AGENT_ID"
  echo "Mode:    $MODE"
  echo "Session: $SESSION_ID"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if openclaw agent \
      --agent "$AGENT_ID" \
      --session-id "$SESSION_ID" \
      --message "$(cat "$MESSAGE_FILE")" \
      --thinking minimal \
      --verbose off \
      --json; then
    PASS=$(( PASS + 1 ))
    RESULTS+=("PASS  $AGENT_ID")
  else
    FAIL=$(( FAIL + 1 ))
    RESULTS+=("FAIL  $AGENT_ID")
    echo "ERROR: agent invocation failed for $AGENT_ID" >&2
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Swarm ${MODE}-test summary — project: $PROJECT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
for LINE in "${RESULTS[@]}"; do
  echo "  $LINE"
done
echo ""
echo "  Passed: $PASS  Failed: $FAIL"
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo "One or more agents failed. Review output above." >&2
  exit 1
fi

if [ "$MODE" = "identity" ]; then
  echo "All agents responded. Review each response to confirm correct role, purpose, and readiness."
else
  echo "All agents completed behavioral tasks. Review each response to confirm correct routing, tool usage, and callback format."
fi
