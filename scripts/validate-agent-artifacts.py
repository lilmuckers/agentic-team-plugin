#!/usr/bin/env python3
import argparse
import re
import sys
from pathlib import Path

HEADER_RE = re.compile(r'^> _posted by \*\*([A-Za-z0-9 /_-]+)\*\*_\s*$', re.MULTILINE)
SEMANTIC_COMMIT_RE = re.compile(r'^(feat|fix|docs|test|chore|refactor|perf|build|ci|style|revert)(\([^)]+\))?: .+')
GIT_EMAIL_RE = re.compile(r'^bot-[a-z0-9-]+@patrick-mckinley\.com$')
GIT_NAME_RE = re.compile(r'^.+ \([A-Za-z0-9 /_-]+\)$')


def fail(msg: str):
    print(f"ERROR: {msg}", file=sys.stderr)
    return 1


def validate_markdown_file(path: Path, require_header: bool):
    text = path.read_text()
    errors = []
    if require_header and not HEADER_RE.search(text):
        errors.append("missing agent attribution header")
    if "```" in text and text.count("```") % 2 != 0:
        errors.append("unbalanced fenced code blocks")
    if not text.strip():
        errors.append("empty markdown body")
    return errors


def main():
    parser = argparse.ArgumentParser(description="Validate standardized agent artifacts.")
    parser.add_argument("--comment-file")
    parser.add_argument("--pr-body-file")
    parser.add_argument("--wiki-file")
    parser.add_argument("--callback-file")
    parser.add_argument("--decision-record-file")
    parser.add_argument("--commit-subject")
    parser.add_argument("--git-name")
    parser.add_argument("--git-email")
    parser.add_argument("--pr-label", action="append", default=[])
    parser.add_argument("--regression-test-path", action="append", default=[])
    parser.add_argument("--accepted-regression-exception", action="store_true")
    args = parser.parse_args()

    had_error = False

    for attr, require_header in [("comment_file", True), ("pr_body_file", True), ("wiki_file", True), ("callback_file", False), ("decision_record_file", False)]:
        value = getattr(args, attr)
        if value:
            path = Path(value)
            if not path.exists():
                print(f"ERROR: file not found: {path}", file=sys.stderr)
                had_error = True
                continue
            errors = validate_markdown_file(path, require_header=require_header)
            for err in errors:
                print(f"ERROR: {path}: {err}", file=sys.stderr)
                had_error = True

    if args.commit_subject and not SEMANTIC_COMMIT_RE.match(args.commit_subject):
        print("ERROR: commit subject is not semantic-commit formatted", file=sys.stderr)
        had_error = True

    if args.git_name and not GIT_NAME_RE.match(args.git_name):
        print("ERROR: git name does not match '<Name> (<Archetype>)' format", file=sys.stderr)
        had_error = True

    if args.git_email and not GIT_EMAIL_RE.match(args.git_email):
        print("ERROR: git email does not match 'bot-<archetype-slug>@patrick-mckinley.com' format", file=sys.stderr)
        had_error = True

    if "type:bug-fix" in args.pr_label:
        if not args.regression_test_path and not args.accepted_regression_exception:
            print(
                "ERROR: bug-fix PR requires at least one --regression-test-path or --accepted-regression-exception",
                file=sys.stderr,
            )
            had_error = True
        for regression_path in args.regression_test_path:
            path = Path(regression_path)
            if not path.exists():
                print(f"ERROR: regression test path not found: {path}", file=sys.stderr)
                had_error = True

    if had_error:
        return 1

    print("Validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
