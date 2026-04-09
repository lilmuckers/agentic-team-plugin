#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
NOTES_FILE="${2:-$ROOT_DIR/FRAMEWORK_NOTES.md}"
DEPLOYED_SHA_FILE="$ROOT_DIR/.state/framework/deployed-sha.txt"

if [ ! -f "$NOTES_FILE" ]; then
  echo "ERROR: FRAMEWORK_NOTES.md not found: $NOTES_FILE" >&2
  exit 1
fi

if [ ! -f "$DEPLOYED_SHA_FILE" ]; then
  echo "ERROR: deployed sha file not found: $DEPLOYED_SHA_FILE" >&2
  exit 1
fi

loaded_sha="$(sed -n 's/^- loadedSha: //p' "$NOTES_FILE" | head -n1)"
if [ -z "$loaded_sha" ]; then
  loaded_sha="$(sed -n 's/^- deployedSha: //p' "$NOTES_FILE" | head -n1)"
fi
if [ -z "$loaded_sha" ]; then
  echo "ERROR: could not determine loaded sha from $NOTES_FILE" >&2
  exit 1
fi

current_sha="$(awk '{print $1}' "$DEPLOYED_SHA_FILE")"

if [ "$loaded_sha" = "$current_sha" ]; then
  echo "Framework SHA matches: $current_sha"
  exit 0
fi

echo "STALE_SESSION"
echo "loadedSha=$loaded_sha"
echo "currentSha=$current_sha"

git -C "$ROOT_DIR" diff --name-only "$loaded_sha" "$current_sha" -- agents policies skills 2>/dev/null || true
