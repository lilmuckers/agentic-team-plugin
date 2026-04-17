#!/usr/bin/env python3
"""
Validate that a GitHub release tracking issue has a legal trigger and the
required fields filled in before Release Manager is dispatched.

Checks:
  - Issue exists and is open
  - Exactly one trigger-source checkbox is checked
  - The checked trigger is one of the two allowed values
  - Scope basis is non-empty
  - Proposed version is present and looks like semver (digits.digits.digits)
  - Proposed version scale has at least one box checked

Exit 0 = valid.  Exit 1 = invalid (errors printed to stderr).

Usage:
  scripts/validate-release-request.py <issue-number> --repo <owner/repo>
"""
import argparse
import json
import re
import subprocess
import sys

ALLOWED_TRIGGERS = {
    "human explicit instruction",
    "orchestrator (pre-agreed condition met, basis recorded above)",
}

SEMVER_RE = re.compile(r"^\d+\.\d+\.\d+")


def gh_issue(repo: str, number: int) -> dict:
    result = subprocess.run(
        ["gh", "api", f"repos/{repo}/issues/{number}"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        print(f"ERROR: could not fetch issue #{number} from {repo}", file=sys.stderr)
        print(result.stderr.strip(), file=sys.stderr)
        sys.exit(1)
    return json.loads(result.stdout)


def checked_boxes(section_text: str) -> list[str]:
    """Return list of labels for checked checkboxes in a markdown section."""
    return re.findall(r"\[x\]\s*(.+)", section_text, re.IGNORECASE)


def section_body(text: str, heading: str) -> str:
    """Extract the text under a given ## heading until the next ## heading."""
    pattern = rf"##\s+{re.escape(heading)}\s*\n(.*?)(?=\n##\s|\Z)"
    m = re.search(pattern, text, re.DOTALL | re.IGNORECASE)
    return m.group(1).strip() if m else ""


def validate(body: str, issue_number: int, repo: str) -> list[str]:
    errors = []

    # ── trigger source ────────────────────────────────────────────────────────
    trigger_section = section_body(body, "Trigger source")
    checked = checked_boxes(trigger_section)
    if not checked:
        errors.append(
            "no trigger-source checkbox is checked — "
            "one of the two allowed triggers must be selected"
        )
    elif len(checked) > 1:
        errors.append(
            f"multiple trigger-source checkboxes checked ({checked!r}) — "
            "only one trigger is allowed"
        )
    else:
        label = checked[0].strip().lower()
        if label not in ALLOWED_TRIGGERS:
            errors.append(
                f"trigger-source checkbox value {checked[0]!r} is not a valid trigger; "
                f"allowed: {sorted(ALLOWED_TRIGGERS)}"
            )

    # ── trigger narrative must be non-placeholder ─────────────────────────────
    trigger_text = section_body(body, "Trigger")
    if not trigger_text or trigger_text.startswith("<!--") or trigger_text == "-":
        errors.append(
            "## Trigger body is empty or still a placeholder — "
            "record the human instruction or pre-agreed condition basis"
        )

    # ── proposed version ─────────────────────────────────────────────────────
    version_text = section_body(body, "Proposed version")
    # strip placeholder markers
    version_clean = re.sub(r"<!--.*?-->", "", version_text, flags=re.DOTALL).strip().lstrip("-").strip()
    if not version_clean:
        errors.append("## Proposed version is empty — provide a semver string, e.g. 0.2.0")
    elif not SEMVER_RE.match(version_clean):
        errors.append(
            f"## Proposed version {version_clean!r} does not look like semver "
            "(expected digits.digits.digits)"
        )

    # ── version scale ─────────────────────────────────────────────────────────
    scale_section = section_body(body, "Version scale")
    scale_checked = checked_boxes(scale_section)
    if not scale_checked:
        errors.append(
            "## Version scale has no checkbox checked — "
            "Orchestrator must confirm major/minor/patch before dispatching Release Manager"
        )

    # ── scope basis ───────────────────────────────────────────────────────────
    scope_text = section_body(body, "Scope basis")
    scope_clean = re.sub(r"<!--.*?-->", "", scope_text, flags=re.DOTALL).strip().lstrip("-").strip()
    if not scope_clean:
        errors.append(
            "## Scope basis is empty — record what merged work this release covers"
        )

    return errors


def main():
    parser = argparse.ArgumentParser(
        description="Validate a release tracking issue before dispatching Release Manager."
    )
    parser.add_argument("issue_number", type=int)
    parser.add_argument("--repo", required=True, help="owner/repo")
    args = parser.parse_args()

    issue = gh_issue(args.repo, args.issue_number)

    if issue.get("state") != "open":
        print(
            f"ERROR: release tracking issue #{args.issue_number} is not open "
            f"(state: {issue.get('state')!r})",
            file=sys.stderr,
        )
        sys.exit(1)

    body = issue.get("body") or ""
    errors = validate(body, args.issue_number, args.repo)

    if errors:
        print(
            f"ERROR: release tracking issue #{args.issue_number} ({args.repo}) "
            "is not valid for release dispatch:",
            file=sys.stderr,
        )
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        sys.exit(1)

    print(
        f"Release request valid: issue #{args.issue_number} ({args.repo}) "
        "has a legal trigger, version, scale, and scope basis."
    )


if __name__ == "__main__":
    main()
