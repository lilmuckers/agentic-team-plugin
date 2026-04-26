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

1. Query the MCP ledger for overdue and blocked tasks:
     task_list project_slug=${PROJECT} overdue=true
     task_list project_slug=${PROJECT} state=blocked

   If both return empty lists, stop — nothing to do.
   If the MCP server is unreachable, report BLOCKED with reason mcp-unavailable and stop.

2. For each overdue task, apply this classification decision tree in order:

   STEP A — Check for explicit blocker in visible GitHub artifacts:
     gh issue view <task-id> --repo <owner/repo>
     gh pr view <pr-number> --repo <owner/repo> (if a PR number is in the ledger)
   If the issue or PR shows an explicit blocker comment, label, or reported dependency:
     → classify as BLOCKED (step D)

   STEP B — Check for completion artifact:
     gh pr list --repo <owner/repo> --search 'head:<expected-branch>'
     git log or recent commits if a branch name is known
   If a merged PR or closed issue confirms work is done:
     → classify as DONE-BUT-MISSED-CALLBACK (step E)
   If recent activity (commit, PR open, comment) shows active progress:
     → classify as IN-PROGRESS (step F)

   STEP C — Default rule for overdue owner-assigned tasks:
   If the ledger has a named owner (builder-<project>, spec-<project>, etc.)
   and no explicit blocker was found in step A
   and no completion or active-progress artifact was found in step B:

     → classify as STALLED

   Absence of visible artifact does NOT mean unknown. If a named agent owns
   the task and has not reported back, the correct assumption is stall, not
   an unresolvable situation. The watchdog exists precisely for this case.

   Only use UNKNOWN when the ledger entry itself is malformed, missing an
   owner, or self-contradictory so that there is no safe agent to nudge.

3. Act on each classification:

   D. BLOCKED
      Evidence: explicit blocker reported in a GitHub artifact.
      Action: task_transition to_state=blocked + task_add_note with specific reason;
      surface to operator; do not reassign without operator direction.

   E. DONE-BUT-MISSED-CALLBACK
      Evidence: merged PR or closed issue, but no callback received.
      Action: accept implicit completion; task_transition to_state=done; route next step.

   F. IN-PROGRESS
      Evidence: recent commit, open PR, or issue comment since last watchdog pass.
      Action: task_update expected_callback_at=<+30min> + task_add_note with what
      you observed; no nudge needed.

   G. STALLED (the default for overdue owner-assigned tasks)
      Evidence: named owner, overdue, no explicit blocker, no completion artifact.
      This is the most common watchdog case — a worker that dispatched correctly
      but has gone silent. It is NOT a confirmed blocker.
      Action:
        1. Dispatch a nudge to the owning agent via scripts/dispatch-named-agent.sh
        2. task_update expected_callback_at=<+30min> + task_add_note recording the stall
        3. Do not transition to blocked yet
      On the next watchdog pass, if state is still stalled with no visible progress:
        → escalate to operator and task_transition to_state=blocked

   H. UNKNOWN
      Evidence: task record is missing an owner or is self-contradictory.
      Action: surface the raw task_get result to the operator; do not guess.

4. After acting on each overdue task, update the MCP task record using task_transition,
   task_update, or task_add_note to reflect your assessment.

Remember: this is a watchdog, not a controller. Callbacks remain the authoritative completion signal.
The default response to a silent worker is to nudge, not to block or escalate.
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
  echo "[dry-run] would run: openclaw cron add --name $CRON_NAME --cron \"$CADENCE\" --agent $AGENT_ID --message <watchdog-message> --thinking low --channel none"
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
  --channel none \
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
