#!/usr/bin/env python3
import argparse
import json
import re
import sys
from pathlib import Path

SECTION_RE = re.compile(r"^##\s+(.+?)\s*$", re.MULTILINE)
ISO_RE = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|\+00:00)$")
TRACKING_RE = re.compile(r"^#\d+$")
VALID_STAGES = {"planning", "beta", "rc", "final"}
VALID_STATUS = {"in_progress", "blocked", "ready", "published"}
REQUIRED_SECTIONS = ["Current Release", "Blocking Issues", "Next Action", "Notes"]
REQUIRED_KEYS = {
    "version": str,
    "stage": str,
    "status": str,
    "tracking_issue": str,
    "beta_iteration": int,
    "rc_iteration": int,
    "target_date": (str, type(None)),
    "updated_at": str,
    "updated_by": str,
}


def extract_sections(text: str):
    matches = list(SECTION_RE.finditer(text))
    sections = []
    for index, match in enumerate(matches):
        name = match.group(1).strip()
        start = match.end()
        end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        sections.append((name, text[start:end].strip()))
    return sections


def extract_json_block(body: str):
    match = re.search(r"```json\n(.*?)\n```", body, re.DOTALL)
    if not match:
        raise ValueError("missing fenced json block")
    return json.loads(match.group(1))


def main():
    parser = argparse.ArgumentParser(description="Validate docs/delivery/release-state.md structure and current release payload.")
    parser.add_argument("path")
    args = parser.parse_args()

    path = Path(args.path)
    if not path.exists():
        print(f"ERROR: file not found: {path}", file=sys.stderr)
        return 1

    text = path.read_text(encoding="utf-8")
    sections = extract_sections(text)
    names = [name for name, _ in sections]
    errors = []

    if names != REQUIRED_SECTIONS:
        errors.append("required sections must appear exactly once and in order: " + ", ".join(REQUIRED_SECTIONS))

    section_map = {name: body for name, body in sections}

    try:
        payload = extract_json_block(section_map.get("Current Release", ""))
    except Exception as exc:
        errors.append(f"invalid current release json block: {exc}")
        payload = None

    if isinstance(payload, dict):
        missing = [key for key in REQUIRED_KEYS if key not in payload]
        if missing:
            errors.append("missing json keys: " + ", ".join(missing))
        for key, expected in REQUIRED_KEYS.items():
            if key in payload and not isinstance(payload[key], expected):
                errors.append(f"json key '{key}' has wrong type")

        if payload.get("stage") not in VALID_STAGES:
            errors.append("json key 'stage' must be one of: " + ", ".join(sorted(VALID_STAGES)))
        if payload.get("status") not in VALID_STATUS:
            errors.append("json key 'status' must be one of: " + ", ".join(sorted(VALID_STATUS)))
        if isinstance(payload.get("tracking_issue"), str) and not TRACKING_RE.match(payload["tracking_issue"]):
            errors.append("json key 'tracking_issue' must look like '#123'")
        if isinstance(payload.get("updated_at"), str) and not ISO_RE.match(payload["updated_at"]):
            errors.append("json key 'updated_at' must be an ISO-8601 UTC timestamp")
        if isinstance(payload.get("version"), str) and not payload["version"].startswith("v"):
            errors.append("json key 'version' should start with 'v'")
        for key in ["beta_iteration", "rc_iteration"]:
            value = payload.get(key)
            if isinstance(value, int) and value < 0:
                errors.append(f"json key '{key}' must be >= 0")
        target_date = payload.get("target_date")
        if isinstance(target_date, str) and target_date and not re.match(r"^\d{4}-\d{2}-\d{2}$", target_date):
            errors.append("json key 'target_date' must be YYYY-MM-DD or null")
        if not str(payload.get("updated_by", "")).strip():
            errors.append("json key 'updated_by' must be non-empty")

    for name in ["Blocking Issues", "Next Action", "Notes"]:
        if not section_map.get(name, "").strip():
            errors.append(f"section '## {name}' must not be empty")

    if errors:
        for error in errors:
            print(f"ERROR: {path}: {error}", file=sys.stderr)
        return 1

    print(f"Release state validation passed: {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
