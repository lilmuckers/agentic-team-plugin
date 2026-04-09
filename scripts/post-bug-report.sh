#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/post-bug-report.sh <owner/repo> <issue|pr> <number> <bug-report-file> [--archetype QA]
EOF
}

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required" >&2
  exit 1
fi

if [ $# -lt 4 ]; then
  usage
  exit 1
fi

REPO="$1"
TARGET_KIND="$2"
TARGET_NUMBER="$3"
BUG_REPORT_FILE="$4"
shift 4
ARCHETYPE="QA"

while [ $# -gt 0 ]; do
  case "$1" in
    --archetype)
      ARCHETYPE="${2:-}"
      shift 2
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [ ! -f "$BUG_REPORT_FILE" ]; then
  echo "ERROR: bug report file not found: $BUG_REPORT_FILE" >&2
  exit 1
fi

BODY_FILE=$(mktemp)
trap 'rm -f "$BODY_FILE"' EXIT
python3 "$(cd "$(dirname "$0")/.." && pwd)/scripts/render-agent-comment.py" --archetype "$ARCHETYPE" --input "$BUG_REPORT_FILE" > "$BODY_FILE"

case "$TARGET_KIND" in
  issue)
    gh issue comment "$TARGET_NUMBER" --repo "$REPO" --body-file "$BODY_FILE"
    ;;
  pr)
    gh pr comment "$TARGET_NUMBER" --repo "$REPO" --body-file "$BODY_FILE"
    ;;
  *)
    echo "ERROR: target kind must be 'issue' or 'pr'" >&2
    exit 1
    ;;
esac
