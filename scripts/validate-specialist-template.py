#!/usr/bin/env python3
import argparse
import re
import sys
from pathlib import Path

REQUIRED_SECTIONS = [
    "Base Identity",
    "Refinement Prompts",
    "Authority Boundaries",
    "Expected Output",
]
HEADER_RE = re.compile(r"^#\s+Specialist:\s+(.+?)\s*$", re.MULTILINE)
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


def has_list_items(body: str):
    for line in body.splitlines():
        stripped = line.strip()
        if stripped.startswith("- ") or re.match(r"^\d+\.\s+", stripped):
            return True
    return False


def main():
    parser = argparse.ArgumentParser(description="Validate a specialist template markdown file.")
    parser.add_argument("template_file")
    args = parser.parse_args()

    path = Path(args.template_file)
    if not path.exists():
        print(f"ERROR: file not found: {path}", file=sys.stderr)
        return 1

    text = path.read_text(encoding="utf-8")
    errors = []

    if not HEADER_RE.search(text):
        errors.append("missing '# Specialist: <name>' header")

    sections = extract_sections(text)
    names = [name for name, _ in sections]
    if names != REQUIRED_SECTIONS:
        errors.append("required sections must appear exactly once and in order: " + ", ".join(REQUIRED_SECTIONS))

    section_map = {name: body for name, body in sections}
    for name in REQUIRED_SECTIONS:
        if not section_map.get(name, "").strip():
            errors.append(f"section '## {name}' must not be empty")

    if section_map.get("Refinement Prompts") and not has_list_items(section_map["Refinement Prompts"]):
        errors.append("section '## Refinement Prompts' must contain at least one bullet or numbered item")

    if errors:
        for error in errors:
            print(f"ERROR: {path}: {error}", file=sys.stderr)
        return 1

    print(f"Specialist template validation passed: {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
