#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$(cd "$(dirname "$0")/.." && pwd)}"

required_files=(
  "agents/orchestrator.md"
  "agents/spec.md"
  "agents/builder.md"
  "agents/qa.md"
  "policies/repo-management.md"
  "docs/delivery/repo-management-operating-model.md"
  "deploy/manifest.yaml"
  "scripts/set-agent-git-identity.sh"
  "scripts/create-agent-issue.sh"
  "scripts/create-agent-pr.sh"
  "scripts/update-agent-pr-body.sh"
  "scripts/update-agent-wiki-page.sh"
  "scripts/validate-agent-artifacts.py"
  "scripts/validate-callback.py"
  "scripts/validate-issue-ready.py"
  "templates/callback-report.md"
  "schemas/callback.md"
)

for rel in "${required_files[@]}"; do
  if [ ! -f "$ROOT_DIR/$rel" ]; then
    echo "ERROR: missing required file: $rel" >&2
    exit 1
  fi
done

required_exec=(
  "deploy/sync-framework.sh"
  "scripts/set-agent-git-identity.sh"
  "scripts/create-agent-issue.sh"
  "scripts/create-agent-pr.sh"
  "scripts/update-agent-pr-body.sh"
  "scripts/update-agent-wiki-page.sh"
  "scripts/post-agent-comment.sh"
  "scripts/render-agent-comment.py"
  "scripts/render-agent-pr-body.py"
  "scripts/render-agent-wiki-page.py"
  "scripts/validate-agent-artifacts.py"
  "scripts/lint-agent-markdown.py"
  "scripts/validate-callback.py"
  "scripts/validate-issue-ready.py"
)

for rel in "${required_exec[@]}"; do
  if [ ! -x "$ROOT_DIR/$rel" ]; then
    echo "ERROR: required executable is missing or not executable: $rel" >&2
    exit 1
  fi
done

echo "Framework validation passed for $ROOT_DIR"
