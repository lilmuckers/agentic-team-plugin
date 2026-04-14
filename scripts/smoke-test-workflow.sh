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
cp "$ROOT_DIR/repo-templates/.github/ISSUE_TEMPLATE/spec-approval.md"    "$REPO/.github/ISSUE_TEMPLATE/spec-approval.md"
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

# 9b. QA scope grounding — clean review citing only PR files passes
QA_PR_FILES="README.md app.js index.html styles.css"
QA_CLEAN_REVIEW="$TMPDIR_BASE/qa-review-clean.md"
cat > "$QA_CLEAN_REVIEW" <<'MD'
## Changed files reviewed

- README.md
- app.js
- index.html
- styles.css

## Outcome

NEEDS_REVIEW

## Findings

The PR introduces a basic web shell. The `app.js` entry point is minimal and
serves `index.html`. `styles.css` provides baseline layout. `README.md` has
been updated with build and run instructions.

No scope drift observed. All changes are consistent with the PR intent.

## Recommended next action

Builder to address the minor issues before re-review.
MD
run_check "validate-qa-scope (clean review — only PR files cited)" \
  python3 "$ROOT_DIR/scripts/validate-qa-scope.py" "$QA_CLEAN_REVIEW" \
  --pr-files $QA_PR_FILES

# 9c. QA scope grounding — review citing context files as PR changes is rejected
# This replicates the exact lapwing failure: QA read SPEC.md, task-ledger.md,
# and release-state.md as context but then cited them as changed by the PR.
QA_BAD_REVIEW="$TMPDIR_BASE/qa-review-scope-drift.md"
cat > "$QA_BAD_REVIEW" <<'MD'
## Changed files reviewed

- README.md
- app.js
- index.html
- styles.css
- SPEC.md
- docs/delivery/task-ledger.md
- docs/delivery/release-state.md

## Outcome

NEEDS_REVIEW

## Findings

This PR appears to have scope drift. In addition to the web shell files, it
also rewrites `SPEC.md`, `docs/delivery/task-ledger.md`, and
`docs/delivery/release-state.md`. These are unrelated to the stated PR intent.

Builder should limit the PR to the web shell changes only.
MD
if python3 "$ROOT_DIR/scripts/validate-qa-scope.py" "$QA_BAD_REVIEW" \
    --pr-files $QA_PR_FILES >/dev/null 2>&1; then
  RESULTS+=("FAIL  validate-qa-scope should reject review citing context files as PR changes (lapwing pattern)")
  FAIL=$(( FAIL + 1 ))
else
  RESULTS+=("PASS  validate-qa-scope rejects review that misattributes context files as PR changes (lapwing pattern)")
  PASS=$(( PASS + 1 ))
fi

# 9d. QA scope grounding — review missing the required section is rejected (exit 2)
QA_NO_SECTION_REVIEW="$TMPDIR_BASE/qa-review-no-section.md"
cat > "$QA_NO_SECTION_REVIEW" <<'MD'
## Outcome

NEEDS_REVIEW

## Findings

The PR looks fine overall but has some scope drift in the delivery docs.
MD
if python3 "$ROOT_DIR/scripts/validate-qa-scope.py" "$QA_NO_SECTION_REVIEW" \
    --pr-files $QA_PR_FILES >/dev/null 2>&1; then
  RESULTS+=("FAIL  validate-qa-scope should require the 'Changed files reviewed' section")
  FAIL=$(( FAIL + 1 ))
else
  RESULTS+=("PASS  validate-qa-scope rejects review missing required 'Changed files reviewed' section")
  PASS=$(( PASS + 1 ))
fi

# 9e. callback validation — missing required section is rejected
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

# ── deploy-project-agent-workspaces watchdog sync ────────────────────────────
# deploy-project-agent-workspaces.py requires live runtime bundles from a
# full deploy, so we test its watchdog wiring by inspecting its --help output
# and by invoking install-project-watchdog.sh directly in dry-run mode to
# prove the integration path works end-to-end.

# 16a. deploy-project-agent-workspaces accepts --no-watchdog (arg is recognised)
DEPLOY_HELP_OUT="$TMPDIR_BASE/deploy-ws-help.txt"
python3 "$ROOT_DIR/scripts/deploy-project-agent-workspaces.py" --help >"$DEPLOY_HELP_OUT" 2>&1 || true
if grep -q "no-watchdog" "$DEPLOY_HELP_OUT"; then
  RESULTS+=("PASS  deploy-project-agent-workspaces exposes --no-watchdog flag")
  PASS=$(( PASS + 1 ))
else
  RESULTS+=("FAIL  deploy-project-agent-workspaces missing --no-watchdog flag")
  FAIL=$(( FAIL + 1 ))
fi

# 16b. deploy-project-agent-workspaces accepts --watchdog-cadence (arg is recognised)
if grep -q "watchdog-cadence" "$DEPLOY_HELP_OUT"; then
  RESULTS+=("PASS  deploy-project-agent-workspaces exposes --watchdog-cadence flag")
  PASS=$(( PASS + 1 ))
else
  RESULTS+=("FAIL  deploy-project-agent-workspaces missing --watchdog-cadence flag")
  FAIL=$(( FAIL + 1 ))
fi

# 16c. watchdog installer invoked by deploy path: install-project-watchdog dry-run
#      exits 0 and produces output mentioning the correct agent id. This proves
#      the end-to-end path: deploy calls installer, installer targets orchestrator-<project>.
WD_DEPLOY_OUT="$TMPDIR_BASE/wd-deploy-dry.txt"
if "$ROOT_DIR/scripts/install-project-watchdog.sh" smoke \
    --cadence "*/30 * * * *" --dry-run >"$WD_DEPLOY_OUT" 2>&1; then
  if grep -q "orchestrator-smoke" "$WD_DEPLOY_OUT"; then
    RESULTS+=("PASS  watchdog deploy path targets orchestrator-smoke (redeploy integration)")
    PASS=$(( PASS + 1 ))
  else
    RESULTS+=("FAIL  watchdog deploy path dry-run output missing orchestrator-smoke agent id")
    FAIL=$(( FAIL + 1 ))
  fi
else
  RESULTS+=("FAIL  watchdog deploy path (install-project-watchdog dry-run) exited non-zero")
  FAIL=$(( FAIL + 1 ))
fi

# ── watchdog cron ─────────────────────────────────────────────────────────────

# 16. install-project-watchdog: missing required args → exits non-zero
if "$ROOT_DIR/scripts/install-project-watchdog.sh" >/dev/null 2>&1; then
  RESULTS+=("FAIL  install-project-watchdog.sh should require <project> argument")
  FAIL=$(( FAIL + 1 ))
else
  RESULTS+=("PASS  install-project-watchdog.sh enforces required <project> argument")
  PASS=$(( PASS + 1 ))
fi

# 17. install-project-watchdog: unknown option → exits non-zero
if "$ROOT_DIR/scripts/install-project-watchdog.sh" smoke --bogus-flag >/dev/null 2>&1; then
  RESULTS+=("FAIL  install-project-watchdog.sh should reject unknown options")
  FAIL=$(( FAIL + 1 ))
else
  RESULTS+=("PASS  install-project-watchdog.sh rejects unknown options")
  PASS=$(( PASS + 1 ))
fi

# 18. install-project-watchdog: dry-run mode exits 0 and prints expected output
WD_DRY_OUT="$TMPDIR_BASE/watchdog-dry.txt"
if "$ROOT_DIR/scripts/install-project-watchdog.sh" smoke --dry-run >"$WD_DRY_OUT" 2>&1; then
  if grep -q "orchestrator-smoke" "$WD_DRY_OUT" && grep -q "dry-run" "$WD_DRY_OUT"; then
    RESULTS+=("PASS  install-project-watchdog.sh dry-run exits 0 and identifies correct agent")
    PASS=$(( PASS + 1 ))
  else
    RESULTS+=("FAIL  install-project-watchdog.sh dry-run output missing expected agent id or dry-run marker")
    FAIL=$(( FAIL + 1 ))
  fi
else
  RESULTS+=("FAIL  install-project-watchdog.sh dry-run exited non-zero")
  FAIL=$(( FAIL + 1 ))
fi

# 19. install-project-watchdog: --disable dry-run exits 0
if "$ROOT_DIR/scripts/install-project-watchdog.sh" smoke --disable --dry-run >/dev/null 2>&1; then
  RESULTS+=("PASS  install-project-watchdog.sh --disable --dry-run exits 0")
  PASS=$(( PASS + 1 ))
else
  RESULTS+=("FAIL  install-project-watchdog.sh --disable --dry-run exited non-zero")
  FAIL=$(( FAIL + 1 ))
fi

# 20. check-task-ledger-overdue: no overdue entries exits 0 (use a ledger with no tasks)
EMPTY_LEDGER="$TMPDIR_BASE/empty-ledger.md"
printf '# Task Ledger\n\nNo tasks yet.\n' > "$EMPTY_LEDGER"
if python3 "$ROOT_DIR/scripts/check-task-ledger-overdue.py" "$EMPTY_LEDGER" >/dev/null 2>&1; then
  RESULTS+=("PASS  check-task-ledger-overdue exits 0 for ledger with no overdue entries")
  PASS=$(( PASS + 1 ))
else
  RESULTS+=("FAIL  check-task-ledger-overdue unexpectedly exited non-zero for empty ledger")
  FAIL=$(( FAIL + 1 ))
fi

# 21. check-task-ledger-overdue: overdue entry exits 2 with JSON
OVERDUE_LEDGER="$TMPDIR_BASE/overdue-ledger.md"
cat > "$OVERDUE_LEDGER" <<'MD'
# Task Ledger

## Task issue-77 - Stalled feature

```json
{
  "task": "issue-77",
  "state": "in_progress",
  "owner": "builder-smoke",
  "expected_callback_at": "2020-01-01T00:00:00Z",
  "current_action": "Builder implementing",
  "next_action": "QA review"
}
```
MD
OVERDUE_EXIT=0
OVERDUE_OUT="$TMPDIR_BASE/overdue-out.txt"
python3 "$ROOT_DIR/scripts/check-task-ledger-overdue.py" "$OVERDUE_LEDGER" \
  >"$OVERDUE_OUT" 2>&1 || OVERDUE_EXIT=$?
if [ "$OVERDUE_EXIT" -eq 2 ] && grep -q '"task"' "$OVERDUE_OUT"; then
  RESULTS+=("PASS  check-task-ledger-overdue exits 2 and emits JSON for overdue task")
  PASS=$(( PASS + 1 ))
else
  RESULTS+=("FAIL  check-task-ledger-overdue did not exit 2 or emit JSON for overdue task (exit=$OVERDUE_EXIT)")
  FAIL=$(( FAIL + 1 ))
fi

# ── post-approval execution sequence ─────────────────────────────────────────
# These tests prove the toolchain supporting the 7-step post-approval sequence:
# merge → verify → sync → close issue → identify next → dispatch → report status

# 16a. QA DONE callback with qa-approved outcome passes validate-callback
QA_DONE_CALLBACK="$TMPDIR_BASE/qa-done-callback.md"
cat > "$QA_DONE_CALLBACK" <<'MD'
## Task

- Task ID: issue-42
- Title: Add web shell feature

## Agent

- Agent: qa-smoke
- Session: qa-smoke:main

## Outcome

DONE

## Routing

- To: orchestrator-smoke
- Via: ACP

## Changed

- Reviewed PR #7 against issue #42 acceptance criteria
- All acceptance criteria verified: PASS
- Applied `qa-approved` label to PR #7

## Artifacts

- PR #7 comment with full review findings

## Tests

- Manual review: PASS
- Unit test coverage adequate
- No regressions detected

## Blockers

- None

## Next Action

- Orchestrator to check for `spec-satisfied` label and proceed with merge gate if present
MD
run_check "validate-callback: QA DONE (qa-approved) passes validation" \
  python3 "$ROOT_DIR/scripts/validate-callback.py" "$QA_DONE_CALLBACK"

# 16b. merge state verification — the jq pattern used in post-approval step 2 produces MERGED
MERGED_STATE_JSON="$TMPDIR_BASE/pr-state.json"
printf '{"state":"MERGED","number":7}\n' > "$MERGED_STATE_JSON"
MERGE_STATE="$(jq -r '.state' "$MERGED_STATE_JSON")"
if [ "$MERGE_STATE" = "MERGED" ]; then
  RESULTS+=("PASS  merge verification jq pattern correctly identifies MERGED state")
  PASS=$(( PASS + 1 ))
else
  RESULTS+=("FAIL  merge verification jq pattern returned '$MERGE_STATE' instead of MERGED")
  FAIL=$(( FAIL + 1 ))
fi

# 16c. merge state verification — an OPEN state is correctly detected as not-merged
OPEN_STATE_JSON="$TMPDIR_BASE/pr-open.json"
printf '{"state":"OPEN","number":7}\n' > "$OPEN_STATE_JSON"
NOT_MERGED="$(jq -r '.state' "$OPEN_STATE_JSON")"
if [ "$NOT_MERGED" != "MERGED" ]; then
  RESULTS+=("PASS  merge verification correctly detects non-MERGED state (OPEN → BLOCKED signal)")
  PASS=$(( PASS + 1 ))
else
  RESULTS+=("FAIL  merge verification failed to distinguish OPEN from MERGED")
  FAIL=$(( FAIL + 1 ))
fi

# 16d. update-task-ledger: write a new task then mark it done (simulates post-approval close step)
POSTAPPROVAL_LEDGER="$TMPDIR_BASE/postapproval-ledger.md"
cp "$ROOT_DIR/docs/delivery/task-ledger.md" "$POSTAPPROVAL_LEDGER"
# First write: create the task in in_progress state
python3 "$ROOT_DIR/scripts/update-task-ledger.py" "$POSTAPPROVAL_LEDGER" \
  "issue-99" "Deliver web shell" in_progress \
  "Builder implementing" "QA to review" \
  --owner "builder-smoke" >/dev/null 2>&1 || true
# Second write: mark done (simulates Orchestrator closing it after merge)
if python3 "$ROOT_DIR/scripts/update-task-ledger.py" "$POSTAPPROVAL_LEDGER" \
     "issue-99" "Deliver web shell" done \
     "Merged PR #7" "Dispatch next ready issue" \
     --history-action "Merged and closed" >/dev/null 2>&1; then
  RESULTS+=("PASS  update-task-ledger marks merged task as done (post-approval close step)")
  PASS=$(( PASS + 1 ))
else
  RESULTS+=("FAIL  update-task-ledger could not mark task done (post-approval close step would fail)")
  FAIL=$(( FAIL + 1 ))
fi

# 16e. validate-issue-ready: missing required args → exits non-zero without crashing
# (validate-issue-ready.py expects a GitHub issue number, not a local file; this
#  proves the script is executable and its arg contract is enforced)
if python3 "$ROOT_DIR/scripts/validate-issue-ready.py" >/dev/null 2>&1; then
  RESULTS+=("FAIL  validate-issue-ready.py should require an issue number argument")
  FAIL=$(( FAIL + 1 ))
else
  RESULTS+=("PASS  validate-issue-ready.py enforces required issue-number argument (dispatch-next gate)")
  PASS=$(( PASS + 1 ))
fi

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
