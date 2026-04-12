#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/smoke-test-agent-swarm.sh <project-slug> [--agents <comma-list>]

Examples:
  scripts/smoke-test-agent-swarm.sh musical-statues
  scripts/smoke-test-agent-swarm.sh musical-statues --agents orchestrator,spec

Options:
  --agents   Comma-separated subset of agents to test (default: all six)
EOF
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

PROJECT=""
AGENT_SUBSET=""

POSITIONAL=()
while [ $# -gt 0 ]; do
  case "$1" in
    --agents)
      shift
      AGENT_SUBSET="$1"
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

PROJECT="${POSITIONAL[0]}"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SESSION_GEN="$ROOT_DIR/scripts/agent-session-id.py"
MESSAGE_FILE="$ROOT_DIR/templates/swarm-smoke-test.md"

if [ ! -f "$MESSAGE_FILE" ]; then
  echo "ERROR: smoke-test message template not found: $MESSAGE_FILE" >&2
  exit 1
fi

if [ -n "$AGENT_SUBSET" ]; then
  IFS=',' read -ra AGENTS <<< "$AGENT_SUBSET"
else
  AGENTS=(orchestrator spec security release-manager builder qa)
fi

PASS=0
FAIL=0
RESULTS=()

for AGENT in "${AGENTS[@]}"; do
  AGENT_ID="${AGENT}-${PROJECT}"
  SESSION_ID="$(python3 "$SESSION_GEN" --project "$PROJECT" --agent "$AGENT" --task "smoke-test")"

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Agent: $AGENT_ID"
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
echo "Swarm smoke-test summary — project: $PROJECT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
for LINE in "${RESULTS[@]}"; do
  echo "  $LINE"
done
echo ""
echo "  Passed: $PASS  Failed: $FAIL"
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo "One or more agents failed the smoke test. Review output above." >&2
  exit 1
fi

echo "All agents responded. Review each response above to confirm correct role, purpose, and readiness."
