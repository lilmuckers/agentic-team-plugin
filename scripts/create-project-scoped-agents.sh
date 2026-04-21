#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT_DIR/scripts/lib/config.sh"
load_framework_config

if [ $# -ne 1 ]; then
  cat >&2 <<'EOF'
Usage:
  scripts/create-project-scoped-agents.sh <project-slug>

Example:
  scripts/create-project-scoped-agents.sh musical-statues
EOF
  exit 1
fi

PROJECT="$1"
for agent in orchestrator spec security release-manager builder qa triage; do
  ID="${agent}-${PROJECT}"
  AGENT_DIR="$FRAMEWORK_OPENCLAW_WORKSPACE_ROOT/agents/${ID}"
  WORKSPACE="$FRAMEWORK_OPENCLAW_WORKSPACE_ROOT/workspace-${ID}"
  echo "Ensuring named agent exists: $ID"
  openclaw agents add "$ID" --agent-dir "$AGENT_DIR" --workspace "$WORKSPACE" --non-interactive --json >/dev/null || true
done

echo "Project-scoped agents ensured for project: $PROJECT"
