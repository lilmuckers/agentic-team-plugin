#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/onboard-project.sh <project-slug> [repo-path] [--with-github-setup] [--dry-run]
EOF
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

PROJECT=""
REPO_PATH="."
WITH_GITHUB_SETUP=0
DRY_RUN=0
POSITIONAL=()

for arg in "$@"; do
  case "$arg" in
    --with-github-setup) WITH_GITHUB_SETUP=1 ;;
    --dry-run) DRY_RUN=1 ;;
    *) POSITIONAL+=("$arg") ;;
  esac
done

if [ "${#POSITIONAL[@]}" -lt 1 ] || [ "${#POSITIONAL[@]}" -gt 2 ]; then
  usage
  exit 1
fi

PROJECT="${POSITIONAL[0]}"
if [ "${#POSITIONAL[@]}" -eq 2 ]; then
  REPO_PATH="${POSITIONAL[1]}"
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_NAME="$(basename "$REPO_PATH")"

"$ROOT_DIR/scripts/validate-config.sh" >/dev/null
. "$ROOT_DIR/scripts/lib/config.sh"
load_framework_config

run() {
  echo "+ $*"
  if [ "$DRY_RUN" -ne 1 ]; then
    "$@"
  fi
}

if [ ! -d "$REPO_PATH" ]; then
  echo "ERROR: repo path does not exist: $REPO_PATH" >&2
  exit 1
fi

for agent in orchestrator spec security release-manager builder qa; do
  AGENT_ID="${agent}-${PROJECT}"
  AGENT_DIR="$FRAMEWORK_OPENCLAW_WORKSPACE_ROOT/agents/${AGENT_ID}"
  WORKSPACE_DIR="$FRAMEWORK_OPENCLAW_WORKSPACE_ROOT/workspace-${AGENT_ID}"

  if [ -d "$AGENT_DIR" ]; then
    echo "Agent directory already exists: $AGENT_DIR"
  else
    run "$ROOT_DIR/scripts/create-project-scoped-agents.sh" "$PROJECT"
    break
  fi

  if [ -d "$WORKSPACE_DIR" ]; then
    echo "Workspace already exists: $WORKSPACE_DIR"
  fi
done

run python3 "$ROOT_DIR/scripts/deploy-project-agent-workspaces.py" --project "$PROJECT"

if [ -f "$REPO_PATH/.github/pull_request_template.md" ] \
  && [ -f "$REPO_PATH/.github/workflows/merge-gate.yml" ] \
  && [ -f "$REPO_PATH/SPEC.md" ] \
  && [ -f "$REPO_PATH/.github/ISSUE_TEMPLATE/release-tracking.md" ] \
  && [ -f "$REPO_PATH/docs/delivery/release-state.md" ]; then
  echo "Repo templates already appear installed in $REPO_PATH"
else
  mkdir -p "$REPO_PATH/.github/ISSUE_TEMPLATE" "$REPO_PATH/.github/workflows" "$REPO_PATH/docs/delivery"
  run cp "$ROOT_DIR/repo-templates/.github/ISSUE_TEMPLATE/spec-task.md" "$REPO_PATH/.github/ISSUE_TEMPLATE/spec-task.md"
  run cp "$ROOT_DIR/repo-templates/.github/ISSUE_TEMPLATE/architecture-decision.md" "$REPO_PATH/.github/ISSUE_TEMPLATE/architecture-decision.md"
  run cp "$ROOT_DIR/repo-templates/.github/ISSUE_TEMPLATE/bugfix-task.md" "$REPO_PATH/.github/ISSUE_TEMPLATE/bugfix-task.md"
  run cp "$ROOT_DIR/repo-templates/.github/ISSUE_TEMPLATE/release-tracking.md" "$REPO_PATH/.github/ISSUE_TEMPLATE/release-tracking.md"
  run cp "$ROOT_DIR/repo-templates/.github/pull_request_template.md" "$REPO_PATH/.github/pull_request_template.md"
  run cp "$ROOT_DIR/repo-templates/.github/workflows/merge-gate.yml" "$REPO_PATH/.github/workflows/merge-gate.yml"
  run cp "$ROOT_DIR/repo-templates/SPEC.md" "$REPO_PATH/SPEC.md"
  run cp "$ROOT_DIR/repo-templates/docs/delivery/release-state.md" "$REPO_PATH/docs/delivery/release-state.md"
  echo "Installed minimum repo templates into $REPO_PATH"
fi

run "$ROOT_DIR/scripts/validate-project-bootstrap.sh" "$REPO_PATH"

if [ "$WITH_GITHUB_SETUP" -eq 1 ]; then
  if [ -z "${GITHUB_REPO:-}" ]; then
    echo "ERROR: set GITHUB_REPO=owner/repo to use --with-github-setup" >&2
    exit 1
  fi
  run "$ROOT_DIR/scripts/bootstrap-project-repo.sh" "$GITHUB_REPO" "$REPO_PATH"
else
  echo "Skipping GitHub label/wiki bootstrap. Re-run with --with-github-setup and GITHUB_REPO=owner/repo for full setup."
fi

run "$ROOT_DIR/scripts/set-agent-git-identity.sh" "$REPO_PATH" "$FRAMEWORK_AGENT_PERSONA_ORCHESTRATOR" Orchestrator

echo "Project onboarding complete for $PROJECT"
echo "Default repo-local git identity set to $FRAMEWORK_AGENT_PERSONA_ORCHESTRATOR (Orchestrator); switch archetypes per task as needed."
