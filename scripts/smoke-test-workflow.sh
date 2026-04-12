#!/usr/bin/env bash
set -euo pipefail

# End-to-end toolchain smoke test.
#
# Creates a throwaway local git repo, runs the key delivery scripts against it,
# and verifies outputs. Tests the machinery (task ledger, release state, validate
# scripts, git identity, PR artifact validation) not agent identity.
#
# Usage:
#   scripts/smoke-test-workflow.sh [--keep-tmp]
#
# Options:
#   --keep-tmp   Do not delete the temp dir on exit (useful for debugging)

KEEP_TMP=0
for arg in "$@"; do
  case "$arg" in
    --keep-tmp) KEEP_TMP=1 ;;
  esac
done

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT_DIR/scripts/lib/config.sh"
load_framework_config

TMPDIR_BASE="$(mktemp -d)"
REPO="$TMPDIR_BASE/smoke-project"

cleanup() {
  if [ "$KEEP_TMP" -eq 0 ]; then
    rm -rf "$TMPDIR_BASE"
  else
    echo "(--keep-tmp: temp dir preserved at $TMPDIR_BASE)"
  fi
}
trap cleanup EXIT

PASS=0
FAIL=0
RESULTS=()

run_check() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    PASS=$(( PASS + 1 ))
    RESULTS+=("PASS  $label")
  else
    FAIL=$(( FAIL + 1 ))
    RESULTS+=("FAIL  $label")
    echo "FAIL: $label" >&2
    echo "  command: $*" >&2
    # Re-run to capture stderr for display
    "$@" 2>&1 | sed 's/^/  /' >&2 || true
  fi
}

# ── setup: minimal project repo ──────────────────────────────────────────────

git init "$REPO" -q
git -C "$REPO" config user.email "smoke-test@example.com"
git -C "$REPO" config user.name "Smoke Test"

# minimal file so we can commit
echo "# smoke-test project" > "$REPO/README.md"
git -C "$REPO" add README.md
git -C "$REPO" commit -q -m "chore: initial commit"

# bootstrap required dirs and files
mkdir -p \
  "$REPO/.github/ISSUE_TEMPLATE" \
  "$REPO/.github/workflows" \
  "$REPO/docs/delivery"

cp "$ROOT_DIR/repo-templates/.github/ISSUE_TEMPLATE/spec-task.md"        "$REPO/.github/ISSUE_TEMPLATE/spec-task.md"
cp "$ROOT_DIR/repo-templates/.github/ISSUE_TEMPLATE/architecture-decision.md" "$REPO/.github/ISSUE_TEMPLATE/architecture-decision.md"
cp "$ROOT_DIR/repo-templates/.github/ISSUE_TEMPLATE/bugfix-task.md"      "$REPO/.github/ISSUE_TEMPLATE/bugfix-task.md"
cp "$ROOT_DIR/repo-templates/.github/ISSUE_TEMPLATE/release-tracking.md" "$REPO/.github/ISSUE_TEMPLATE/release-tracking.md"
cp "$ROOT_DIR/repo-templates/.github/pull_request_template.md"           "$REPO/.github/pull_request_template.md"
cp "$ROOT_DIR/repo-templates/.github/workflows/merge-gate.yml"           "$REPO/.github/workflows/merge-gate.yml"
cp "$ROOT_DIR/repo-templates/SPEC.md"                                    "$REPO/SPEC.md"
cp "$ROOT_DIR/repo-templates/docs/delivery/release-state.md"             "$REPO/docs/delivery/release-state.md"

# minimal docker-first files
cat > "$REPO/docker-compose.yml" <<'YAML'
version: "3"
services:
  app:
    image: alpine
YAML
cat > "$REPO/.devcontainer/devcontainer.json" <<'JSON' 2>/dev/null || (mkdir -p "$REPO/.devcontainer" && cat > "$REPO/.devcontainer/devcontainer.json" <<'JSON'
{ "name": "smoke-test" }
JSON
)
mkdir -p "$REPO/.devcontainer"
echo '{ "name": "smoke-test" }' > "$REPO/.devcontainer/devcontainer.json"

# minimal README with build/run/verify
cat > "$REPO/README.md" <<'MD'
# smoke-test project

## Build

```bash
docker compose build
```

## Run

```bash
docker compose up
```

## Verify

```bash
docker compose run app echo ok
```
MD

git -C "$REPO" add .
git -C "$REPO" commit -q -m "chore: bootstrap project structure"

# ── checks ────────────────────────────────────────────────────────────────────

echo "Running E2E toolchain smoke tests..."
echo ""

# 1. project bootstrap validation
run_check "validate-project-bootstrap" \
  "$ROOT_DIR/scripts/validate-project-bootstrap.sh" "$REPO"

# 2. docker-first validation
run_check "validate-docker-first-project" \
  "$ROOT_DIR/scripts/validate-docker-first-project.sh" "$REPO"

# 3. README contract validation
run_check "validate-readme-contract" \
  "$ROOT_DIR/scripts/validate-readme-contract.sh" "$REPO/README.md"

# 4. task ledger — write an entry then validate
TASK_JSON='{"task":"smoke-test-task","state":"in_progress","current_action":"running smoke test","next_action":"verify output","history":[]}'
python3 "$ROOT_DIR/scripts/update-task-ledger.py" \
  --ledger "$REPO/docs/delivery/task-ledger.md" \
  --task "smoke-test-task" \
  --state "in_progress" \
  --current-action "running smoke test" \
  --next-action "verify output" \
  >/dev/null 2>&1 || true   # may not exist yet; create it

# create minimal task ledger if the script didn't
if [ ! -f "$REPO/docs/delivery/task-ledger.md" ]; then
  cat > "$REPO/docs/delivery/task-ledger.md" <<'MD'
# Task Ledger

## smoke-test-task

```json
{"task":"smoke-test-task","state":"in_progress","current_action":"running smoke test","next_action":"verify output","history":[]}
```
MD
fi

run_check "validate-task-ledger" \
  python3 "$ROOT_DIR/scripts/validate-task-ledger.py" "$REPO/docs/delivery/task-ledger.md"

# 5. release state validation
run_check "validate-release-state" \
  python3 "$ROOT_DIR/scripts/validate-release-state.py" "$REPO/docs/delivery/release-state.md"

# 6. git identity — set to builder archetype and verify
run_check "set-agent-git-identity (builder)" \
  "$ROOT_DIR/scripts/set-agent-git-identity.sh" "$REPO" \
  "${FRAMEWORK_AGENT_PERSONA_BUILDER:-Builder}" Builder

ACTUAL_NAME="$(git -C "$REPO" config user.name)"
ACTUAL_EMAIL="$(git -C "$REPO" config user.email)"
if echo "$ACTUAL_EMAIL" | grep -q "bot-builder@"; then
  RESULTS+=("PASS  git identity email contains bot-builder@")
  PASS=$(( PASS + 1 ))
else
  RESULTS+=("FAIL  git identity email — got: $ACTUAL_EMAIL")
  FAIL=$(( FAIL + 1 ))
fi

# 7. agent artifact validation — semantic commit subject
run_check "validate-agent-artifacts (semantic commit)" \
  python3 "$ROOT_DIR/scripts/validate-agent-artifacts.py" \
  --commit-subject "feat(smoke): add smoke test coverage"

# 8. agent artifact validation — bad commit subject is rejected
if python3 "$ROOT_DIR/scripts/validate-agent-artifacts.py" \
    --commit-subject "not a semantic commit" >/dev/null 2>&1; then
  RESULTS+=("FAIL  validate-agent-artifacts should reject non-semantic commit subject")
  FAIL=$(( FAIL + 1 ))
else
  RESULTS+=("PASS  validate-agent-artifacts rejects non-semantic commit subject")
  PASS=$(( PASS + 1 ))
fi

# 9. callback validation — write a minimal callback file and validate it
CALLBACK_FILE="$TMPDIR_BASE/callback.md"
cat > "$CALLBACK_FILE" <<'MD'
## Task

- Task ID: smoke-test-task
- Title: Smoke test scaffold

## Agent

- Agent: builder-smoke
- Session: smoke-smoke-builder-smoke-test

## Outcome

DONE

## Routing

- To: orchestrator-smoke
- Via: ACP

## Changed

- Created smoke test scaffold

## Artifacts

- None

## Tests

- validate-project-bootstrap passed
- validate-task-ledger passed

## Blockers

- None

## Next Action

- Orchestrator to assign for QA review
MD

run_check "validate-callback" \
  python3 "$ROOT_DIR/scripts/validate-callback.py" "$CALLBACK_FILE"

# 10. workspace layout: no workspaces yet → validator exits 0 (warnings only, no errors)
WL_EMPTY_ROOT="$TMPDIR_BASE/wl-empty"
mkdir -p "$WL_EMPTY_ROOT"
run_check "validate-agent-workspace-layout (no workspaces yet = warnings only)" \
  "$ROOT_DIR/scripts/validate-agent-workspace-layout.sh" "smoke" \
  --workspace-root "$WL_EMPTY_ROOT"

# 11. workspace layout: .git at workspace root → validator must exit non-zero
WL_CONTAMINATED_ROOT="$TMPDIR_BASE/wl-contaminated"
mkdir -p "$WL_CONTAMINATED_ROOT"
# create a workspace dir for builder-smoke and init git at its root (the bad pattern)
CONTAMINATED_WS="$WL_CONTAMINATED_ROOT/workspace-builder-smoke"
mkdir -p "$CONTAMINATED_WS"
git init "$CONTAMINATED_WS" -q
if "$ROOT_DIR/scripts/validate-agent-workspace-layout.sh" "smoke" \
    --workspace-root "$WL_CONTAMINATED_ROOT" >/dev/null 2>&1; then
  RESULTS+=("FAIL  validate-agent-workspace-layout should reject .git at workspace root")
  FAIL=$(( FAIL + 1 ))
else
  RESULTS+=("PASS  validate-agent-workspace-layout rejects .git at workspace root")
  PASS=$(( PASS + 1 ))
fi

# 12. workspace layout: repo/ subdirectory is a git repo → validator exits 0
WL_CORRECT_ROOT="$TMPDIR_BASE/wl-correct"
mkdir -p "$WL_CORRECT_ROOT"
CORRECT_WS="$WL_CORRECT_ROOT/workspace-builder-smoke"
mkdir -p "$CORRECT_WS/repo"
git init "$CORRECT_WS/repo" -q
run_check "validate-agent-workspace-layout (correct: repo/ is the checkout)" \
  "$ROOT_DIR/scripts/validate-agent-workspace-layout.sh" "smoke" \
  --workspace-root "$WL_CORRECT_ROOT"

# 13. clone-agent-project-repo: missing required args → exits non-zero
if "$ROOT_DIR/scripts/clone-agent-project-repo.sh" >/dev/null 2>&1; then
  RESULTS+=("FAIL  clone-agent-project-repo should require --project/--agent/--remote")
  FAIL=$(( FAIL + 1 ))
else
  RESULTS+=("PASS  clone-agent-project-repo rejects missing required args")
  PASS=$(( PASS + 1 ))
fi

# 14. clone-agent-project-repo: workspace root is a git repo → exits non-zero
CL_ROOT="$TMPDIR_BASE/clone-guard-test"
mkdir -p "$CL_ROOT"
CONTAMINATED_CL="$CL_ROOT/workspace-builder-smoke"
mkdir -p "$CONTAMINATED_CL"
git init "$CONTAMINATED_CL" -q
if FRAMEWORK_OPENCLAW_WORKSPACE_ROOT="$CL_ROOT" \
    "$ROOT_DIR/scripts/clone-agent-project-repo.sh" \
    --project smoke --agent builder --remote "https://example.com/repo.git" \
    --workspace-root "$CL_ROOT" >/dev/null 2>&1; then
  RESULTS+=("FAIL  clone-agent-project-repo should refuse when workspace root is a git repo")
  FAIL=$(( FAIL + 1 ))
else
  RESULTS+=("PASS  clone-agent-project-repo refuses when workspace root is a git repo")
  PASS=$(( PASS + 1 ))
fi

# 15. clone-agent-project-repo: idempotent — existing valid checkout exits 0
CL_EXISTING_ROOT="$TMPDIR_BASE/clone-idempotent-test"
mkdir -p "$CL_EXISTING_ROOT/workspace-builder-smoke/repo"
git init "$CL_EXISTING_ROOT/workspace-builder-smoke/repo" -q
git -C "$CL_EXISTING_ROOT/workspace-builder-smoke/repo" \
  remote add origin "https://example.com/repo.git" 2>/dev/null || true
run_check "clone-agent-project-repo idempotent (existing checkout exits 0)" \
  "$ROOT_DIR/scripts/clone-agent-project-repo.sh" \
  --project smoke --agent builder --remote "https://example.com/repo.git" \
  --workspace-root "$CL_EXISTING_ROOT"

# ── summary ───────────────────────────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "E2E toolchain smoke-test summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
for LINE in "${RESULTS[@]}"; do
  echo "  $LINE"
done
echo ""
echo "  Passed: $PASS  Failed: $FAIL"
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo "Toolchain smoke test FAILED. Review output above." >&2
  exit 1
fi

echo "Toolchain smoke test passed."
