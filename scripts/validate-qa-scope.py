#!/usr/bin/env python3
"""
Validate that a QA review's scope findings are grounded in the actual PR
changed-file list and not in broader repo context files.

This script enforces the QA scope-grounding rule: a QA review must not
claim a file was "changed by this PR" unless that file appears in the
confirmed PR changed-file list.

Usage:
    scripts/validate-qa-scope.py <review-file> --pr-files <file1> [<file2> ...]
    scripts/validate-qa-scope.py <review-file> --pr-files-from <file>

Arguments:
    review-file          Path to the QA review markdown file.
    --pr-files           Space-separated list of files actually changed by the PR.
    --pr-files-from      Path to a file containing one PR-changed filename per line.

Exit codes:
    0  Scope grounding check passed.
    1  One or more scope-grounding violations found.
    2  Review is missing the required "Changed files reviewed" section.

Examples:
    scripts/validate-qa-scope.py qa-review.md --pr-files README.md app.js index.html
    scripts/validate-qa-scope.py qa-review.md --pr-files-from pr-changed-files.txt

The review file must contain a section that begins with one of:
    ## Changed files reviewed
    ## Files reviewed
    ## PR files

That section must list only files that appear in the --pr-files set.
Any file listed in that section that is NOT in the PR changed-file list
is a scope-grounding violation.

Additionally, if the review body mentions a file (by path or basename) in a
scope-drift or "not part of the PR" context outside the grounded section,
this script will warn — but only explicit section violations are errors.
"""

import argparse
import re
import sys
from pathlib import Path

# Headings that introduce the required changed-files section.
CHANGED_FILES_HEADING_RE = re.compile(
    r"^#{1,3}\s+(changed\s+files\s+reviewed|files\s+reviewed|pr\s+files)\s*$",
    re.IGNORECASE | re.MULTILINE,
)

# A file path listed in a markdown bullet or numbered list item.
# Matches things like:  - README.md  or  * src/app.js  or  1. docs/delivery/foo.md
LIST_FILE_RE = re.compile(r"^[\s*\-\d.]+`?([^\s`]+\.[a-zA-Z0-9_]+)`?\s*", re.MULTILINE)

# Scope-drift indicator phrases in the review body.
SCOPE_DRIFT_PHRASES = re.compile(
    r"(scope\s+drift|out\s+of\s+scope|not\s+part\s+of\s+(the\s+)?pr|"
    r"unrelated\s+(change|edit|file)|should\s+not\s+be\s+(in|part\s+of)\s+(this\s+)?pr)",
    re.IGNORECASE,
)


def extract_section(text: str, heading_re) -> tuple[str | None, str]:
    """Return (section_heading, section_body) or (None, '') if not found."""
    match = heading_re.search(text)
    if not match:
        return None, ""
    heading = match.group(0).strip()
    start = match.end()
    # Find the next heading at the same or higher level.
    next_heading = re.search(r"^#{1,3}\s+", text[start:], re.MULTILINE)
    end = start + next_heading.start() if next_heading else len(text)
    return heading, text[start:end].strip()


def extract_listed_files(section_body: str) -> list[str]:
    """Extract file paths listed as bullets in a section body."""
    files = []
    for match in LIST_FILE_RE.finditer(section_body):
        candidate = match.group(1).strip().strip("`")
        # Must look like a file path (contains a dot or a slash).
        if "." in candidate or "/" in candidate:
            files.append(candidate)
    return files


def basename(path: str) -> str:
    return path.split("/")[-1]


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate QA review scope grounding against the PR changed-file list."
    )
    parser.add_argument("review_file", help="QA review markdown file")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument(
        "--pr-files",
        nargs="+",
        metavar="FILE",
        help="Files actually changed by the PR",
    )
    group.add_argument(
        "--pr-files-from",
        metavar="FILE",
        help="File containing one PR-changed path per line",
    )
    args = parser.parse_args()

    review_path = Path(args.review_file)
    if not review_path.exists():
        print(f"ERROR: review file not found: {review_path}", file=sys.stderr)
        return 1

    if args.pr_files_from:
        pf_path = Path(args.pr_files_from)
        if not pf_path.exists():
            print(f"ERROR: pr-files-from file not found: {pf_path}", file=sys.stderr)
            return 1
        pr_files = [l.strip() for l in pf_path.read_text().splitlines() if l.strip()]
    else:
        pr_files = args.pr_files

    pr_file_set = set(pr_files)
    pr_basename_set = {basename(f) for f in pr_files}

    review_text = review_path.read_text(encoding="utf-8")

    heading, section_body = extract_section(review_text, CHANGED_FILES_HEADING_RE)

    errors = []
    warnings = []

    # ── Rule 1: section must exist ─────────────────────────────────────────────
    if heading is None:
        print(
            f"ERROR: {review_path}: missing required 'Changed files reviewed' section\n"
            f"  QA reviews must list the PR changed-file set explicitly before making scope findings.\n"
            f"  Add a section like:\n"
            f"  ## Changed files reviewed\n"
            f"  - README.md\n"
            f"  - app.js",
            file=sys.stderr,
        )
        return 2

    # ── Rule 2: section must not list files outside the PR diff ───────────────
    listed_files = extract_listed_files(section_body)
    if not listed_files:
        errors.append(
            f"'Changed files reviewed' section is empty or lists no files; "
            f"it must list the files actually changed by this PR"
        )

    for listed in listed_files:
        in_pr = (
            listed in pr_file_set
            or basename(listed) in pr_basename_set
            # Also accept if the listed path is a suffix of a PR file path.
            or any(pr.endswith(listed) or listed.endswith(pr) for pr in pr_files)
        )
        if not in_pr:
            errors.append(
                f"scope-grounding violation: '{listed}' appears in 'Changed files reviewed' "
                f"but is NOT in the PR changed-file list\n"
                f"  PR files: {', '.join(sorted(pr_file_set))}\n"
                f"  '{listed}' was likely read as project context, not changed by the PR"
            )

    # ── Rule 3: warn if scope-drift language appears near a non-PR file ───────
    # Find scope-drift phrases and check the surrounding context for file mentions.
    context_file_re = re.compile(r"`([^`]+\.[a-zA-Z0-9_]+)`")
    for phrase_match in SCOPE_DRIFT_PHRASES.finditer(review_text):
        context_start = max(0, phrase_match.start() - 200)
        context_end = min(len(review_text), phrase_match.end() + 200)
        context = review_text[context_start:context_end]
        for file_match in context_file_re.finditer(context):
            mentioned = file_match.group(1)
            in_pr = (
                mentioned in pr_file_set
                or basename(mentioned) in pr_basename_set
                or any(pr.endswith(mentioned) or mentioned.endswith(pr) for pr in pr_files)
            )
            if not in_pr:
                warnings.append(
                    f"scope-drift claim near non-PR file: '{mentioned}' mentioned near "
                    f"'{phrase_match.group(0).strip()}' — verify this is not a false positive"
                )

    # ── Output ────────────────────────────────────────────────────────────────
    for warning in warnings:
        print(f"WARNING: {review_path}: {warning}", file=sys.stderr)

    if errors:
        for error in errors:
            print(f"ERROR: {review_path}: {error}", file=sys.stderr)
        return 1

    print(
        f"QA scope grounding check passed: {review_path}\n"
        f"  PR files: {', '.join(sorted(pr_file_set))}\n"
        f"  QA listed: {', '.join(listed_files) if listed_files else '(none)'}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
