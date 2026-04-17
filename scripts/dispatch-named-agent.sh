#!/usr/bin/env bash
set -euo pipefail

# Send a task directly to an existing named project agent session.
#
# This is the ONLY correct dispatch path for project-scoped named agents:
#   spec-<project>, builder-<project>, qa-<project>,
#   security-<project>, release-manager-<project>
#
# ── Delivery vs completion ────────────────────────────────────────────────────
# This script confirms task DELIVERY only. A successful exit (0) means the
# task message was accepted by the named agent's session. It does NOT mean
# the task is complete.
#
# Task completion is signalled by the named agent sending an explicit callback
# to orchestrator-<project> using scripts/send-agent-callback.sh.
#
# ── Runtime-enforced gates ────────────────────────────────────────────────────
# This script enforces precondition gates before dispatch. These cannot be
# bypassed by prompt instruction — the script will exit non-zero if conditions
# are not met.
#
#   builder dispatch  — requires --repo-path; project must be ACTIVE
#                       (docs/delivery/project-state.md state == "ACTIVE")
#
#   release-manager   — requires --release-issue and --release-repo;
#   dispatch            tracking issue must have a valid trigger, version,
#                       scale, and scope basis
#
# ── Behaviour ────────────────────────────────────────────────────────────────
# - Routes by agent name only — no synthetic --session-id unless an explicit
#   task-suffix is provided. OpenClaw resolves the live session internally.
# - Does NOT spawn a new session.
# - Does NOT fall back to a generic sub-agent. Exits non-zero on unavailability.

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/dispatch-named-agent.sh <project> <archetype> <task-file> [options]

Positional arguments:
  project      project slug, e.g. merlin
  archetype    agent role: spec | builder | qa | security | release-manager | orchestrator
  task-file    path to the task message file

Options:
  --repo-path <path>           Required for builder dispatch.
                               Path to the project repo; used to verify project
                               is ACTIVE before Builder is dispatched.
  --release-issue <number>     Required for release-manager dispatch.
                               Release tracking issue number.
  --release-repo <owner/repo>  Required when --release-issue is supplied.
  --task-suffix <suffix>       Disambiguate session id, e.g. issue-42
  --thinking <level>           minimal | low | medium | high (default: minimal)

Examples:
  scripts/dispatch-named-agent.sh merlin spec issue-5.md
  scripts/dispatch-named-agent.sh merlin builder issue-5.md --repo-path ../merlin --task-suffix issue-5
  scripts/dispatch-named-agent.sh merlin qa pr-review.md --task-suffix pr-42 --thinking low
  scripts/dispatch-named-agent.sh merlin release-manager release-task.md \
    --release-issue 42 --release-repo org/merlin
EOF
}

if [ $# -lt 3 ]; then
  usage
  exit 1
fi

PROJECT="$1"
ARCHETYPE="$2"
TASK_FILE="$3"
shift 3

REPO_PATH=""
RELEASE_ISSUE=""
RELEASE_REPO=""
TASK_SUFFIX=""
THINKING="minimal"

while [ $# -gt 0 ]; do
  case "$1" in
    --repo-path)      shift; REPO_PATH="$1" ;;
    --release-issue)  shift; RELEASE_ISSUE="$1" ;;
    --release-repo)   shift; RELEASE_REPO="$1" ;;
    --task-suffix)    shift; TASK_SUFFIX="$1" ;;
    --thinking)       shift; THINKING="$1" ;;
    -h|--help)        usage; exit 0 ;;
    *)
      # legacy positional compat: 4th arg = task-suffix, 5th = thinking
      if [ -z "$TASK_SUFFIX" ]; then
        TASK_SUFFIX="$1"
      elif [ "$THINKING" = "minimal" ]; then
        THINKING="$1"
      else
        echo "ERROR: unexpected argument: $1" >&2
        usage
        exit 1
      fi
      ;;
  esac
  shift
done

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [ ! -f "$TASK_FILE" ]; then
  echo "ERROR: task file not found: $TASK_FILE" >&2
  exit 1
fi

# ── Gate: builder requires ACTIVE project ────────────────────────────────────

if [ "$ARCHETYPE" = "builder" ]; then
  if [ -z "$REPO_PATH" ]; then
    echo "ERROR: --repo-path is required when dispatching builder." >&2
    echo "  Builder must not start until the project is ACTIVE." >&2
    echo "  Provide the project repo path so the activation state can be verified." >&2
    exit 1
  fi

  echo "Checking project activation state before builder dispatch..."
  if ! "$ROOT_DIR/scripts/validate-project-activation.sh" "$PROJECT" "$REPO_PATH" --require-active; then
    cat >&2 <<EOF

DISPATCH BLOCKED: project '$PROJECT' is not ACTIVE.

Builder cannot be dispatched until:
  1. SPEC.md is non-placeholder
  2. At least one wiki page with project context exists
  3. At least one issue passes validate-issue-ready.py
  4. Human has closed the spec-approval issue
  5. Orchestrator has recorded ACTIVE in docs/delivery/project-state.md

Do not proceed. Route back to Spec or wait for human approval.
EOF
    exit 1
  fi
fi

# ── Gate: release-manager requires valid release tracking issue ───────────────

if [ "$ARCHETYPE" = "release-manager" ]; then
  if [ -z "$RELEASE_ISSUE" ] || [ -z "$RELEASE_REPO" ]; then
    echo "ERROR: --release-issue and --release-repo are required when dispatching release-manager." >&2
    echo "  Orchestrator must open a valid release tracking issue BEFORE dispatching Release Manager." >&2
    echo "  The issue must have a legal trigger, version, scale, and scope basis." >&2
    exit 1
  fi

  echo "Validating release tracking issue #${RELEASE_ISSUE} (${RELEASE_REPO}) before release-manager dispatch..."
  if ! python3 "$ROOT_DIR/scripts/validate-release-request.py" "$RELEASE_ISSUE" --repo "$RELEASE_REPO"; then
    cat >&2 <<EOF

DISPATCH BLOCKED: release tracking issue #${RELEASE_ISSUE} is not valid.

Release Manager cannot be dispatched until the tracking issue has:
  - A valid trigger-source checkbox checked (human instruction or Orchestrator pre-agreed condition)
  - A non-placeholder trigger narrative
  - A proposed semver version
  - A version scale checkbox checked (major/minor/patch)
  - A non-empty scope basis

Fix the release tracking issue, then retry dispatch.
EOF
    exit 1
  fi
fi

# ── Dispatch ──────────────────────────────────────────────────────────────────

AGENT_ID="${ARCHETYPE}-${PROJECT}"
MESSAGE="$(cat "$TASK_FILE")"

OPENCLAW_ARGS=(
  --agent "$AGENT_ID"
  --message "$MESSAGE"
  --thinking "$THINKING"
  --json
)

if [ -n "$TASK_SUFFIX" ]; then
  SESSION_GEN="$ROOT_DIR/scripts/agent-session-id.py"
  SESSION_ID="$(python3 "$SESSION_GEN" --project "$PROJECT" --agent "$ARCHETYPE" --task "$TASK_SUFFIX")"
  OPENCLAW_ARGS+=(--session-id "$SESSION_ID")
  echo "Dispatching to named agent: $AGENT_ID (session: $SESSION_ID)"
else
  echo "Dispatching to named agent: $AGENT_ID"
fi

echo "NOTE: This confirms delivery only. Task completion comes via send-agent-callback.sh."

if ! openclaw agent "${OPENCLAW_ARGS[@]}"; then
  cat >&2 <<EOF

ERROR: dispatch to named agent '$AGENT_ID' failed — task was NOT delivered.

This path does NOT fall back to a generic sub-agent.
Possible causes:
  - The named agent session is not running.
  - The OpenClaw runtime does not support direct named-agent dispatch on this surface.
  - The agent id '$AGENT_ID' does not exist in the current namespace.

Required action:
  Surface this as a blocker to the human operator.
  Do not substitute a generic archetype-shaped worker unless the operator
  has explicitly approved that substitution for this task.
EOF
  exit 1
fi

echo "Task delivered to $AGENT_ID. Waiting for callback via send-agent-callback.sh."
