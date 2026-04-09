#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT_DIR/scripts/lib/config.sh"
load_framework_config

if [ $# -lt 3 ] || [ $# -gt 4 ]; then
  cat >&2 <<'EOF'
Usage:
  scripts/set-agent-git-identity.sh <repo-path> <agent-name> <archetype> [archetype-slug]

Examples:
  scripts/set-agent-git-identity.sh . Cohen Orchestrator
  scripts/set-agent-git-identity.sh . Rowan Builder builder
EOF
  exit 1
fi

REPO_PATH="$1"
AGENT_NAME="$2"
ARCHETYPE="$3"
ARCHETYPE_SLUG="${4:-$(printf '%s' "$ARCHETYPE" | tr '[:upper:]' '[:lower:]' | tr ' ' '-') }"
EMAIL="bot-${ARCHETYPE_SLUG}@${FRAMEWORK_OPERATOR_EMAIL_DOMAIN}"
GIT_NAME="${AGENT_NAME} (${ARCHETYPE})"

if [ ! -d "$REPO_PATH/.git" ]; then
  echo "Not a git repository: $REPO_PATH" >&2
  exit 1
fi

git -C "$REPO_PATH" config user.name "$GIT_NAME"
git -C "$REPO_PATH" config user.email "$EMAIL"

echo "Configured git identity for $REPO_PATH"
echo "  user.name  = $GIT_NAME"
echo "  user.email = $EMAIL"
