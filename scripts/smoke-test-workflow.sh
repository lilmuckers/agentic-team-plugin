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
cp "$ROOT_DIR/repo-templates/docs/delivery/task-ledger.md"               "$REPO/docs/delivery/task-ledger.md"

# minimal docker-first files
cat > "$REPO/docker-compose.yml" <<'YAML'
version: "3"
services:
  app:
    image: alpine
YAML
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
  "$ROOT_DIR/scripts/validate-readme-contract.sh" "$REPO"

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

# 9b. callback validation — missing required section is rejected
BAD_CALLBACK_FILE="$TMPDIR_BASE/bad-callback.md"
cat > "$BAD_CALLBACK_FILE" <<'MD'
## Task

- Task ID: smoke-test-task

## Agent

- Agent: qa-smoke

## Outcome

NEEDS_REVIEW

## Routing

- To: orchestrator-smoke
- Via: ACP

## Changed

- Posted QA review comment on PR #7

## Artifacts

- PR #7 comment

## Tests

- Manual review performed

## Blockers

- None

MD
# Missing ## Next Action section — validator must reject this
if python3 "$ROOT_DIR/scripts/validate-callback.py" "$BAD_CALLBACK_FILE" >/dev/null 2>&1; then
  RESULTS+=("FAIL  validate-callback should reject callback missing ## Next Action")
  FAIL=$(( FAIL + 1 ))
else
  RESULTS+=("PASS  validate-callback rejects callback missing required section")
  PASS=$(( PASS + 1 ))
fi

# 9c. callback validation — no Routing To: line is rejected
NO_ROUTING_CALLBACK="$TMPDIR_BASE/no-routing-callback.md"
cat > "$NO_ROUTING_CALLBACK" <<'MD'
## Task

- Task ID: smoke-test-task
- Title: Smoke test

## Agent

- Agent: qa-smoke
- Session: smoke

## Outcome

DONE

## Routing

- Via: ACP

## Changed

- Did stuff

## Artifacts

- None

## Tests

- None

## Blockers

- None

## Next Action

- Orchestrator to proceed
MD
if python3 "$ROOT_DIR/scripts/validate-callback.py" "$NO_ROUTING_CALLBACK" >/dev/null 2>&1; then
  RESULTS+=("FAIL  validate-callback should reject callback with no Routing To: line")
  FAIL=$(( FAIL + 1 ))
else
  RESULTS+=("PASS  validate-callback rejects callback with no Routing To: line")
  PASS=$(( PASS + 1 ))
fi

# 9d. send-agent-callback: missing required args → exits non-zero (validates arg handling)
if "$ROOT_DIR/scripts/send-agent-callback.sh" >/dev/null 2>&1; then
  RESULTS+=("FAIL  send-agent-callback.sh should require <project> and <callback-file>")
  FAIL=$(( FAIL + 1 ))
else
  RESULTS+=("PASS  send-agent-callback.sh rejects missing required args")
  PASS=$(( PASS + 1 ))
fi

# 9e. send-agent-callback: bad callback file → validation fails before openclaw is invoked
# (send-agent-callback.sh calls validate-callback.py first; if that fails it exits 1 without
# touching openclaw — we can test this without openclaw being installed)
if "$ROOT_DIR/scripts/send-agent-callback.sh" smoke "$BAD_CALLBACK_FILE" >/dev/null 2>&1; then
  RESULTS+=("FAIL  send-agent-callback.sh should exit non-zero when callback is invalid")
  FAIL=$(( FAIL + 1 ))
else
  RESULTS+=("PASS  send-agent-callback.sh fails fast on invalid callback (validation before transport)")
  PASS=$(( PASS + 1 ))
fi

# 9f. send-agent-callback: well-formed callback reaches the transport step
# (expected to fail at the openclaw call — but must NOT fail at validation)
# We detect this by checking stderr for 'validation failed' vs anything else.
SEND_STDERR="$TMPDIR_BASE/send-stderr.txt"
"$ROOT_DIR/scripts/send-agent-callback.sh" smoke "$CALLBACK_FILE" 2>"$SEND_STDERR" || true
if grep -q "validation failed" "$SEND_STDERR" 2>/dev/null; then
  RESULTS+=("FAIL  send-agent-callback.sh failed at validation for a well-formed callback (should reach transport step)")
  FAIL=$(( FAIL + 1 ))
else
  RESULTS+=("PASS  send-agent-callback.sh passes validation for well-formed callback (fails at transport as expected in CI)")
  PASS=$(( PASS + 1 ))
fi

# 10. workspace layout: openclaw-style root .git (no matching remote) → exits 0, repo/ missing = warn only
WL_OPENCLAW_ROOT="$TMPDIR_BASE/wl-openclaw"
mkdir -p "$WL_OPENCLAW_ROOT"
OPENCLAW_WS="$WL_OPENCLAW_ROOT/workspace-builder-smoke"
mkdir -p "$OPENCLAW_WS"
git init "$OPENCLAW_WS" -q   # OpenClaw-style root .git, different/no remote
run_check "validate-agent-workspace-layout (openclaw root .git tolerated, repo/ not yet cloned = warn only)" \
  "$ROOT_DIR/scripts/validate-agent-workspace-layout.sh" "smoke" \
  --workspace-root "$WL_OPENCLAW_ROOT" \
  --remote "https://example.com/repo.git"

# 11. workspace layout: root .git remote matches project remote → validator must exit non-zero
WL_CONTAMINATED_ROOT="$TMPDIR_BASE/wl-contaminated"
mkdir -p "$WL_CONTAMINATED_ROOT"
# simulate: project repo was cloned at workspace root (wrong) instead of into repo/
CONTAMINATED_WS="$WL_CONTAMINATED_ROOT/workspace-builder-smoke"
mkdir -p "$CONTAMINATED_WS"
git init "$CONTAMINATED_WS" -q
git -C "$CONTAMINATED_WS" remote add origin "https://example.com/repo.git"
if "$ROOT_DIR/scripts/validate-agent-workspace-layout.sh" "smoke" \
    --workspace-root "$WL_CONTAMINATED_ROOT" \
    --remote "https://example.com/repo.git" >/dev/null 2>&1; then
  RESULTS+=("FAIL  validate-agent-workspace-layout should reject root .git with matching project remote")
  FAIL=$(( FAIL + 1 ))
else
  RESULTS+=("PASS  validate-agent-workspace-layout rejects root .git whose remote matches project remote")
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

# 14. clone-agent-project-repo: root .git remote matches project remote → exits non-zero
CL_ROOT="$TMPDIR_BASE/clone-guard-test"
mkdir -p "$CL_ROOT"
CONTAMINATED_CL="$CL_ROOT/workspace-builder-smoke"
mkdir -p "$CONTAMINATED_CL"
git init "$CONTAMINATED_CL" -q
git -C "$CONTAMINATED_CL" remote add origin "https://example.com/repo.git"
if "$ROOT_DIR/scripts/clone-agent-project-repo.sh" \
    --project smoke --agent builder --remote "https://example.com/repo.git" \
    --workspace-root "$CL_ROOT" >/dev/null 2>&1; then
  RESULTS+=("FAIL  clone-agent-project-repo should refuse when root .git remote matches project remote")
  FAIL=$(( FAIL + 1 ))
else
  RESULTS+=("PASS  clone-agent-project-repo refuses when root .git remote matches project remote")
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
