#!/usr/bin/env python3
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

ISSUE_TYPE_LABELS = {"feature", "bug", "change", "chore", "spike"}
ROUTING_LABELS = {
    "spec-needed",
    "architecture-needed",
    "ready-for-build",
    "in-build",
    "in-review",
    "needs-clarification",
    "blocked",
}
SECTION_RE = re.compile(r"^##\s+(.+?)\s*$", re.MULTILINE)
ISSUE_REF_RE = re.compile(r"#(\d+)")
PLACEHOLDER_LINES = {"-", "*", "none", "n/a", "tbd"}


def run_gh(*args: str) -> str:
    result = subprocess.run(["gh", *args], capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or "gh command failed")
    return result.stdout


def extract_sections(body: str):
    matches = list(SECTION_RE.finditer(body))
    sections = {}
    for index, match in enumerate(matches):
        name = match.group(1).strip().lower()
        start = match.end()
        end = matches[index + 1].start() if index + 1 < len(matches) else len(body)
        sections[name] = body[start:end].strip()
    return sections


def non_placeholder_lines(text: str):
    lines = []
    for raw in text.splitlines():
        line = raw.strip().strip("[]")
        normalized = re.sub(r"^- \[[ xX]\]\s*", "", line).strip().lower()
        normalized = re.sub(r"^[-*]\s*", "", normalized).strip()
        if not normalized:
            continue
        if normalized in PLACEHOLDER_LINES:
            continue
        lines.append(raw.strip())
    return lines


def issue_is_open(issue_number: str, repo: str | None):
    args = ["issue", "view", issue_number, "--json", "state"]
    if repo:
        args.extend(["--repo", repo])
    payload = json.loads(run_gh(*args))
    return payload["state"].upper() == "OPEN"


def main():
    parser = argparse.ArgumentParser(description="Validate whether a GitHub issue is ready for build.")
    parser.add_argument("issue_number")
    parser.add_argument("--repo", help="owner/repo; defaults to current gh repo context")
    args = parser.parse_args()

    try:
        gh_args = ["issue", "view", args.issue_number, "--json", "number,title,url,state,body,labels"]
        if args.repo:
            gh_args.extend(["--repo", args.repo])
        issue = json.loads(run_gh(*gh_args))
    except RuntimeError as exc:
        print(f"ERROR: unable to read issue {args.issue_number}: {exc}", file=sys.stderr)
        return 1

    errors = []
    labels = {label["name"] for label in issue.get("labels", [])}
    body = issue.get("body") or ""
    sections = extract_sections(body)

    if issue.get("state", "").upper() != "OPEN":
        errors.append("issue is not open")

    if not labels.intersection(ISSUE_TYPE_LABELS):
        errors.append(
            "missing high-level issue-type label (expected one of: " + ", ".join(sorted(ISSUE_TYPE_LABELS)) + ")"
        )

    if not labels.intersection(ROUTING_LABELS):
        errors.append(
            "missing routing/workflow label (expected one of: " + ", ".join(sorted(ROUTING_LABELS)) + ")"
        )

    acceptance = sections.get("acceptance criteria", "")
    if not non_placeholder_lines(acceptance):
        errors.append("missing non-empty '## Acceptance Criteria' section")

    assumptions = sections.get("assumptions", "")
    links = sections.get("links", "")
    has_assumptions = bool(non_placeholder_lines(assumptions))
    has_linked_docs = bool(non_placeholder_lines(links))
    if not has_assumptions and not has_linked_docs:
        errors.append("missing documented assumptions or linked docs/context")

    blockers = sections.get("dependencies / blockers", sections.get("dependencies", sections.get("blockers", "")))
    blocker_lines = non_placeholder_lines(blockers)
    blocker_refs = sorted(set(ISSUE_REF_RE.findall(blockers)))
    open_blockers = []
    for ref in blocker_refs:
        try:
            if issue_is_open(ref, args.repo):
                open_blockers.append(f"#{ref}")
        except RuntimeError as exc:
            errors.append(f"unable to inspect blocker issue #{ref}: {exc}")

    if open_blockers:
        errors.append("open blocking issues referenced: " + ", ".join(open_blockers))

    unresolved_blocker_lines = [line for line in blocker_lines if not ISSUE_REF_RE.search(line)]
    if unresolved_blocker_lines:
        errors.append("dependencies/blockers section is not empty")

    if errors:
        print(f"Issue {issue['number']} is NOT ready for build: {issue['title']}", file=sys.stderr)
        print(issue["url"], file=sys.stderr)
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print(f"Issue {issue['number']} is ready for build: {issue['title']}")
    print(issue["url"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
