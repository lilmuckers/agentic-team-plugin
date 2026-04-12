#!/usr/bin/env bash
set -euo pipefail

# Clone the project repo into the canonical repo/ subdirectory for an agent.
#
# Agents call this at the start of any session that needs a local checkout.
# It is safe to call multiple times — if repo/ already exists and is a valid
# git repo pointing at the right remote, it reports the path and exits 0.
#
# OpenClaw initialises a git repo at the workspace root for its own session
# tracking. This is tolerated. The workspace root .git is only treated as an
# error if its remote matches the project remote (meaning the project was
# cloned at root instead of into repo/).
#
# Refuses to proceed if:
#   - workspace root .git remote matches the project remote (leaked project checkout)
#   - repo/ exists but is not a git repo (corrupted state)
#   - repo/ exists, is a git repo, but has a different remote (mismatch)
#
# Usage:
#   scripts/clone-agent-project-repo.sh \
#     --project <slug> \
#     --agent <archetype> \
#     --remote <git-remote-url> \
#     [--branch <branch>] \
#     [--workspace-root <path>]
#
# Outputs on success:
#   CHECKOUT_PATH=<absolute path to repo/>
#
# Example:
#   scripts/clone-agent-project-repo.sh \
#     --project musical-statues \
#     --agent builder \
#     --remote git@github.com:your-org/musical-statues.git

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/clone-agent-project-repo.sh \
    --project <slug> --agent <archetype> --remote <url> \
    [--branch <branch>] [--workspace-root <path>]
EOF
}

PROJECT=""
AGENT=""
REMOTE=""
BRANCH="main"
WORKSPACE_ROOT_OVERRIDE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --project)       shift; PROJECT="$1" ;;
    --agent)         shift; AGENT="$1" ;;
    --remote)        shift; REMOTE="$1" ;;
    --branch)        shift; BRANCH="$1" ;;
    --workspace-root) shift; WORKSPACE_ROOT_OVERRIDE="$1" ;;
    -h|--help)       usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
  shift
done

if [ -z "$PROJECT" ] || [ -z "$AGENT" ] || [ -z "$REMOTE" ]; then
  echo "ERROR: --project, --agent, and --remote are required" >&2
  usage
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT_DIR/scripts/lib/config.sh"
load_framework_config

WORKSPACE_ROOT="${WORKSPACE_ROOT_OVERRIDE:-$FRAMEWORK_OPENCLAW_WORKSPACE_ROOT}"
WORKSPACE="$WORKSPACE_ROOT/workspace-${AGENT}-${PROJECT}"
CHECKOUT="$WORKSPACE/repo"

# ── guard: workspace root .git must not be the project repo ──────────────────
# A root .git is normal OpenClaw session tracking — tolerated unless its remote
# matches the project remote, which would mean the project was cloned at root.

if [ -d "$WORKSPACE/.git" ]; then
  ROOT_REMOTE="$(git -C "$WORKSPACE" remote get-url origin 2>/dev/null || true)"
  if [ -n "$ROOT_REMOTE" ] && [ "$ROOT_REMOTE" = "$REMOTE" ]; then
    echo "ERROR: workspace root .git remote matches the project remote." >&2
    echo "       The project repo appears to have been cloned at the workspace root." >&2
    echo "       Expected checkout location: $CHECKOUT" >&2
    echo "       Found at root: $WORKSPACE (remote: $ROOT_REMOTE)" >&2
    exit 1
  fi
fi

# ── idempotent: repo/ already exists ──────────────────────────────────────────

if [ -d "$CHECKOUT" ]; then
  if [ ! -d "$CHECKOUT/.git" ]; then
    echo "ERROR: $CHECKOUT exists but is not a git repo (corrupted state)." >&2
    echo "       Remove it and re-run to clone fresh." >&2
    exit 1
  fi

  EXISTING_REMOTE="$(git -C "$CHECKOUT" remote get-url origin 2>/dev/null || true)"
  if [ -n "$EXISTING_REMOTE" ] && [ "$EXISTING_REMOTE" != "$REMOTE" ]; then
    echo "ERROR: $CHECKOUT already exists with a different remote." >&2
    echo "       Expected: $REMOTE" >&2
    echo "       Found:    $EXISTING_REMOTE" >&2
    echo "       If you intended a different repo, remove $CHECKOUT and re-run." >&2
    exit 1
  fi

  echo "Checkout already present: $CHECKOUT"
  echo "CHECKOUT_PATH=$CHECKOUT"
  exit 0
fi

# ── clone ─────────────────────────────────────────────────────────────────────

mkdir -p "$WORKSPACE"

echo "Cloning $REMOTE into $CHECKOUT ..."
git clone --branch "$BRANCH" "$REMOTE" "$CHECKOUT"

# verify the result is sane
if [ ! -d "$CHECKOUT/.git" ]; then
  echo "ERROR: clone completed but $CHECKOUT/.git is missing." >&2
  exit 1
fi

# set repo-local git identity for this archetype
PERSONA_VAR="FRAMEWORK_AGENT_PERSONA_$(echo "$AGENT" | tr '[:lower:]-' '[:upper:]_')"
PERSONA="${!PERSONA_VAR:-$AGENT}"
"$ROOT_DIR/scripts/set-agent-git-identity.sh" "$CHECKOUT" "$PERSONA" "$AGENT" 2>/dev/null || true

echo "Cloned successfully."
echo "CHECKOUT_PATH=$CHECKOUT"
