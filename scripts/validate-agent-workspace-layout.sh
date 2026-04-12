#!/usr/bin/env bash
set -euo pipefail

# Validate that project-scoped agent workspaces have the correct layout:
#   - no .git at the workspace root (would contaminate workspace files)
#   - repo/ subdirectory is a proper git clone
#
# Usage:
#   scripts/validate-agent-workspace-layout.sh <project-slug> [options]
#
# Options:
#   --workspace-root <path>   Override workspace root (default: from config)
#   --require-repo            Treat missing repo/ as an error, not a warning
#                             (use this after onboarding to assert fully-ready state)
#   --repair                  Remove stray root-level .git dirs that are empty/corrupt
#                             WILL NOT remove a root .git that contains real commits

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/validate-agent-workspace-layout.sh <project-slug> [--workspace-root <path>] [--require-repo] [--repair]
EOF
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

PROJECT=""
WORKSPACE_ROOT_OVERRIDE=""
REQUIRE_REPO=0
REPAIR=0
POSITIONAL=()

while [ $# -gt 0 ]; do
  case "$1" in
    --workspace-root) shift; WORKSPACE_ROOT_OVERRIDE="$1" ;;
    --require-repo)   REQUIRE_REPO=1 ;;
    --repair)         REPAIR=1 ;;
    -h|--help)        usage; exit 0 ;;
    *)                POSITIONAL+=("$1") ;;
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

is_empty_git_repo() {
  # Returns 0 (true) if the .git dir has no commits — safe to remove
  local dir="$1"
  ! git -C "$dir" rev-parse HEAD >/dev/null 2>&1
}

for agent in orchestrator spec security release-manager builder qa; do
  WORKSPACE="$WORKSPACE_ROOT/workspace-${agent}-${PROJECT}"

  if [ ! -d "$WORKSPACE" ]; then
    echo "SKIP  $agent: workspace not yet created ($WORKSPACE)"
    continue
  fi

  # ── root .git check ──────────────────────────────────────────────────────────
  if [ -d "$WORKSPACE/.git" ]; then
    if [ "$REPAIR" -eq 1 ]; then
      if is_empty_git_repo "$WORKSPACE"; then
        echo "REPAIR $agent: removing empty stray .git at workspace root ($WORKSPACE/.git)"
        rm -rf "$WORKSPACE/.git"
        echo "OK    $agent: stray root .git removed"
      else
        echo "ERROR $agent: workspace root has .git with commits — refusing to auto-remove." >&2
        echo "       Inspect $WORKSPACE manually before proceeding." >&2
        ERRORS=$(( ERRORS + 1 ))
        continue
      fi
    else
      echo "ERROR $agent: workspace root is a git repo — project repo must be in $WORKSPACE/repo/" >&2
      echo "       Run with --repair to auto-remove if the root .git is empty/corrupt." >&2
      ERRORS=$(( ERRORS + 1 ))
      continue
    fi
  fi

  # ── repo/ presence check ─────────────────────────────────────────────────────
  if [ ! -d "$WORKSPACE/repo" ]; then
    if [ "$REQUIRE_REPO" -eq 1 ]; then
      echo "ERROR $agent: repo/ subdirectory missing — agents are not in a usable state ($WORKSPACE/repo)" >&2
      ERRORS=$(( ERRORS + 1 ))
    else
      echo "WARN  $agent: repo/ not yet cloned ($WORKSPACE/repo) — expected before first task"
      WARNINGS=$(( WARNINGS + 1 ))
    fi
    continue
  fi

  # ── repo/ must be a valid git repo ───────────────────────────────────────────
  if [ ! -d "$WORKSPACE/repo/.git" ]; then
    echo "ERROR $agent: repo/ exists but is not a git repo — possibly a failed clone ($WORKSPACE/repo)" >&2
    ERRORS=$(( ERRORS + 1 ))
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
  echo "Workspace layout validation passed with $WARNINGS warning(s) (repo/ not yet cloned)"
else
  echo "Workspace layout validation passed"
fi
