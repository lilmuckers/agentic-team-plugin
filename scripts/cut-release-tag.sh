#!/usr/bin/env bash
set -euo pipefail

if ! command -v git >/dev/null 2>&1; then
  echo "git is required" >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required" >&2
  exit 1
fi

if [ $# -lt 3 ]; then
  cat >&2 <<'EOF'
Usage:
  scripts/cut-release-tag.sh <owner/repo> <version> <beta|rc|final> [notes-file] [--dry-run] [--release-issue <number>]

Options:
  --release-issue <number>   Required for final stage. Release tracking issue
                             number; human approval is verified before tagging.

Examples:
  scripts/cut-release-tag.sh owner/repo v0.2.0 beta notes.md
  scripts/cut-release-tag.sh owner/repo v0.2.0 final notes.md --release-issue 42
EOF
  exit 1
fi

REPO="$1"
VERSION="$2"
STAGE="$3"
shift 3

NOTES_FILE=""
DRY_RUN=0
RELEASE_ISSUE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)       DRY_RUN=1 ;;
    --release-issue) shift; RELEASE_ISSUE="$1" ;;
    *)
      if [ -z "$NOTES_FILE" ] && [ "${1:0:2}" != "--" ]; then
        NOTES_FILE="$1"
      else
        echo "ERROR: unexpected argument: $1" >&2
        exit 1
      fi
      ;;
  esac
  shift
done

if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9]+)?$ ]]; then
  echo "Version must look like v<major>.<minor>.<patch>" >&2
  exit 1
fi

case "$STAGE" in
  beta)
    TAG="${VERSION}-beta"
    PRERELEASE=1
    ;;
  rc)
    TAG="${VERSION}-rc"
    PRERELEASE=1
    ;;
  final)
    TAG="$VERSION"
    PRERELEASE=0
    ;;
  *)
    echo "Stage must be one of: beta, rc, final" >&2
    exit 1
    ;;
esac

# ── Gate: final release requires explicit human approval ──────────────────────
if [ "$STAGE" = "final" ]; then
  if [ -z "$RELEASE_ISSUE" ]; then
    echo "ERROR: --release-issue is required for final release." >&2
    echo "  Provide the release tracking issue number so human approval can be verified." >&2
    echo "  Example: scripts/cut-release-tag.sh $REPO $VERSION final notes.md --release-issue 42" >&2
    exit 1
  fi

  ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
  echo "Checking human approval on release tracking issue #${RELEASE_ISSUE} (${REPO})..."
  if ! "$ROOT_DIR/scripts/guard-final-release.sh" "$RELEASE_ISSUE" "$REPO"; then
    cat >&2 <<EOF

RELEASE BLOCKED: final release cannot be published without explicit human approval.

Release Manager must:
  1. Post an approval request on issue #${RELEASE_ISSUE}
  2. Wait for the human to explicitly approve (not silence, not no-objection)
  3. Ensure the 'Human approved' checkbox is checked on the issue
  4. Retry this script once approval is recorded

Do not proceed.
EOF
    exit 1
  fi
fi

if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "Tag already exists locally: $TAG" >&2
  exit 1
fi

if [ -n "$NOTES_FILE" ] && [ ! -f "$NOTES_FILE" ]; then
  echo "Notes file not found: $NOTES_FILE" >&2
  exit 1
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "DRY RUN: git tag -a $TAG -m Release $TAG"
  if [ -n "$NOTES_FILE" ]; then
    if [ "$PRERELEASE" -eq 1 ]; then
      echo "DRY RUN: gh release create $TAG --repo $REPO --title $TAG --notes-file $NOTES_FILE --prerelease"
    else
      echo "DRY RUN: gh release create $TAG --repo $REPO --title $TAG --notes-file $NOTES_FILE"
    fi
  else
    if [ "$PRERELEASE" -eq 1 ]; then
      echo "DRY RUN: gh release create $TAG --repo $REPO --title $TAG --generate-notes --prerelease"
    else
      echo "DRY RUN: gh release create $TAG --repo $REPO --title $TAG --generate-notes"
    fi
  fi
  exit 0
fi

git tag -a "$TAG" -m "Release $TAG"
git push origin "$TAG"

ARGS=(release create "$TAG" --repo "$REPO" --title "$TAG")
if [ -n "$NOTES_FILE" ]; then
  ARGS+=(--notes-file "$NOTES_FILE")
else
  ARGS+=(--generate-notes)
fi
if [ "$PRERELEASE" -eq 1 ]; then
  ARGS+=(--prerelease)
fi

gh "${ARGS[@]}"

echo "Created release tag and GitHub release: $TAG"
