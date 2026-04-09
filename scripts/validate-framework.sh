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
  "scripts/post-pr-line-comment.sh"
  "scripts/check-framework-version.sh"
  "scripts/validate-agent-artifacts.py"
  "scripts/validate-callback.py"
  "scripts/validate-issue-ready.py"
  "scripts/validate-task-ledger.py"
  "scripts/validate-decision-record.py"
  "scripts/validate-readme-contract.sh"
  "scripts/prepare-specialist-spawn.py"
  "scripts/validate-specialist-template.py"
  "scripts/validate-workflows.py"
  "templates/callback-report.md"
  "templates/decision-record.md"
  "schemas/callback.md"
  "schemas/decision-record.md"
  "schemas/specialist-template.md"
  "schemas/workflow.json"
  "docs/delivery/task-ledger.md"
  "docs/decisions/.gitkeep"
  "agents/specialists/typescript-engineer.md"
  "agents/specialists/qa-regression.md"
  "agents/specialists/ux-designer.md"
  "agents/specialists/visual-designer.md"
  "agents/specialists/usability-reviewer.md"
  "policies/spec-process.md"
  "workflows/implement-feature.yaml"
  "workflows/fix-bug.yaml"
  "workflows/prepare-release.yaml"
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
  "scripts/post-pr-line-comment.sh"
  "scripts/check-framework-version.sh"
  "scripts/render-agent-comment.py"
  "scripts/render-agent-pr-body.py"
  "scripts/render-agent-wiki-page.py"
  "scripts/validate-agent-artifacts.py"
  "scripts/lint-agent-markdown.py"
  "scripts/validate-callback.py"
  "scripts/validate-issue-ready.py"
  "scripts/validate-task-ledger.py"
  "scripts/validate-decision-record.py"
  "scripts/validate-readme-contract.sh"
  "scripts/prepare-specialist-spawn.py"
  "scripts/validate-specialist-template.py"
  "scripts/validate-workflows.py"
)

for rel in "${required_exec[@]}"; do
  if [ ! -x "$ROOT_DIR/$rel" ]; then
    echo "ERROR: required executable is missing or not executable: $rel" >&2
    exit 1
  fi
done

"$ROOT_DIR/scripts/validate-task-ledger.py" "$ROOT_DIR/docs/delivery/task-ledger.md"
"$ROOT_DIR/scripts/validate-decision-record.py" "$ROOT_DIR/templates/decision-record.md"
"$ROOT_DIR/scripts/validate-specialist-template.py" "$ROOT_DIR/agents/specialists/typescript-engineer.md"
"$ROOT_DIR/scripts/validate-specialist-template.py" "$ROOT_DIR/agents/specialists/qa-regression.md"
"$ROOT_DIR/scripts/validate-specialist-template.py" "$ROOT_DIR/agents/specialists/ux-designer.md"
"$ROOT_DIR/scripts/validate-specialist-template.py" "$ROOT_DIR/agents/specialists/visual-designer.md"
"$ROOT_DIR/scripts/validate-specialist-template.py" "$ROOT_DIR/agents/specialists/usability-reviewer.md"
"$ROOT_DIR/scripts/validate-workflows.py" "$ROOT_DIR/workflows/implement-feature.yaml" "$ROOT_DIR/workflows/fix-bug.yaml" "$ROOT_DIR/workflows/prepare-release.yaml"

echo "Framework validation passed for $ROOT_DIR"
