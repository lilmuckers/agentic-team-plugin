#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  cat >&2 <<'EOF'
Usage:
  scripts/list-agent-sessions.sh <agent|all> [active-minutes]

Examples:
  scripts/list-agent-sessions.sh orchestrator
  scripts/list-agent-sessions.sh builder 120
  scripts/list-agent-sessions.sh all
EOF
  exit 1
fi

AGENT="$1"
ACTIVE_MINUTES="${2:-}"
ARGS=()

if [ "$AGENT" = "all" ]; then
  ARGS+=(--all-agents)
else
  ARGS+=(--agent "$AGENT")
fi

if [ -n "$ACTIVE_MINUTES" ]; then
  ARGS+=(--active "$ACTIVE_MINUTES")
fi

openclaw sessions "${ARGS[@]}" --json
