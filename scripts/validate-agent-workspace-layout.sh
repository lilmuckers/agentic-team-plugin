#!/usr/bin/env bash
set -euo pipefail

# Validate that a project-scoped agent workspace does not have a git repo at its
# root. The project repo must be cloned into the repo/ subdirectory, never at
# the workspace root itself, to prevent agent config files from being inside
# the project git working tree.
#
# Usage:
#   scripts/validate-agent-workspace-layout.sh <project-slug>
#   scripts/validate-agent-workspace-layout.sh <project-slug> --workspace-root <path>

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/validate-agent-workspace-layout.sh <project-slug> [--workspace-root <path>]
EOF
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

PROJECT=""
WORKSPACE_ROOT_OVERRIDE=""
POSITIONAL=()

while [ $# -gt 0 ]; do
  case "$1" in
    --workspace-root)
      shift
      WORKSPACE_ROOT_OVERRIDE="$1"
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
. "$ROOT_DIR/scripts/lib/config.sh"
load_framework_config

WORKSPACE_ROOT="${WORKSPACE_ROOT_OVERRIDE:-$FRAMEWORK_OPENCLAW_WORKSPACE_ROOT}"

ERRORS=0
WARNINGS=0

for agent in orchestrator spec security release-manager builder qa; do
  WORKSPACE="$WORKSPACE_ROOT/workspace-${agent}-${PROJECT}"

  if [ ! -d "$WORKSPACE" ]; then
    echo "SKIP  $agent: workspace not yet created ($WORKSPACE)" >&2
    continue
  fi

  # Hard failure: workspace root must not itself be a git repo
  if [ -d "$WORKSPACE/.git" ]; then
    echo "ERROR $agent: workspace root is a git repo — project repo must be in $WORKSPACE/repo/, not at the workspace root" >&2
    ERRORS=$(( ERRORS + 1 ))
    continue
  fi

  # Soft warning: repo/ subdirectory doesn't exist yet (agent hasn't cloned yet)
  if [ ! -d "$WORKSPACE/repo" ]; then
    echo "WARN  $agent: repo/ subdirectory not yet present ($WORKSPACE/repo)" >&2
    WARNINGS=$(( WARNINGS + 1 ))
    continue
  fi

  # repo/ must be a git repo
  if [ ! -d "$WORKSPACE/repo/.git" ]; then
    echo "WARN  $agent: repo/ exists but is not a git repo ($WORKSPACE/repo)" >&2
    WARNINGS=$(( WARNINGS + 1 ))
    continue
  fi

  echo "OK    $agent: repo checkout at $WORKSPACE/repo"
done

echo ""
if [ "$ERRORS" -gt 0 ]; then
  echo "Workspace layout validation FAILED — $ERRORS error(s), $WARNINGS warning(s)" >&2
  exit 1
fi

if [ "$WARNINGS" -gt 0 ]; then
  echo "Workspace layout validation passed with $WARNINGS warning(s) (repo/ not yet cloned — expected before first task)"
else
  echo "Workspace layout validation passed"
fi
