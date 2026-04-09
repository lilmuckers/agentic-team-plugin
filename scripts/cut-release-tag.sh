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
  scripts/cut-release-tag.sh <owner/repo> <version> <beta|rc|final> [notes-file] [--dry-run]

Examples:
  scripts/cut-release-tag.sh owner/repo v0.2.0 beta notes.md
  scripts/cut-release-tag.sh owner/repo v0.2.0 final notes.md
EOF
  exit 1
fi

REPO="$1"
VERSION="$2"
STAGE="$3"
NOTES_FILE="${4:-}"
DRY_RUN=0
if [ "${NOTES_FILE:-}" = "--dry-run" ]; then
  NOTES_FILE=""
  DRY_RUN=1
fi
if [ "${5:-}" = "--dry-run" ]; then
  DRY_RUN=1
fi

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
