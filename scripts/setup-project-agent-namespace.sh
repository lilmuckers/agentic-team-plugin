#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  cat >&2 <<'EOF'
Usage:
  scripts/setup-project-agent-namespace.sh <project-slug>

Example:
  scripts/setup-project-agent-namespace.sh musical-statues
EOF
  exit 1
fi

PROJECT="$1"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

"$ROOT_DIR/scripts/create-project-scoped-agents.sh" "$PROJECT"
python3 "$ROOT_DIR/scripts/deploy-project-agent-workspaces.py" --project "$PROJECT"

echo "Project-scoped named-agent namespace is ready for project: $PROJECT"
echo "Next: invoke the project-scoped named agents with fresh sessions to load the updated bootstrap files."
