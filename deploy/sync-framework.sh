#!/usr/bin/env bash
set -euo pipefail

# Sync the reviewed framework working copy into a stable active deployment copy.
#
# Expected model:
# - this git checkout is the editable development working copy
# - reviewed changes land on main via pull requests
# - an active deployment copy remains stable between promotions
# - Rowan/OpenClaw local workspace identity/state files are never deployed from this repo
# - repo-templates/ is versioned here, but is meant for downstream project repositories,
#   not for the active framework runtime copy

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ACTIVE_DIR="${ACTIVE_DIR:-$ROOT_DIR/.active/framework}"
STATE_DIR="${STATE_DIR:-$ROOT_DIR/.state}"
STAMP_FILE="$STATE_DIR/deployed-sha.txt"

mkdir -p "$ACTIVE_DIR" "$STATE_DIR"

if ! command -v git >/dev/null 2>&1; then
  echo "git is required" >&2
  exit 1
fi

if ! command -v rsync >/dev/null 2>&1; then
  echo "rsync is required" >&2
  exit 1
fi

SHA="$(git -C "$ROOT_DIR" rev-parse HEAD)"
BRANCH="$(git -C "$ROOT_DIR" rev-parse --abbrev-ref HEAD)"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [ "$BRANCH" != "main" ]; then
  echo "Refusing to deploy from branch '$BRANCH'. Deploy reviewed commits from main only." >&2
  exit 1
fi

rsync -a \
  --delete \
  --exclude '.git/' \
  --exclude '.active/' \
  --exclude '.state/' \
  --exclude '.openclaw/' \
  --exclude 'SOUL.md' \
  --exclude 'IDENTITY.md' \
  --exclude 'USER.md' \
  --exclude 'MEMORY.md' \
  --exclude 'memory/' \
  --exclude 'TOOLS.md' \
  --exclude 'HEARTBEAT.md' \
  --exclude 'AGENTS.md' \
  --exclude 'BOOT.md' \
  --exclude 'BOOTSTRAP.md' \
  --exclude 'repo-templates/' \
  --exclude 'scripts/' \
  "$ROOT_DIR/" "$ACTIVE_DIR/"

printf '%s %s\n' "$SHA" "$TS" > "$STAMP_FILE"
echo "Promoted framework commit $SHA from $BRANCH at $TS to $ACTIVE_DIR"
