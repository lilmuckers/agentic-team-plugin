#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/onboard-project.sh <project-slug> [repo-path] [options]

Options:
  --remote <url>        Git remote URL to clone into each agent workspace (default: auto-detected from repo-path)
  --branch <branch>     Branch to clone (default: main)
  --with-github-setup   Bootstrap GitHub labels, branch protections, and wiki
  --dry-run             Print actions without executing them
  --no-smoke-test       Skip the swarm smoke test at the end
  --no-clone            Skip cloning the project repo into agent workspaces (use if remote not yet available)
EOF
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

PROJECT=""
REPO_PATH="."
REMOTE=""
BRANCH="main"
WITH_GITHUB_SETUP=0
DRY_RUN=0
SMOKE_TEST=1
DO_CLONE=1
POSITIONAL=()

while [ $# -gt 0 ]; do
  case "$1" in
    --with-github-setup) WITH_GITHUB_SETUP=1 ;;
    --dry-run)           DRY_RUN=1 ;;
    --no-smoke-test)     SMOKE_TEST=0 ;;
    --no-clone)          DO_CLONE=0 ;;
    --remote)            shift; REMOTE="$1" ;;
    --branch)            shift; BRANCH="$1" ;;
    *)                   POSITIONAL+=("$1") ;;
  esac
  shift
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

# Auto-detect remote from repo if not supplied
if [ -z "$REMOTE" ] && [ "$DO_CLONE" -eq 1 ]; then
  REMOTE="$(git -C "$REPO_PATH" remote get-url origin 2>/dev/null || true)"
  if [ -z "$REMOTE" ]; then
    echo "WARNING: could not detect git remote from $REPO_PATH and --remote was not supplied." >&2
    echo "         Agent workspaces will be created without a repo/ checkout." >&2
    echo "         Re-run with --remote <url> once the remote is available, or agents will start half-ready." >&2
    DO_CLONE=0
  else
    echo "Detected remote: $REMOTE"
  fi
fi

# ── named agents ──────────────────────────────────────────────────────────────

for agent in orchestrator spec security release-manager builder qa; do
  AGENT_ID="${agent}-${PROJECT}"
  AGENT_DIR="$FRAMEWORK_OPENCLAW_WORKSPACE_ROOT/agents/${AGENT_ID}"

  if [ -d "$AGENT_DIR" ]; then
    echo "Agent directory already exists: $AGENT_DIR"
  else
    run "$ROOT_DIR/scripts/create-project-scoped-agents.sh" "$PROJECT"
    break
  fi
done

# ── workspace bootstrap files ─────────────────────────────────────────────────

run python3 "$ROOT_DIR/scripts/deploy-project-agent-workspaces.py" --project "$PROJECT"

# ── seed empty repo before cloning ────────────────────────────────────────────

if [ "$DO_CLONE" -eq 1 ]; then
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] would scaffold empty repo if needed, then clone into each agent workspace"
  else
    "$ROOT_DIR/scripts/scaffold-project-repo.sh" "$REPO_PATH" "$PROJECT" --branch "$BRANCH"
  fi
fi

# ── repo/ checkout in every agent workspace ───────────────────────────────────

if [ "$DO_CLONE" -eq 1 ]; then
  echo ""
  echo "Cloning project repo into each agent workspace..."
  for agent in orchestrator spec security release-manager builder qa; do
    if [ "$DRY_RUN" -eq 1 ]; then
      WORKSPACE="$FRAMEWORK_OPENCLAW_WORKSPACE_ROOT/workspace-${agent}-${PROJECT}"
      echo "[dry-run] would clone $REMOTE into $WORKSPACE/repo/"
    else
      "$ROOT_DIR/scripts/clone-agent-project-repo.sh" \
        --project "$PROJECT" \
        --agent "$agent" \
        --remote "$REMOTE" \
        --branch "$BRANCH"
    fi
  done
  echo ""
else
  echo ""
  echo "Skipping repo clone (--no-clone). Each agent workspace has no repo/ checkout yet."
  echo "Run scripts/clone-agent-project-repo.sh for each agent when the remote is available."
  echo ""
fi

# ── validate workspace layout — hard failure if repo/ missing ─────────────────

if [ "$DO_CLONE" -eq 1 ] && [ "$DRY_RUN" -ne 1 ]; then
  LAYOUT_ARGS=("$PROJECT" --require-repo)
  [ -n "$REMOTE" ] && LAYOUT_ARGS+=(--remote "$REMOTE")
  if ! "$ROOT_DIR/scripts/validate-agent-workspace-layout.sh" "${LAYOUT_ARGS[@]}"; then
    echo "ERROR: workspace layout validation failed — agents are not in a usable state." >&2
    exit 1
  fi
fi

# ── repo templates ────────────────────────────────────────────────────────────

if [ -f "$REPO_PATH/.github/pull_request_template.md" ] \
  && [ -f "$REPO_PATH/.github/workflows/merge-gate.yml" ] \
  && [ -f "$REPO_PATH/SPEC.md" ] \
  && [ -f "$REPO_PATH/.github/ISSUE_TEMPLATE/release-tracking.md" ] \
  && [ -f "$REPO_PATH/.github/ISSUE_TEMPLATE/spec-approval.md" ] \
  && [ -f "$REPO_PATH/docs/delivery/release-state.md" ] \
  && [ -f "$REPO_PATH/docs/delivery/task-ledger.md" ]; then
  echo "Repo templates already appear installed in $REPO_PATH"
else
  mkdir -p "$REPO_PATH/.github/ISSUE_TEMPLATE" "$REPO_PATH/.github/workflows" "$REPO_PATH/docs/delivery"
  run cp "$ROOT_DIR/repo-templates/.github/ISSUE_TEMPLATE/spec-task.md"            "$REPO_PATH/.github/ISSUE_TEMPLATE/spec-task.md"
  run cp "$ROOT_DIR/repo-templates/.github/ISSUE_TEMPLATE/architecture-decision.md" "$REPO_PATH/.github/ISSUE_TEMPLATE/architecture-decision.md"
  run cp "$ROOT_DIR/repo-templates/.github/ISSUE_TEMPLATE/bugfix-task.md"          "$REPO_PATH/.github/ISSUE_TEMPLATE/bugfix-task.md"
  run cp "$ROOT_DIR/repo-templates/.github/ISSUE_TEMPLATE/release-tracking.md"     "$REPO_PATH/.github/ISSUE_TEMPLATE/release-tracking.md"
  run cp "$ROOT_DIR/repo-templates/.github/ISSUE_TEMPLATE/spec-approval.md"        "$REPO_PATH/.github/ISSUE_TEMPLATE/spec-approval.md"
  run cp "$ROOT_DIR/repo-templates/.github/pull_request_template.md"               "$REPO_PATH/.github/pull_request_template.md"
  run cp "$ROOT_DIR/repo-templates/.github/workflows/merge-gate.yml"               "$REPO_PATH/.github/workflows/merge-gate.yml"
  run cp "$ROOT_DIR/repo-templates/SPEC.md"                                        "$REPO_PATH/SPEC.md"
  run cp "$ROOT_DIR/repo-templates/docs/delivery/release-state.md"                 "$REPO_PATH/docs/delivery/release-state.md"
  run cp "$ROOT_DIR/repo-templates/docs/delivery/task-ledger.md"                   "$REPO_PATH/docs/delivery/task-ledger.md"
  echo "Installed minimum repo templates into $REPO_PATH"
fi

run "$ROOT_DIR/scripts/validate-project-bootstrap.sh" "$REPO_PATH"

# ── github setup ──────────────────────────────────────────────────────────────

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

echo ""
echo "Project onboarding complete for $PROJECT"
echo "Default repo-local git identity set to $FRAMEWORK_AGENT_PERSONA_ORCHESTRATOR (Orchestrator); switch archetypes per task as needed."
echo ""

# ── smoke test ────────────────────────────────────────────────────────────────

if [ "$SMOKE_TEST" -eq 1 ]; then
  echo "Running swarm smoke test — each agent will report its purpose and readiness..."
  if [ "$DRY_RUN" -ne 1 ]; then
    "$ROOT_DIR/scripts/smoke-test-agent-swarm.sh" "$PROJECT"
  else
    echo "[dry-run] would invoke: scripts/smoke-test-agent-swarm.sh $PROJECT"
  fi
else
  echo "Skipping swarm smoke test (--no-smoke-test). Run scripts/smoke-test-agent-swarm.sh $PROJECT manually when ready."
fi
