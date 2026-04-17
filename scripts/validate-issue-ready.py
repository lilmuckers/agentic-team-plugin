#!/usr/bin/env python3
"""
Validate whether a GitHub issue meets definition of ready for its type.

Type-aware checks:
  feature  — spec artifact required; acceptance criteria, test strategy, assumptions/links
  change   — same as feature; additionally requires current/desired behavior sections
  bug      — reported behavior, expected behavior, reproduction required; spec triage implied
  chore    — spec artifact NOT required; acceptance criteria and test strategy required
  spike    — different path: question, success/failure criteria; no spec artifact, no test strategy

Security-scope checks apply to any type carrying security-scope or security-review-required labels.

Exit 0 = ready.  Exit 1 = not ready (errors printed to stderr).
"""
import argparse
import json
import re
import subprocess
import sys

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
SECURITY_SCOPE_LABELS = {"security-scope", "security-review-required"}
SECTION_RE = re.compile(r"^##\s+(.+?)\s*$", re.MULTILINE)
ISSUE_REF_RE = re.compile(r"#(\d+)")
PLACEHOLDER_LINES = {"-", "*", "none", "n/a", "tbd", ""}

SPEC_ARTIFACT_RE = re.compile(
    r"(SPEC\.md|wiki/|docs/decisions/|architecture.decision|ADR-\d+)",
    re.IGNORECASE,
)


def run_gh(*args: str) -> str:
    result = subprocess.run(["gh", *args], capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or "gh command failed")
    return result.stdout


def extract_sections(body: str) -> dict:
    matches = list(SECTION_RE.finditer(body))
    sections = {}
    for index, match in enumerate(matches):
        name = match.group(1).strip().lower()
        start = match.end()
        end = matches[index + 1].start() if index + 1 < len(matches) else len(body)
        sections[name] = body[start:end].strip()
    return sections


def non_placeholder_lines(text: str) -> list:
    lines = []
    for raw in text.splitlines():
        line = raw.strip().strip("[]")
        normalized = re.sub(r"^- \[[ xX]\]\s*", "", line).strip().lower()
        normalized = re.sub(r"^[-*]\s*", "", normalized).strip()
        if not normalized or normalized in PLACEHOLDER_LINES:
            continue
        lines.append(raw.strip())
    return lines


def issue_is_open(issue_number: str, repo: str | None) -> bool:
    args = ["issue", "view", issue_number, "--json", "state"]
    if repo:
        args.extend(["--repo", repo])
    payload = json.loads(run_gh(*args))
    return payload["state"].upper() == "OPEN"


def check_common(labels: set, sections: dict, body: str, issue_type: str) -> list:
    """Checks that apply to all types."""
    errors = []

    if not labels.intersection(ROUTING_LABELS):
        errors.append(
            "missing routing/workflow label (expected one of: " + ", ".join(sorted(ROUTING_LABELS)) + ")"
        )

    # Spikes use a separate routing path — ready-for-build is not applicable
    if issue_type != "spike" and "ready-for-build" not in labels:
        errors.append(
            "missing 'ready-for-build' label — "
            "Spec must apply this label and Orchestrator must verify before dispatch"
        )

    if "needs-clarification" in labels:
        errors.append("issue carries 'needs-clarification' — resolve before routing to build")

    if "blocked" in labels:
        errors.append("issue carries 'blocked' — resolve the blocker before routing to build")

    return errors


def check_feature_or_change(labels: set, sections: dict, body: str, issue_type: str) -> list:
    errors = []

    acceptance = sections.get("acceptance criteria", "")
    if not non_placeholder_lines(acceptance):
        errors.append("missing non-empty '## Acceptance Criteria'")

    test_strategy = sections.get("test strategy", "")
    if not non_placeholder_lines(test_strategy):
        errors.append("missing non-empty '## Test Strategy'")

    if not SPEC_ARTIFACT_RE.search(body):
        errors.append(
            "issue does not reference a spec artifact (SPEC.md, wiki page, or architecture decision); "
            "Builder cannot start without a cited spec — route back to Spec"
        )

    assumptions = sections.get("assumptions", "")
    links = sections.get("links", "")
    if not non_placeholder_lines(assumptions) and not non_placeholder_lines(links):
        errors.append("missing documented assumptions or linked docs/context")

    if issue_type == "change":
        if not non_placeholder_lines(sections.get("current behavior", "")):
            errors.append(
                "change issue is missing non-empty '## Current Behavior' — "
                "document what it does now before specifying what it should do instead"
            )
        if not non_placeholder_lines(sections.get("desired behavior", "")):
            errors.append(
                "change issue is missing non-empty '## Desired Behavior' — "
                "the 'what' must be already decided for a change; if not, reclassify as feature"
            )

    # User-facing sections: all three must be present together or none
    has_user_flows = bool(non_placeholder_lines(sections.get("user flows", "")))
    has_usability = bool(non_placeholder_lines(sections.get("usability requirements", "")))
    has_design = bool(non_placeholder_lines(sections.get("design direction", "")))
    if any([has_user_flows, has_usability, has_design]):
        if not has_user_flows:
            errors.append("user-facing issue is missing non-empty '## User Flows'")
        if not has_usability:
            errors.append("user-facing issue is missing non-empty '## Usability Requirements'")

    return errors


def check_bug(labels: set, sections: dict, body: str) -> list:
    errors = []

    if not non_placeholder_lines(sections.get("reported behavior", "")):
        errors.append("bug issue is missing non-empty '## Reported Behavior'")

    if not non_placeholder_lines(sections.get("expected behavior", "")):
        errors.append("bug issue is missing non-empty '## Expected Behavior'")

    reproduction = sections.get("reproduction", "")
    repro_lines = non_placeholder_lines(reproduction)
    if len(repro_lines) < 2:
        errors.append(
            "bug issue '## Reproduction' must contain at least two non-placeholder steps"
        )

    acceptance = sections.get("acceptance criteria", "")
    if not non_placeholder_lines(acceptance):
        errors.append("missing non-empty '## Acceptance Criteria'")

    test_strategy = sections.get("test strategy", "")
    if not non_placeholder_lines(test_strategy):
        errors.append(
            "missing non-empty '## Test Strategy' — "
            "must specify regression coverage expectation or document why automation is impossible"
        )

    if not SPEC_ARTIFACT_RE.search(body):
        errors.append(
            "bug issue does not reference a spec artifact — "
            "Spec must confirm this is an accepted in-scope bug against current spec before build"
        )

    return errors


def check_chore(labels: set, sections: dict, body: str) -> list:
    errors = []

    acceptance = sections.get("acceptance criteria", "")
    if not non_placeholder_lines(acceptance):
        errors.append("missing non-empty '## Acceptance Criteria'")

    test_strategy = sections.get("test strategy", "")
    if not non_placeholder_lines(test_strategy):
        errors.append(
            "missing non-empty '## Test Strategy' — "
            "at minimum: 'CI passes; no regressions in existing tests'"
        )

    # Spec artifact NOT required for chores, but context should still exist
    assumptions = sections.get("assumptions", "")
    links = sections.get("links", "")
    summary = sections.get("summary", "")
    if (
        not non_placeholder_lines(assumptions)
        and not non_placeholder_lines(links)
        and not non_placeholder_lines(summary)
    ):
        errors.append(
            "chore issue has no summary, assumptions, or links — "
            "provide enough context for Builder to understand the goal"
        )

    return errors


def check_spike(labels: set, sections: dict, body: str) -> list:
    errors = []

    question = sections.get("question", "")
    if not non_placeholder_lines(question):
        errors.append(
            "spike issue is missing non-empty '## Question' — "
            "a spike must have a single bounded question"
        )

    success = sections.get("success criteria", "")
    if not non_placeholder_lines(success):
        errors.append("spike issue is missing non-empty '## Success Criteria'")

    failure = sections.get("failure criteria", "")
    if not non_placeholder_lines(failure):
        errors.append("spike issue is missing non-empty '## Failure Criteria'")

    output = sections.get("expected output", "")
    if not non_placeholder_lines(output):
        errors.append(
            "spike issue is missing non-empty '## Expected Output' — "
            "define what the spike report must contain"
        )

    # Spikes must NOT carry ready-for-build
    if "ready-for-build" in labels:
        errors.append(
            "spike issue must not carry 'ready-for-build' — "
            "spikes use a different dispatch path; remove this label"
        )

    return errors


def check_security_scope(sections: dict) -> list:
    errors = []

    if not non_placeholder_lines(sections.get("security requirements", "")):
        errors.append(
            "security-scope issue is missing non-empty '## Security Requirements' — "
            "Security must define requirements before build handoff"
        )

    threat_model = sections.get("threat model", "")
    if not non_placeholder_lines(threat_model):
        errors.append(
            "security-scope issue is missing non-empty '## Threat Model' — "
            "Security must document trust boundaries and mitigations"
        )

    return errors


def check_blockers(sections: dict, repo: str | None) -> list:
    errors = []
    blockers_text = sections.get(
        "dependencies / blockers",
        sections.get("dependencies", sections.get("blockers", "")),
    )
    blocker_refs = sorted(set(ISSUE_REF_RE.findall(blockers_text)))

    open_blockers = []
    for ref in blocker_refs:
        try:
            if issue_is_open(ref, repo):
                open_blockers.append(f"#{ref}")
        except RuntimeError as exc:
            errors.append(f"unable to inspect blocker issue #{ref}: {exc}")

    if open_blockers:
        errors.append("open blocking issues referenced: " + ", ".join(open_blockers))

    non_ref_blocker_lines = [
        line for line in non_placeholder_lines(blockers_text)
        if not ISSUE_REF_RE.search(line)
    ]
    if non_ref_blocker_lines:
        errors.append(
            "dependencies/blockers section contains unresolved text — "
            "resolve or reference with a linked issue number"
        )

    return errors


def main():
    parser = argparse.ArgumentParser(
        description="Validate whether a GitHub issue is ready for build (type-aware)."
    )
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

    type_labels = labels.intersection(ISSUE_TYPE_LABELS)
    if not type_labels:
        errors.append(
            "missing issue-type label (expected exactly one of: " + ", ".join(sorted(ISSUE_TYPE_LABELS)) + ")"
        )
        issue_type = None
    elif len(type_labels) > 1:
        errors.append(
            f"multiple issue-type labels present ({sorted(type_labels)!r}) — exactly one allowed"
        )
        issue_type = sorted(type_labels)[0]  # pick one to continue checks
    else:
        issue_type = next(iter(type_labels))

    if issue_type:
        errors.extend(check_common(labels, sections, body, issue_type))

        if issue_type in ("feature", "change"):
            errors.extend(check_feature_or_change(labels, sections, body, issue_type))
        elif issue_type == "bug":
            errors.extend(check_bug(labels, sections, body))
        elif issue_type == "chore":
            errors.extend(check_chore(labels, sections, body))
        elif issue_type == "spike":
            errors.extend(check_spike(labels, sections, body))

        if labels.intersection(SECURITY_SCOPE_LABELS):
            errors.extend(check_security_scope(sections))

        errors.extend(check_blockers(sections, args.repo))

    if errors:
        print(
            f"Issue {issue['number']} is NOT ready for build "
            f"[type: {issue_type or 'unknown'}]: {issue['title']}",
            file=sys.stderr,
        )
        print(issue["url"], file=sys.stderr)
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print(
        f"Issue {issue['number']} is ready for build "
        f"[type: {issue_type}]: {issue['title']}"
    )
    print(issue["url"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
