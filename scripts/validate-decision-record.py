#!/usr/bin/env python3
import argparse
import re
import sys
from pathlib import Path

REQUIRED_SECTIONS = [
    "Date",
    "Decision",
    "Rationale",
    "Alternatives Rejected",
    "Constraints Applied",
    "Source Pointers",
]
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
SECTION_RE = re.compile(r"^##\s+(.+?)\s*$", re.MULTILINE)
HEADER_RE = re.compile(r"^#\s+Decision Record:\s+(.+?)\s*$", re.MULTILINE)


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


def non_empty_bullets(body: str):
    items = []
    for line in body.splitlines():
        stripped = line.strip()
        if stripped.startswith("- ") and stripped[2:].strip():
            items.append(stripped[2:].strip())
    return items


def main():
    parser = argparse.ArgumentParser(description="Validate a markdown decision record.")
    parser.add_argument("decision_record_file")
    args = parser.parse_args()

    path = Path(args.decision_record_file)
    if not path.exists():
        print(f"ERROR: file not found: {path}", file=sys.stderr)
        return 1

    text = path.read_text(encoding="utf-8")
    errors = []

    header = HEADER_RE.search(text)
    if not header or not header.group(1).strip():
        errors.append("missing '# Decision Record: <id>' header")

    sections = extract_sections(text)
    names = [name for name, _ in sections]
    if names != REQUIRED_SECTIONS:
        errors.append("required sections must appear exactly once and in order: " + ", ".join(REQUIRED_SECTIONS))

    section_map = {name: body for name, body in sections}

    date_body = section_map.get("Date", "").strip()
    if not DATE_RE.match(date_body):
        errors.append("'## Date' must contain a YYYY-MM-DD value")

    for name in ["Decision", "Rationale"]:
        if not section_map.get(name, "").strip():
            errors.append(f"section '## {name}' must not be empty")

    for name in ["Alternatives Rejected", "Constraints Applied", "Source Pointers"]:
        items = non_empty_bullets(section_map.get(name, ""))
        if not items:
            errors.append(f"section '## {name}' must contain at least one bullet item")

    if errors:
        for error in errors:
            print(f"ERROR: {path}: {error}", file=sys.stderr)
        return 1

    print(f"Decision record validation passed: {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
