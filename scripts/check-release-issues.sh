#!/usr/bin/env bash
set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required" >&2
  exit 1
fi

if [ $# -lt 2 ]; then
  cat >&2 <<'EOF'
Usage:
  scripts/check-release-issues.sh <owner/repo> <release-label> [--state open|closed|all]

Examples:
  scripts/check-release-issues.sh owner/repo release:v0.2.0
  scripts/check-release-issues.sh owner/repo release:v0.2.0 --state open
EOF
  exit 1
fi

REPO="$1"
LABEL="$2"
STATE="open"
shift 2

while [ $# -gt 0 ]; do
  case "$1" in
    --state)
      STATE="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

case "$STATE" in
  open|closed|all) ;;
  *)
    echo "State must be one of: open, closed, all" >&2
    exit 1
    ;;
esac

gh issue list --repo "$REPO" --limit 200 --state "$STATE" --label "$LABEL" --json number,title,state,url,labels
