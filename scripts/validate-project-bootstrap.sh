#!/usr/bin/env bash
set -euo pipefail

REPO_PATH="${1:-.}"

require_file() {
  local path="$1"
  if [ ! -f "$REPO_PATH/$path" ]; then
    echo "ERROR: missing required bootstrap file: $path" >&2
    exit 1
  fi
}

require_file ".github/ISSUE_TEMPLATE/spec-task.md"
require_file ".github/ISSUE_TEMPLATE/architecture-decision.md"
require_file ".github/ISSUE_TEMPLATE/bugfix-task.md"
require_file ".github/ISSUE_TEMPLATE/release-tracking.md"
require_file ".github/pull_request_template.md"
require_file ".github/workflows/merge-gate.yml"
require_file "SPEC.md"
require_file "docs/delivery/release-state.md"
require_file "docs/delivery/task-ledger.md"

echo "Project bootstrap validation passed: $REPO_PATH"
