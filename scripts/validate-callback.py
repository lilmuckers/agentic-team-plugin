#!/usr/bin/env python3
import argparse
import re
import sys
from pathlib import Path

REQUIRED_SECTIONS = [
    "Task",
    "Agent",
    "Outcome",
    "Changed",
    "Artifacts",
    "Tests",
    "Blockers",
    "Next Action",
]
VALID_OUTCOMES = {"DONE", "BLOCKED", "FAILED", "NEEDS_REVIEW"}
SECTION_RE = re.compile(r"^##\s+(.+?)\s*$", re.MULTILINE)


def extract_sections(text: str):
    matches = list(SECTION_RE.finditer(text))
    sections = []
    for index, match in enumerate(matches):
        name = match.group(1).strip()
        start = match.end()
        end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        body = text[start:end].strip()
        sections.append((name, body))
    return sections


def validate_callback(path: Path):
    text = path.read_text(encoding="utf-8")
    sections = extract_sections(text)
    errors = []

    names = [name for name, _ in sections]
    if names != REQUIRED_SECTIONS:
        errors.append(
            "required sections must appear exactly once and in order: " + ", ".join(REQUIRED_SECTIONS)
        )

    counts = {name: names.count(name) for name in set(names)}
    for required in REQUIRED_SECTIONS:
        if counts.get(required, 0) != 1:
            errors.append(f"section '## {required}' must appear exactly once")

    section_map = {name: body for name, body in sections}
    outcome = section_map.get("Outcome", "").strip()
    if outcome and outcome not in VALID_OUTCOMES:
        errors.append(
            "section '## Outcome' must be exactly one of: " + ", ".join(sorted(VALID_OUTCOMES))
        )

    for name in ["Changed", "Artifacts", "Tests", "Blockers", "Next Action"]:
        body = section_map.get(name, "").strip()
        if not body:
            errors.append(f"section '## {name}' must not be empty")

    for name in ["Task", "Agent", "Outcome"]:
        body = section_map.get(name, "").strip()
        if not body:
            errors.append(f"section '## {name}' must not be empty")

    return errors


def main():
    parser = argparse.ArgumentParser(description="Validate callback markdown against the callback schema.")
    parser.add_argument("callback_file")
    args = parser.parse_args()

    path = Path(args.callback_file)
    if not path.exists():
        print(f"ERROR: file not found: {path}", file=sys.stderr)
        return 1

    errors = validate_callback(path)
    if errors:
        for error in errors:
            print(f"ERROR: {path}: {error}", file=sys.stderr)
        return 1

    print(f"Callback validation passed: {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
