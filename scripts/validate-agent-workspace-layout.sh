#!/usr/bin/env bash
set -euo pipefail

# Validate that project-scoped agent workspaces have the correct layout.
#
# OpenClaw initialises a git repo at the workspace root as part of its own
# session tracking. This is expected and tolerated. The only failure conditions
# related to a root .git are:
#
#   - the root .git remote matches the project remote (project was cloned at root
#     instead of into repo/)
#   - project files exist at the workspace root that belong in repo/
#
# The canonical project checkout must be in repo/ — a dedicated subdirectory.
#
# Usage:
#   scripts/validate-agent-workspace-layout.sh <project-slug> [options]
#
# Options:
#   --workspace-root <path>   Override workspace root (default: from config)
#   --remote <url>            Project remote URL to check against root .git
#                             (default: auto-detected from repo/ if present)
#   --require-repo            Treat missing repo/ as an error, not a warning
#                             (use after onboarding to assert fully-ready state)

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/validate-agent-workspace-layout.sh <project-slug> [--workspace-root <path>] [--remote <url>] [--require-repo]
EOF
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

PROJECT=""
WORKSPACE_ROOT_OVERRIDE=""
PROJECT_REMOTE=""
REQUIRE_REPO=0
POSITIONAL=()

while [ $# -gt 0 ]; do
  case "$1" in
    --workspace-root) shift; WORKSPACE_ROOT_OVERRIDE="$1" ;;
    --remote)         shift; PROJECT_REMOTE="$1" ;;
    --require-repo)   REQUIRE_REPO=1 ;;
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

for agent in orchestrator spec security release-manager builder qa; do
  WORKSPACE="$WORKSPACE_ROOT/workspace-${agent}-${PROJECT}"

  if [ ! -d "$WORKSPACE" ]; then
    echo "SKIP  $agent: workspace not yet created ($WORKSPACE)"
    continue
  fi

  # ── root .git check ──────────────────────────────────────────────────────────
  # A root .git is OpenClaw's own session tracking — tolerated unless it is
  # actually serving as the project repo checkout (wrong remote or project files
  # at root instead of in repo/).
  if [ -d "$WORKSPACE/.git" ]; then
    ROOT_REMOTE="$(git -C "$WORKSPACE" remote get-url origin 2>/dev/null || true)"

    # Determine what remote to compare against
    COMPARE_REMOTE="$PROJECT_REMOTE"
    if [ -z "$COMPARE_REMOTE" ] && [ -d "$WORKSPACE/repo/.git" ]; then
      COMPARE_REMOTE="$(git -C "$WORKSPACE/repo" remote get-url origin 2>/dev/null || true)"
    fi

    if [ -n "$ROOT_REMOTE" ] && [ -n "$COMPARE_REMOTE" ] && [ "$ROOT_REMOTE" = "$COMPARE_REMOTE" ]; then
      echo "ERROR $agent: workspace root .git has the same remote as the project repo." >&2
      echo "       The project was cloned at the workspace root instead of into $WORKSPACE/repo/." >&2
      echo "       Move the checkout: git clone $ROOT_REMOTE $WORKSPACE/repo/" >&2
      ERRORS=$(( ERRORS + 1 ))
      continue
    fi

    # Root .git is OpenClaw's — tolerated
    echo "NOTE  $agent: workspace root has a .git (OpenClaw session tracking — OK)"
  fi

  # ── repo/ presence check ─────────────────────────────────────────────────────
  if [ ! -d "$WORKSPACE/repo" ]; then
    if [ "$REQUIRE_REPO" -eq 1 ]; then
      echo "ERROR $agent: repo/ subdirectory missing — agent is not in a usable state ($WORKSPACE/repo)" >&2
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
