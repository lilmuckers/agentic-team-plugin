#!/usr/bin/env bash
set -euo pipefail

# Guard: block final release publication unless explicit human approval is
# recorded on the release tracking issue.
#
# Checks:
#   1. The "Approval requested" checkbox is checked on the issue.
#   2. The "Human approved" checkbox is checked on the issue.
#   3. The approval field body contains non-placeholder text.
#
# Exit 0 = approved and safe to proceed.
# Exit 1 = not approved; Release Manager must not publish the final release.
#
# Usage:
#   scripts/guard-final-release.sh <issue-number> <owner/repo>

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/guard-final-release.sh <issue-number> <owner/repo>

Examples:
  scripts/guard-final-release.sh 42 org/my-project
EOF
}

if [ $# -ne 2 ]; then
  usage
  exit 1
fi

ISSUE_NUMBER="$1"
REPO="$2"

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: gh CLI is required but not found" >&2
  exit 1
fi

# Fetch issue body
BODY="$(gh api "repos/${REPO}/issues/${ISSUE_NUMBER}" --jq '.body' 2>/dev/null || true)"

if [ -z "$BODY" ]; then
  echo "ERROR: could not fetch issue #${ISSUE_NUMBER} from ${REPO}" >&2
  exit 1
fi

STATE="$(gh api "repos/${REPO}/issues/${ISSUE_NUMBER}" --jq '.state' 2>/dev/null || echo "unknown")"
if [ "$STATE" = "closed" ]; then
  echo "ERROR: release tracking issue #${ISSUE_NUMBER} is already closed" >&2
  echo "  If this is intentional, verify the release was published correctly." >&2
  exit 1
fi

ERRORS=()

# Check "Approval requested" checkbox
if ! echo "$BODY" | grep -iq "\[x\].*approval requested"; then
  ERRORS+=("'Approval requested' checkbox is not checked — Release Manager must request human approval before publishing final release")
fi

# Check "Human approved" checkbox
if ! echo "$BODY" | grep -iq "\[x\].*human approved"; then
  ERRORS+=("'Human approved' checkbox is not checked — human must explicitly approve on the issue before final release publication")
fi

# Check the approval body contains non-placeholder content
# Extract content after "Human approved" section header
APPROVAL_CONTENT="$(python3 - "$BODY" <<'PY'
import sys, re
body = sys.argv[1]
m = re.search(r'##\s+Human final approval\s*\n(.*?)(?=\n##\s|\Z)', body, re.DOTALL | re.IGNORECASE)
if not m:
    print("")
    sys.exit(0)
text = m.group(1).strip()
# strip checkbox lines themselves
text = re.sub(r'\[[ x]\].*', '', text, flags=re.IGNORECASE).strip().lstrip('-').strip()
# strip HTML comments
text = re.sub(r'<!--.*?-->', '', text, flags=re.DOTALL).strip()
print(text)
PY
)"

if [ -z "$APPROVAL_CONTENT" ]; then
  ERRORS+=("Human approval section contains no approval text — human must quote or reference their approval, not just check the box")
fi

if [ "${#ERRORS[@]}" -gt 0 ]; then
  echo "ERROR: final release is blocked on issue #${ISSUE_NUMBER} (${REPO}):" >&2
  for ERR in "${ERRORS[@]}"; do
    echo "  - $ERR" >&2
  done
  echo "" >&2
  echo "Release Manager must NOT publish the final release until these conditions are met." >&2
  echo "Silence and absence of objection are not approval." >&2
  exit 1
fi

echo "Final release approved: issue #${ISSUE_NUMBER} (${REPO}) has explicit human approval recorded."
