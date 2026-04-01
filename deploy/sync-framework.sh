#!/usr/bin/env bash
set -euo pipefail

# Promote the reviewed framework working copy into a stable active deployment copy.
#
# Promotion flow:
# 1. verify we are deploying from reviewed main
# 2. validate framework contents in the working copy
# 3. sync managed framework files into the active copy
# 4. validate the active copy
# 5. generate runtime bundles for archetype sessions
# 6. record deployed SHA and metadata

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ACTIVE_DIR="${ACTIVE_DIR:-$ROOT_DIR/.active/framework}"
STATE_DIR="${STATE_DIR:-$ROOT_DIR/.state/framework}"
STAMP_FILE="$STATE_DIR/deployed-sha.txt"
META_FILE="$STATE_DIR/deploy-meta.txt"
VALIDATOR="$ROOT_DIR/scripts/validate-framework.sh"
BUNDLE_GEN="$ROOT_DIR/scripts/generate-runtime-bundles.py"

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

if [ ! -x "$VALIDATOR" ]; then
  echo "Framework validator is missing or not executable: $VALIDATOR" >&2
  exit 1
fi

if [ ! -x "$BUNDLE_GEN" ]; then
  echo "Runtime bundle generator is missing or not executable: $BUNDLE_GEN" >&2
  exit 1
fi

"$VALIDATOR" "$ROOT_DIR"

rsync -a \
  --delete \
  --exclude '.git/' \
  --exclude '.active/' \
  --exclude '.state/' \
  --exclude '.runtime/' \
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
  "$ROOT_DIR/" "$ACTIVE_DIR/"

"$VALIDATOR" "$ACTIVE_DIR"
(
  cd "$ACTIVE_DIR"
  "$BUNDLE_GEN"
)

printf '%s %s\n' "$SHA" "$TS" > "$STAMP_FILE"
cat > "$META_FILE" <<EOF
sha=$SHA
branch=$BRANCH
timestamp=$TS
active_dir=$ACTIVE_DIR
runtime_dir=$ACTIVE_DIR/.runtime
EOF

echo "Promoted framework commit $SHA from $BRANCH at $TS to $ACTIVE_DIR"
echo "Runtime bundles generated in $ACTIVE_DIR/.runtime"
