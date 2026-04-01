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
NAMED_AGENT_DEPLOY="$ROOT_DIR/scripts/deploy-named-agents.py"
WORKSPACE_BOOTSTRAP_DEPLOY="$ROOT_DIR/scripts/deploy-agent-workspace-bootstrap.py"

mkdir -p "$ACTIVE_DIR" "$STATE_DIR"

if ! command -v git >/dev/null 2>&1; then
  echo "git is required" >&2
  exit 1
fi

SYNC_TREE="$ROOT_DIR/scripts/sync-tree.py"
if ! command -v rsync >/dev/null 2>&1; then
  if [ ! -x "$SYNC_TREE" ]; then
    echo "Neither rsync nor sync fallback is available" >&2
    exit 1
  fi
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

if [ ! -x "$NAMED_AGENT_DEPLOY" ]; then
  echo "Named-agent deploy helper is missing or not executable: $NAMED_AGENT_DEPLOY" >&2
  exit 1
fi

if [ ! -x "$WORKSPACE_BOOTSTRAP_DEPLOY" ]; then
  echo "Workspace-bootstrap deploy helper is missing or not executable: $WORKSPACE_BOOTSTRAP_DEPLOY" >&2
  exit 1
fi

"$VALIDATOR" "$ROOT_DIR"

EXCLUDES=(
  '.git/'
  '.active/'
  '.state/'
  '.runtime/'
  '.openclaw/'
  'SOUL.md'
  'IDENTITY.md'
  'USER.md'
  'MEMORY.md'
  'memory/'
  'TOOLS.md'
  'HEARTBEAT.md'
  'AGENTS.md'
  'BOOT.md'
  'BOOTSTRAP.md'
  'repo-templates/'
)

if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete \
    $(printf -- " --exclude %q" "${EXCLUDES[@]}") \
    "$ROOT_DIR/" "$ACTIVE_DIR/"
else
  PY_ARGS=()
  for pattern in "${EXCLUDES[@]}"; do
    PY_ARGS+=(--exclude "$pattern")
  done
  "$SYNC_TREE" "$ROOT_DIR" "$ACTIVE_DIR" "${PY_ARGS[@]}"
fi

"$VALIDATOR" "$ACTIVE_DIR"
(
  cd "$ACTIVE_DIR"
  "$BUNDLE_GEN"
)
"$NAMED_AGENT_DEPLOY"
"$WORKSPACE_BOOTSTRAP_DEPLOY"

printf '%s %s\n' "$SHA" "$TS" > "$STAMP_FILE"
cat > "$META_FILE" <<EOF
sha=$SHA
branch=$BRANCH
timestamp=$TS
active_dir=$ACTIVE_DIR
runtime_dir=$ACTIVE_DIR/.runtime
named_agents_root=/data/.openclaw/agents
managed_workspaces=/data/.openclaw/workspace-orchestrator,/data/.openclaw/workspace-spec,/data/.openclaw/workspace-builder,/data/.openclaw/workspace-qa
reload_boundary=fresh-session
EOF

echo "Promoted framework commit $SHA from $BRANCH at $TS to $ACTIVE_DIR"
echo "Runtime bundles generated in $ACTIVE_DIR/.runtime"
echo "Named agents deployed under /data/.openclaw/agents"
echo "Managed workspace bootstrap files deployed for named agents"
