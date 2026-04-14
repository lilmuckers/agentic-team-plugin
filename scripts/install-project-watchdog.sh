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
    echo "[dry-run] would run: openclaw cron delete $CRON_NAME"
  else
    openclaw cron delete "$CRON_NAME" 2>/dev/null \
      && echo "Watchdog cron removed: $CRON_NAME" \
      || echo "No cron named '$CRON_NAME' found (already removed or never created)"
  fi
  exit 0
fi

# ── watchdog message ──────────────────────────────────────────────────────────
#
# This message is delivered to orchestrator-<project> on each cron tick.
# It instructs Orchestrator to run the overdue detector and follow up on any
# stalled work. It must not create new tasks or change scope.

WATCHDOG_MESSAGE="Watchdog heartbeat for project: ${PROJECT}.

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
     gh pr list --repo <owner/repo> --search \"head:<expected-branch>\" (if a PR was expected)

   Classify the worker state and act:

   a. DONE-BUT-MISSED-CALLBACK
      Visible artifact confirms work is complete but no callback arrived.
      → Accept the implicit callback, update the task ledger to done, route the next step.

   b. IN-PROGRESS
      Recent commit, PR activity, or comment trail shows the worker is still progressing.
      → Update ledger current_action with what you observed.
      → Extend expected_callback_at by 30 minutes.
      → No nudge needed yet.

   c. STALLED
      No visible progress since the expected callback time.
      → Dispatch a nudge to the owning agent:
        scripts/dispatch-named-agent.sh ${PROJECT} <archetype> <nudge-task-file>
      → Update ledger: state = blocked, reason = watchdog stall detected.

   d. BLOCKED
      Worker reported a blocker in a comment or PR but the ledger was not updated.
      → Surface the blocker to the human operator.
      → Update the ledger to reflect the blockage.

   e. UNKNOWN
      No visible artifact, no callback, no evidence of progress.
      → Surface to the human operator with full task details from the ledger.
      → Do not reassign silently.

3. After acting on each overdue task, update scripts/update-task-ledger.py to reflect your assessment.

Remember: this is a watchdog, not a controller. Callbacks remain the authoritative completion signal."

# ── install cron ──────────────────────────────────────────────────────────────

# Remove any existing job with this name first (idempotent).
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[dry-run] would run: openclaw cron delete $CRON_NAME (idempotent; ok if absent)"
else
  openclaw cron delete "$CRON_NAME" 2>/dev/null || true
fi

echo "Installing watchdog cron: $CRON_NAME"
echo "  Target agent: $AGENT_ID"
echo "  Schedule:     $CADENCE"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[dry-run] would run: openclaw cron add --name $CRON_NAME --schedule \"$CADENCE\" --agent $AGENT_ID --message <watchdog-message> --thinking low"
  echo "Watchdog cron would be installed for project: $PROJECT (dry-run)"
  exit 0
fi

openclaw cron add \
  --name "$CRON_NAME" \
  --schedule "$CADENCE" \
  --agent "$AGENT_ID" \
  --message "$WATCHDOG_MESSAGE" \
  --thinking low

echo "Watchdog cron installed: $CRON_NAME"
echo "  Orchestrator ($AGENT_ID) will receive watchdog nudges on schedule: $CADENCE"
echo "  To verify: openclaw cron list | grep $CRON_NAME"
echo "  To remove: scripts/install-project-watchdog.sh $PROJECT --disable"
