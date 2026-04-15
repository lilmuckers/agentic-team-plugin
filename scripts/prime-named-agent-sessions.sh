#!/usr/bin/env bash
set -euo pipefail

# Establish persistent main sessions for all named project agents.
#
# When a named agent (e.g. builder-lapwing) has never been contacted, its
# session store is empty. If Orchestrator's internal session tools try to
# reach it by label, they fail with "No session found". This script primes
# each agent by sending a brief initialisation message via the CLI, which
# creates `agent:<id>:main` in each agent's session store.
#
# The correct dispatch path (scripts/dispatch-named-agent.sh → openclaw agent
# --agent <id>) always works regardless of priming. This script is a defensive
# measure to make sessions visible to any internal tooling that may inspect them.
#
# Called automatically by onboard-project.sh and deploy-project-agent-workspaces.py.
#
# Usage:
#   scripts/prime-named-agent-sessions.sh <project>
#
# Options:
#   --dry-run    Print what would be sent without executing

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/prime-named-agent-sessions.sh <project>

Examples:
  scripts/prime-named-agent-sessions.sh lapwing
  scripts/prime-named-agent-sessions.sh lapwing --dry-run
EOF
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

PROJECT=""
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help) usage; exit 0 ;;
    -*)
      echo "ERROR: unknown option: $1" >&2
      usage
      exit 1
      ;;
    *)
      if [ -z "$PROJECT" ]; then
        PROJECT="$1"
      else
        echo "ERROR: unexpected argument: $1" >&2
        usage
        exit 1
      fi
      ;;
  esac
  shift
done

if [ -z "$PROJECT" ]; then
  echo "ERROR: <project> is required" >&2
  usage
  exit 1
fi

PRIMING_MESSAGE="System: session initialisation for ${PROJECT}. Acknowledge with your agent id only."

PASS=0
FAIL=0

for ARCHETYPE in orchestrator spec security release-manager builder qa; do
  AGENT_ID="${ARCHETYPE}-${PROJECT}"

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] would prime: openclaw agent --agent $AGENT_ID --message <priming> --thinking minimal"
    PASS=$(( PASS + 1 ))
    continue
  fi

  echo -n "Priming session for $AGENT_ID ... "
  if openclaw agent \
      --agent "$AGENT_ID" \
      --message "$PRIMING_MESSAGE" \
      --thinking minimal \
      --json >/dev/null 2>&1; then
    echo "ok"
    PASS=$(( PASS + 1 ))
  else
    echo "FAILED"
    echo "WARNING: could not prime session for $AGENT_ID" >&2
    FAIL=$(( FAIL + 1 ))
  fi
done

echo ""
echo "Session priming complete for project: $PROJECT"
echo "  Primed: $PASS  Failed: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  echo "WARNING: $FAIL agent session(s) could not be primed." >&2
  echo "         Dispatch via scripts/dispatch-named-agent.sh still works regardless." >&2
  echo "         Internal session tools may not resolve those agents until sessions are established." >&2
  exit 1
fi
