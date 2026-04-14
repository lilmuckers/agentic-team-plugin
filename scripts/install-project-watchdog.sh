#!/usr/bin/env bash
set -euo pipefail

# Install a single per-project Orchestrator watchdog cron.
#
# Creates one native OpenClaw cron job per project, targeting
# orchestrator-<project>. Only the Orchestrator is watchdogged — not Spec,
# Security, Release Manager, Builder, or QA. Orchestrator already owns all
# follow-through coordination; centralising the watchdog there avoids
# duplicated cron logic across every persistent archetype.
#
# Idempotent: removes and recreates any existing cron with the same name so
# re-deploying or changing cadence does not accumulate duplicate jobs.
#
# Cron name: <project>-orchestrator-watchdog
#
# The watchdog is NOT the primary completion mechanism. Explicit callbacks
# from workers remain authoritative. This cron exists only to catch:
#   - missed callbacks
#   - stalled worker sessions
#   - overdue in-flight tasks
#
# Usage:
#   scripts/install-project-watchdog.sh <project> [options]
#
# Options:
#   --cadence <cron>   Cron schedule expression (default: "*/30 * * * *")
#   --dry-run          Print the openclaw commands without executing them
#   --disable          Remove the watchdog cron for this project and exit
#
# Examples:
#   scripts/install-project-watchdog.sh lapwing
#   scripts/install-project-watchdog.sh lapwing --cadence "*/15 * * * *"
#   scripts/install-project-watchdog.sh lapwing --cadence "*/30 8-20 * * 1-5"
#   scripts/install-project-watchdog.sh lapwing --disable

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/install-project-watchdog.sh <project> [options]

Options:
  --cadence <cron>   Cron schedule expression (default: "*/30 * * * *")
  --dry-run          Print actions without executing
  --disable          Remove the watchdog cron for this project and exit

Examples:
  scripts/install-project-watchdog.sh lapwing
  scripts/install-project-watchdog.sh lapwing --cadence "*/15 * * * *"
  scripts/install-project-watchdog.sh lapwing --disable
EOF
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

PROJECT=""
CADENCE="*/30 * * * *"
DRY_RUN=0
DISABLE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --cadence)  shift; CADENCE="$1" ;;
    --dry-run)  DRY_RUN=1 ;;
    --disable)  DISABLE=1 ;;
    -h|--help)  usage; exit 0 ;;
    -*)
      echo "ERROR: unknown option: $1" >&2
      usage
      exit 1
      ;;
    *)
      if [ -z "$PROJECT" ]; then
        PROJECT="$1"
      else
        echo "ERROR: unexpected argument: $1" >&2
        usage
        exit 1
      fi
      ;;
  esac
  shift
done

if [ -z "$PROJECT" ]; then
  echo "ERROR: <project> is required" >&2
  usage
  exit 1
fi

AGENT_ID="orchestrator-${PROJECT}"
CRON_NAME="${PROJECT}-orchestrator-watchdog"

run() {
  echo "+ $*"
  if [ "$DRY_RUN" -ne 1 ]; then
    "$@"
  fi
}

# ── disable path ──────────────────────────────────────────────────────────────

if [ "$DISABLE" -eq 1 ]; then
  echo "Removing watchdog cron: $CRON_NAME"
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] would look up $CRON_NAME in cron list, then run: openclaw cron rm <uuid>"
  else
    DISABLE_ID="$(openclaw cron list --json 2>/dev/null \
      | python3 -c "
import json, sys
try:
    data = json.loads(sys.stdin.read())
    for job in data.get('jobs', []):
        if job.get('name') == sys.argv[1]:
            print(job['id'])
            break
except Exception:
    pass
" "$CRON_NAME")"
    if [ -n "$DISABLE_ID" ]; then
      openclaw cron rm "$DISABLE_ID" 2>/dev/null \
        && echo "Watchdog cron removed: $CRON_NAME (id: $DISABLE_ID)" \
        || echo "WARNING: cron rm returned non-zero for id $DISABLE_ID" >&2
    else
      echo "No cron named '$CRON_NAME' found (already removed or never created)"
    fi
  fi
  exit 0
fi

# ── watchdog message ──────────────────────────────────────────────────────────
#
# This message is delivered to orchestrator-<project> on each cron tick.
# It instructs Orchestrator to run the overdue detector and follow up on any
# stalled work. It must not create new tasks or change scope.

WATCHDOG_MESSAGE="$(cat <<WATCHDOG_EOF
Watchdog heartbeat for project: ${PROJECT}.

This is an automated check — not a new request. Inspect in-flight work for missed callbacks or stalls.

Do not create new work, change scope, merge, or release in response to this message.

Steps:

1. Run the overdue detector:
   python3 scripts/check-task-ledger-overdue.py repo/docs/delivery/task-ledger.md --grace-minutes 15

   Interpret the exit code:
   - 0: no overdue entries — nothing to do, stop here
   - 1: ledger error — surface to operator immediately
   - 2: overdue entries found — continue to step 2

2. For each overdue task in the JSON output, check visible GitHub state first:
     gh issue view <task-id> --repo <owner/repo>
     gh pr list --repo <owner/repo> --search 'head:<expected-branch>' (if a PR was expected)

   Classify the worker state and act:

   a. DONE-BUT-MISSED-CALLBACK
      Visible artifact confirms work is complete but no callback arrived.
      Action: accept the implicit callback, update the task ledger to done, route the next step.

   b. IN-PROGRESS
      Recent commit, PR activity, or comment trail shows the worker is still progressing.
      Action: update ledger current_action with what you observed; extend expected_callback_at
      by 30 minutes; no nudge needed yet.

   c. STALLED
      No visible progress since the expected callback time. The worker may still be running
      but is silent. This is NOT a true blocker — do not mark it blocked.
      Action: dispatch a nudge to the owning agent via scripts/dispatch-named-agent.sh;
      update ledger state to stalled and record the watchdog note in current_action.
      If STALLED recurs on the next watchdog pass with still no visible progress, escalate
      to the human operator and mark it blocked at that point instead.

   d. BLOCKED
      Worker reported an explicit external blocker in a comment or PR but the ledger was
      not updated, OR two consecutive watchdog passes both showed STALLED.
      Action: surface the blocker or repeated stall to the human operator; update the
      ledger state to blocked with the specific reason; do not reassign without operator direction.

   e. UNKNOWN
      No visible artifact, no callback, no evidence of progress.
      Action: surface to the human operator with full task details from the ledger;
      do not reassign silently.

3. After acting on each overdue task, update the ledger using scripts/update-task-ledger.py
   to reflect your assessment.

Remember: this is a watchdog, not a controller. Callbacks remain the authoritative completion signal.
WATCHDOG_EOF
)"

# ── install cron ──────────────────────────────────────────────────────────────
#
# CLI shape for OpenClaw 2026.4.8:
#   openclaw cron add --name <name> --cron <expr> --agent <agent-id> \
#                     --message <msg> --thinking <level>
#   openclaw cron rm <uuid>          # takes UUID, not name
#   openclaw cron list --json        # returns { jobs: [...] }
#
# Idempotency: look up existing job by name in list output, remove by UUID,
# then recreate. This guarantees the cron message and schedule are always
# current after a framework update.

cron_id_by_name() {
  # Print the UUID of the cron job with the given name, or nothing if absent.
  openclaw cron list --json 2>/dev/null \
    | python3 -c "
import json, sys
try:
    data = json.loads(sys.stdin.read())
    for job in data.get('jobs', []):
        if job.get('name') == sys.argv[1]:
            print(job['id'])
            break
except Exception:
    pass
" "$1"
}

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[dry-run] would look up existing cron by name: $CRON_NAME"
  echo "[dry-run] would run: openclaw cron rm <uuid> (if exists)"
  echo "[dry-run] would run: openclaw cron add --name $CRON_NAME --cron \"$CADENCE\" --agent $AGENT_ID --message <watchdog-message> --thinking low"
  echo "Installing watchdog cron: $CRON_NAME"
  echo "  Target agent: $AGENT_ID"
  echo "  Schedule:     $CADENCE"
  echo "Watchdog cron would be installed for project: $PROJECT (dry-run)"
  exit 0
fi

# Remove any existing job with this name (idempotent).
EXISTING_ID="$(cron_id_by_name "$CRON_NAME")"
if [ -n "$EXISTING_ID" ]; then
  echo "Removing existing watchdog cron: $CRON_NAME (id: $EXISTING_ID)"
  if ! openclaw cron rm "$EXISTING_ID" 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if d.get('removed') else 1)" 2>/dev/null; then
    echo "WARNING: failed to remove existing cron $EXISTING_ID; will attempt to create anyway" >&2
  fi
fi

echo "Installing watchdog cron: $CRON_NAME"
echo "  Target agent: $AGENT_ID"
echo "  Schedule:     $CADENCE"

ADD_OUTPUT="$(openclaw cron add \
  --name "$CRON_NAME" \
  --cron "$CADENCE" \
  --agent "$AGENT_ID" \
  --message "$WATCHDOG_MESSAGE" \
  --thinking low \
  --json 2>&1)"

ADD_EXIT=$?
if [ $ADD_EXIT -ne 0 ]; then
  echo "ERROR: failed to install watchdog cron for $PROJECT (exit $ADD_EXIT)" >&2
  echo "$ADD_OUTPUT" >&2
  exit 1
fi

NEW_ID="$(printf '%s' "$ADD_OUTPUT" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('id','?'))" 2>/dev/null || true)"
echo "Watchdog cron installed: $CRON_NAME (id: $NEW_ID)"
echo "  Orchestrator ($AGENT_ID) will receive watchdog nudges on schedule: $CADENCE"
echo "  To verify: openclaw cron list | grep $CRON_NAME"
echo "  To remove: scripts/install-project-watchdog.sh $PROJECT --disable"
