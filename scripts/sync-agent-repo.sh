#!/usr/bin/env bash
set -euo pipefail

# Sync the agent's local repo/ checkout to the current remote state.
#
# Every named agent must run this before reading project truth or beginning
# any substantive work. Local checkouts drift between sessions. Agents that
# act on stale local state produce false blockers, miss upstream changes,
# and make unreliable decisions.
#
# What this script does:
#   1. Verifies repo/ exists and is a git repo.
#   2. Checks the working tree is clean (no uncommitted or untracked changes).
#   3. Fetches from the configured remote.
#   4. Confirms the current branch is the expected branch.
#   5. Confirms the local branch can be fast-forwarded to the remote tip
#      (exits non-zero if it cannot — no forced resets).
#   6. Fast-forwards the local branch.
#   7. Reports pre-sync and post-sync commit SHAs.
#
# Exit behaviour:
#   0  — repo is now at the current remote tip; safe to proceed
#   1  — sync could not be completed safely; agent must report BLOCKED
#
# When the agent reports BLOCKED:
#   Include the output of this script in the callback. Do not proceed with
#   stale local state. Do not proceed on a dirty tree. Do not force-reset
#   to resolve this without operator approval.
#
# Usage:
#   scripts/sync-agent-repo.sh [--repo <path>] [--branch <branch>] [--remote <name>]
#
# Defaults:
#   --repo    ./repo      (relative to cwd, i.e. the agent workspace root)
#   --branch  main
#   --remote  origin
#
# Examples:
#   scripts/sync-agent-repo.sh
#   scripts/sync-agent-repo.sh --repo /data/.openclaw/workspace-builder-lapwing/repo
#   scripts/sync-agent-repo.sh --branch develop --remote upstream

REPO_PATH="./repo"
BRANCH="main"
REMOTE_NAME="origin"

while [ $# -gt 0 ]; do
  case "$1" in
    --repo)   shift; REPO_PATH="$1" ;;
    --branch) shift; BRANCH="$1" ;;
    --remote) shift; REMOTE_NAME="$1" ;;
    -h|--help)
      sed -n '/^# Usage/,/^$/p' "$0" | sed 's/^# \{0,2\}//'
      exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
  shift
done

# Resolve to absolute path.
REPO_PATH="$(cd "$REPO_PATH" 2>/dev/null && pwd)" || {
  echo "BLOCKED: repo/ does not exist at the expected path." >&2
  echo "  Expected: $REPO_PATH" >&2
  echo "  Run scripts/clone-agent-project-repo.sh first." >&2
  exit 1
}

if [ ! -d "$REPO_PATH/.git" ]; then
  echo "BLOCKED: $REPO_PATH exists but is not a git repository." >&2
  echo "  This suggests a corrupted checkout. Remove it and re-clone." >&2
  exit 1
fi

# ── 1. pre-sync SHA ───────────────────────────────────────────────────────────

PRE_SHA="$(git -C "$REPO_PATH" rev-parse HEAD)"
echo "pre-sync  HEAD: $PRE_SHA"

# ── 2. working tree must be clean ─────────────────────────────────────────────

if ! git -C "$REPO_PATH" diff --quiet 2>/dev/null || \
   ! git -C "$REPO_PATH" diff --cached --quiet 2>/dev/null; then
  echo "BLOCKED: repo/ has uncommitted changes." >&2
  git -C "$REPO_PATH" status --short >&2
  echo "  Commit, stash, or discard local changes before syncing." >&2
  exit 1
fi

UNTRACKED="$(git -C "$REPO_PATH" ls-files --others --exclude-standard 2>/dev/null | head -5)"
if [ -n "$UNTRACKED" ]; then
  echo "WARNING: repo/ has untracked files (proceeding):"
  echo "$UNTRACKED" | sed 's/^/  /'
fi

# ── 3. confirm on expected branch ─────────────────────────────────────────────

CURRENT_BRANCH="$(git -C "$REPO_PATH" rev-parse --abbrev-ref HEAD)"
if [ "$CURRENT_BRANCH" != "$BRANCH" ]; then
  echo "BLOCKED: local checkout is on '$CURRENT_BRANCH', expected '$BRANCH'." >&2
  echo "  Check out the correct branch before proceeding." >&2
  exit 1
fi

# ── 4. fetch ──────────────────────────────────────────────────────────────────

echo "Fetching from $REMOTE_NAME ..."
if ! git -C "$REPO_PATH" fetch "$REMOTE_NAME" "$BRANCH" 2>&1; then
  echo "BLOCKED: fetch from '$REMOTE_NAME' failed." >&2
  echo "  Check network access and remote configuration." >&2
  exit 1
fi

# ── 5. check fast-forward eligibility ─────────────────────────────────────────

REMOTE_REF="$REMOTE_NAME/$BRANCH"
REMOTE_SHA="$(git -C "$REPO_PATH" rev-parse "$REMOTE_REF" 2>/dev/null)" || {
  echo "BLOCKED: could not resolve remote ref '$REMOTE_REF' after fetch." >&2
  exit 1
}

if [ "$PRE_SHA" = "$REMOTE_SHA" ]; then
  echo "Already up to date: $PRE_SHA"
  echo "post-sync HEAD: $PRE_SHA"
  echo "SYNC_STATUS=up_to_date"
  exit 0
fi

# Is local strictly behind remote? (fast-forward possible)
MERGE_BASE="$(git -C "$REPO_PATH" merge-base HEAD "$REMOTE_REF" 2>/dev/null || true)"
if [ "$MERGE_BASE" != "$PRE_SHA" ]; then
  echo "BLOCKED: local branch has diverged from $REMOTE_REF." >&2
  echo "  Local:  $PRE_SHA" >&2
  echo "  Remote: $REMOTE_SHA" >&2
  echo "  Merge base: $MERGE_BASE" >&2
  echo "  This cannot be resolved with a fast-forward. Operator intervention required." >&2
  exit 1
fi

# ── 6. fast-forward ───────────────────────────────────────────────────────────

echo "Fast-forwarding $BRANCH to $REMOTE_SHA ..."
git -C "$REPO_PATH" merge --ff-only "$REMOTE_REF"

POST_SHA="$(git -C "$REPO_PATH" rev-parse HEAD)"
echo "post-sync HEAD: $POST_SHA"
echo "SYNC_STATUS=updated"
echo "Sync complete. Safe to proceed."
