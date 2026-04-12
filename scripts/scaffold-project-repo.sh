#!/usr/bin/env bash
set -euo pipefail

# Seed an empty remote repo with the minimum framework files and push to main.
#
# Called by onboard-project.sh when the remote has no commits yet.
# After this script completes, the remote has a default branch and per-agent
# repo/ clones will succeed.
#
# Usage:
#   scripts/scaffold-project-repo.sh <repo-path> <project-slug> [--branch <branch>] [--dry-run]

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/scaffold-project-repo.sh <repo-path> <project-slug> [--branch <branch>] [--dry-run]
EOF
}

REPO_PATH=""
PROJECT=""
BRANCH="main"
DRY_RUN=0
POSITIONAL=()

while [ $# -gt 0 ]; do
  case "$1" in
    --branch)   shift; BRANCH="$1" ;;
    --dry-run)  DRY_RUN=1 ;;
    -h|--help)  usage; exit 0 ;;
    *)          POSITIONAL+=("$1") ;;
  esac
  shift
done

if [ "${#POSITIONAL[@]}" -ne 2 ]; then
  usage
  exit 1
fi

REPO_PATH="${POSITIONAL[0]}"
PROJECT="${POSITIONAL[1]}"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT_DIR/scripts/lib/config.sh"
load_framework_config

run() {
  echo "+ $*"
  [ "$DRY_RUN" -ne 1 ] && "$@"
}

if [ ! -d "$REPO_PATH" ]; then
  echo "ERROR: repo path does not exist: $REPO_PATH" >&2
  exit 1
fi

# Is the repo truly empty (no commits)?
if git -C "$REPO_PATH" rev-parse HEAD >/dev/null 2>&1; then
  echo "Repo already has commits — scaffold not needed."
  exit 0
fi

echo "Repo has no commits — seeding initial scaffold for project: $PROJECT"

# Install minimum framework files
mkdir -p \
  "$REPO_PATH/.github/ISSUE_TEMPLATE" \
  "$REPO_PATH/.github/workflows" \
  "$REPO_PATH/docs/delivery"

run cp "$ROOT_DIR/repo-templates/.github/ISSUE_TEMPLATE/spec-task.md"            "$REPO_PATH/.github/ISSUE_TEMPLATE/spec-task.md"
run cp "$ROOT_DIR/repo-templates/.github/ISSUE_TEMPLATE/architecture-decision.md" "$REPO_PATH/.github/ISSUE_TEMPLATE/architecture-decision.md"
run cp "$ROOT_DIR/repo-templates/.github/ISSUE_TEMPLATE/bugfix-task.md"          "$REPO_PATH/.github/ISSUE_TEMPLATE/bugfix-task.md"
run cp "$ROOT_DIR/repo-templates/.github/ISSUE_TEMPLATE/release-tracking.md"     "$REPO_PATH/.github/ISSUE_TEMPLATE/release-tracking.md"
run cp "$ROOT_DIR/repo-templates/.github/pull_request_template.md"               "$REPO_PATH/.github/pull_request_template.md"
run cp "$ROOT_DIR/repo-templates/.github/workflows/merge-gate.yml"               "$REPO_PATH/.github/workflows/merge-gate.yml"
run cp "$ROOT_DIR/repo-templates/SPEC.md"                                        "$REPO_PATH/SPEC.md"
run cp "$ROOT_DIR/repo-templates/docs/delivery/release-state.md"                 "$REPO_PATH/docs/delivery/release-state.md"
run cp "$ROOT_DIR/repo-templates/docs/delivery/task-ledger.md"                   "$REPO_PATH/docs/delivery/task-ledger.md"

# Minimal README so the repo looks reasonable
if [ ! -f "$REPO_PATH/README.md" ]; then
  cat > "$REPO_PATH/README.md" <<MD
# ${PROJECT}

Project scaffolded by the agentic delivery team framework.

> **Note:** This README will be updated by the Builder agent once the spec is complete and implementation begins.

## Getting started

See \`SPEC.md\` for the project specification and delivery plan.
MD
  echo "Created placeholder README.md"
fi

# Set git identity for the scaffolding commit
run git -C "$REPO_PATH" config user.name  "${FRAMEWORK_AGENT_PERSONA_ORCHESTRATOR:-Orchestrator} (Orchestrator)"
run git -C "$REPO_PATH" config user.email "bot-orchestrator@${FRAMEWORK_OPERATOR_EMAIL_DOMAIN}"

# Commit and push
run git -C "$REPO_PATH" checkout -b "$BRANCH"
run git -C "$REPO_PATH" add .
run git -C "$REPO_PATH" commit -m "chore: initial project scaffold from agentic-team-plugin"
run git -C "$REPO_PATH" push -u origin "$BRANCH"

echo "Scaffold committed and pushed to $BRANCH."
echo "Remote now has a default branch — per-agent repo/ clones can proceed."
