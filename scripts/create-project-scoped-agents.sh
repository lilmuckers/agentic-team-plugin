#!/usr/bin/env bash
set -euo pipefail

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
for agent in orchestrator spec builder qa; do
  ID="${agent}-${PROJECT}"
  AGENT_DIR="/data/.openclaw/agents/${ID}"
  WORKSPACE="/data/.openclaw/workspace-${ID}"
  echo "Ensuring named agent exists: $ID"
  openclaw agents add "$ID" --agent-dir "$AGENT_DIR" --workspace "$WORKSPACE" --non-interactive --json >/dev/null || true
done

echo "Project-scoped agents ensured for project: $PROJECT"
