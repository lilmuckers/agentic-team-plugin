#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/validate-project-activation.sh <project-slug> <repo-path> [--require-active]

Options:
  --require-active   Exit non-zero if project is not yet ACTIVE (default: report only)

Examples:
  scripts/validate-project-activation.sh musical-statues ../musical-statues
  scripts/validate-project-activation.sh musical-statues ../musical-statues --require-active
EOF
}

if [ $# -lt 2 ]; then
  usage
  exit 1
fi

PROJECT="$1"
REPO_PATH="$2"
REQUIRE_ACTIVE=0

shift 2
while [ $# -gt 0 ]; do
  case "$1" in
    --require-active) REQUIRE_ACTIVE=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
  shift
done

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
STATE_FILE="$REPO_PATH/docs/delivery/project-state.md"
ISSUE_READY_SCRIPT="$ROOT_DIR/scripts/validate-issue-ready.py"

PASS=0
FAIL=0

check() {
  local label="$1"
  local result="$2"  # "ok" or "fail"
  local detail="${3:-}"
  if [ "$result" = "ok" ]; then
    echo "  OK    $label"
    PASS=$(( PASS + 1 ))
  else
    echo "  FAIL  $label${detail:+ — $detail}"
    FAIL=$(( FAIL + 1 ))
  fi
}

echo ""
echo "Project activation check: $PROJECT"
echo "Repo: $REPO_PATH"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── project-state.md exists ───────────────────────────────────────────────────

if [ ! -f "$STATE_FILE" ]; then
  echo "  FAIL  docs/delivery/project-state.md does not exist — project has no activation record"
  echo ""
  echo "State: UNKNOWN (state file missing)"
  echo "Run scripts/onboard-project.sh to bootstrap the project."
  exit 1
fi

# ── extract state ─────────────────────────────────────────────────────────────

STATE="$(python3 - "$STATE_FILE" <<'PY'
import sys, re, json

content = open(sys.argv[1]).read()
# extract first json block
m = re.search(r'```json\s*(\{.*?\})\s*```', content, re.DOTALL)
if not m:
    print("UNKNOWN")
    sys.exit(0)
try:
    data = json.loads(m.group(1))
    print(data.get("state", "UNKNOWN"))
except Exception:
    print("UNKNOWN")
PY
)"

echo "  State file found: $STATE_FILE"
echo "  Recorded state:   $STATE"
echo ""

# ── BOOTSTRAPPED checks ───────────────────────────────────────────────────────

echo "── BOOTSTRAPPED conditions ──────────────────────────────────────────────"

[ -f "$REPO_PATH/SPEC.md" ] \
  && check "SPEC.md exists" ok \
  || check "SPEC.md exists" fail "missing"

[ -f "$REPO_PATH/docs/delivery/task-ledger.md" ] \
  && check "task-ledger.md exists" ok \
  || check "task-ledger.md exists" fail "missing"

[ -f "$REPO_PATH/docs/delivery/release-state.md" ] \
  && check "release-state.md exists" ok \
  || check "release-state.md exists" fail "missing"

[ -f "$REPO_PATH/.github/workflows/merge-gate.yml" ] \
  && check "merge-gate.yml exists" ok \
  || check "merge-gate.yml exists" fail "missing"

[ -f "$REPO_PATH/.github/pull_request_template.md" ] \
  && check "PR template exists" ok \
  || check "PR template exists" fail "missing"

echo ""

# ── DEFINED checks ────────────────────────────────────────────────────────────

echo "── DEFINED conditions ───────────────────────────────────────────────────"

# SPEC.md non-placeholder (more than 5 lines and doesn't contain the placeholder marker)
if [ -f "$REPO_PATH/SPEC.md" ]; then
  SPEC_LINES="$(wc -l < "$REPO_PATH/SPEC.md")"
  if [ "$SPEC_LINES" -gt 10 ] && ! grep -q "<!-- placeholder" "$REPO_PATH/SPEC.md"; then
    check "SPEC.md non-placeholder" ok
  else
    check "SPEC.md non-placeholder" fail "file is too short ($SPEC_LINES lines) or contains placeholder marker"
  fi
else
  check "SPEC.md non-placeholder" fail "SPEC.md missing"
fi

# spec-approval issue check (requires gh)
if command -v gh >/dev/null 2>&1 && git -C "$REPO_PATH" remote get-url origin >/dev/null 2>&1; then
  ORIGIN="$(git -C "$REPO_PATH" remote get-url origin)"
  # extract owner/repo from remote URL
  GITHUB_REPO="$(echo "$ORIGIN" | sed -E 's|.*[:/]([^/]+/[^/]+?)(\.git)?$|\1|')"
  OPEN_APPROVAL="$(gh issue list --repo "$GITHUB_REPO" --label spec-approval --state open --json number --jq 'length' 2>/dev/null || echo "unknown")"
  CLOSED_APPROVAL="$(gh issue list --repo "$GITHUB_REPO" --label spec-approval --state closed --json number --jq 'length' 2>/dev/null || echo "unknown")"
  if [ "$CLOSED_APPROVAL" = "unknown" ] || [ "$OPEN_APPROVAL" = "unknown" ]; then
    check "spec-approval issue" fail "could not query GitHub (check gh auth)"
  elif [ "$OPEN_APPROVAL" -gt 0 ]; then
    check "spec-approval issue" fail "spec-approval issue is still open — human has not approved yet"
  elif [ "$CLOSED_APPROVAL" -gt 0 ]; then
    check "spec-approval issue closed by human" ok
  else
    check "spec-approval issue" fail "no spec-approval issue found — create one and have human close it to activate"
  fi
else
  check "spec-approval issue" fail "skipped (gh not available or no git remote)"
fi

echo ""

# ── ACTIVE check ──────────────────────────────────────────────────────────────

echo "── ACTIVE conditions ────────────────────────────────────────────────────"

if [ "$STATE" = "ACTIVE" ]; then
  check "project-state.md records ACTIVE" ok
else
  check "project-state.md records ACTIVE" fail "current state is '$STATE'"
fi

# Check at least one ready issue exists (optional — requires gh)
if command -v gh >/dev/null 2>&1 && [ -n "${GITHUB_REPO:-}" ]; then
  READY_ISSUES="$(gh issue list --repo "$GITHUB_REPO" --label ready-for-build --state open --json number --jq 'length' 2>/dev/null || echo "unknown")"
  if [ "$READY_ISSUES" = "unknown" ]; then
    check "at least one ready-for-build issue" fail "could not query GitHub"
  elif [ "$READY_ISSUES" -gt 0 ]; then
    check "at least one ready-for-build issue ($READY_ISSUES found)" ok
  else
    check "at least one ready-for-build issue" fail "no issues labeled ready-for-build"
  fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Passed: $PASS  Failed: $FAIL"
echo "  Recorded state: $STATE"
echo ""

if [ "$FAIL" -gt 0 ]; then
  if [ "$REQUIRE_ACTIVE" -eq 1 ]; then
    echo "Project is not ACTIVE. Builder must not begin implementation." >&2
    exit 1
  else
    echo "One or more activation conditions are not met. See above."
    exit 0
  fi
fi

if [ "$STATE" != "ACTIVE" ]; then
  if [ "$REQUIRE_ACTIVE" -eq 1 ]; then
    echo "All conditions appear met but project-state.md still records '$STATE'." >&2
    echo "Orchestrator must update project-state.md to ACTIVE after human approval." >&2
    exit 1
  fi
fi

echo "Project $PROJECT is ACTIVE and ready for delivery."
