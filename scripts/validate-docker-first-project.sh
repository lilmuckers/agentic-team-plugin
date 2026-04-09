#!/usr/bin/env bash
set -euo pipefail

REPO_PATH="${1:-.}"

require_file() {
  local path="$1"
  if [ ! -f "$REPO_PATH/$path" ]; then
    echo "ERROR: missing required file: $path" >&2
    exit 1
  fi
}

require_file "docker-compose.yml"
require_file ".devcontainer/devcontainer.json"
require_file "README.md"

"$(cd "$(dirname "$0")" && pwd)/validate-readme-contract.sh" "$REPO_PATH"

echo "Docker-first project validation passed: $REPO_PATH"
