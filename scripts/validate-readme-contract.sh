#!/usr/bin/env bash
set -euo pipefail

REPO_PATH="${1:-.}"
README="$REPO_PATH/README.md"

if [ ! -f "$README" ]; then
  echo "ERROR: README.md not found in $REPO_PATH" >&2
  exit 1
fi

extract_section_body() {
  local heading="$1"
  awk -v h="$heading" '
    BEGIN { in_section=0 }
    $0 ~ "^## " h "$" { in_section=1; next }
    in_section && $0 ~ "^## " { exit }
    in_section { print }
  ' "$README"
}

build_body="$(extract_section_body "Build")"
verify_body="$(extract_section_body "Verify")"
run_body="$(extract_section_body "Run")"
alt_body="$(extract_section_body "Executable Verification Path")"

if [ -z "$(printf '%s' "$build_body" | tr -d '[:space:]')" ]; then
  echo "ERROR: README.md must contain a non-empty '## Build' section" >&2
  exit 1
fi

if [ -z "$(printf '%s' "$verify_body" | tr -d '[:space:]')" ]; then
  echo "ERROR: README.md must contain a non-empty '## Verify' section" >&2
  exit 1
fi

if [ -z "$(printf '%s' "$run_body" | tr -d '[:space:]')" ] && [ -z "$(printf '%s' "$alt_body" | tr -d '[:space:]')" ]; then
  echo "ERROR: README.md must contain either a non-empty '## Run' section or a non-empty '## Executable Verification Path' section" >&2
  exit 1
fi

echo "README contract validation passed: $README"
