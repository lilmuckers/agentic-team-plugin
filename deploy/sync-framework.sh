#!/usr/bin/env bash
set -euo pipefail

# Minimal bootstrap sync script for the framework repo.
# Expected model:
# - repo working copy is reviewed via GitHub
# - active deployment lives in a separate directory
# - this script stages and promotes managed files only

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ACTIVE_DIR="${ACTIVE_DIR:-$ROOT_DIR/.active/framework}"
STATE_DIR="${STATE_DIR:-$ROOT_DIR/.state}"
STAMP_FILE="$STATE_DIR/deployed-sha.txt"

mkdir -p "$ACTIVE_DIR" "$STATE_DIR"

if ! command -v git >/dev/null 2>&1; then
  echo "git is required" >&2
  exit 1
fi

SHA="$(git -C "$ROOT_DIR" rev-parse HEAD)"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

rsync -a \
  --delete \
  --exclude '.git/' \
  --exclude '.active/' \
  --exclude '.state/' \
  --exclude 'SOUL.md' \
  --exclude 'IDENTITY.md' \
  --exclude 'USER.md' \
  --exclude 'MEMORY.md' \
  --exclude 'memory/' \
  --exclude 'TOOLS.md' \
  --exclude 'HEARTBEAT.md' \
  --exclude 'AGENTS.md' \
  "$ROOT_DIR/" "$ACTIVE_DIR/"

printf '%s %s\n' "$SHA" "$TS" > "$STAMP_FILE"
echo "Promoted framework commit $SHA at $TS to $ACTIVE_DIR"
