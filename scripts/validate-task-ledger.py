#!/usr/bin/env python3
# SUPERSEDED: use MCP task tools instead.
# task_list / task_get replace this script.
# See docs/delivery/orchestrator-tooling-helpers.md and skills/task-ledger-mcp/SKILL.md.
# This script is retained for legacy compatibility only.
import argparse
import json
import re
import sys
from datetime import datetime
from pathlib import Path

REQUIRED_FIELDS = {"task", "state", "current_action", "next_action", "history"}
ALLOWED_STATES = {"queued", "in_progress", "stalled", "blocked", "needs_review", "done"}
ENTRY_HEADING_RE = re.compile(r"^##\s+Task\s+(.+?)\s*$", re.MULTILINE)
JSON_BLOCK_RE = re.compile(r"```json\n(.*?)\n```", re.DOTALL)


def validate_entry(heading: str, payload: dict, errors: list[str]):
    missing = sorted(REQUIRED_FIELDS - payload.keys())
    if missing:
        errors.append(f"{heading}: missing required fields: {', '.join(missing)}")
        return

    if payload["state"] not in ALLOWED_STATES:
        errors.append(f"{heading}: invalid state '{payload['state']}'")

    if not isinstance(payload["task"], str) or not payload["task"].strip():
        errors.append(f"{heading}: 'task' must be a non-empty string")

    if not isinstance(payload["current_action"], str) or not payload["current_action"].strip():
        errors.append(f"{heading}: 'current_action' must be a non-empty string")

    if not isinstance(payload["next_action"], str) or not payload["next_action"].strip():
        errors.append(f"{heading}: 'next_action' must be a non-empty string")

    owner = payload.get("owner")
    if owner is not None and (not isinstance(owner, str) or not owner.strip()):
        errors.append(f"{heading}: optional 'owner' must be a non-empty string when present")

    expected_callback_at = payload.get("expected_callback_at")
    if expected_callback_at is not None:
        if not isinstance(expected_callback_at, str) or not expected_callback_at.strip():
            errors.append(f"{heading}: optional 'expected_callback_at' must be a non-empty string when present")
        else:
            try:
                datetime.fromisoformat(expected_callback_at.replace("Z", "+00:00"))
            except ValueError:
                errors.append(f"{heading}: optional 'expected_callback_at' must be ISO-8601 formatted")

    history = payload["history"]
    if not isinstance(history, list) or not history:
        errors.append(f"{heading}: 'history' must be a non-empty array")
        return

    for index, item in enumerate(history, start=1):
        if not isinstance(item, dict):
            errors.append(f"{heading}: history item {index} must be an object")
            continue
        for key in ("at", "action", "by"):
            value = item.get(key)
            if not isinstance(value, str) or not value.strip():
                errors.append(f"{heading}: history item {index} missing non-empty '{key}'")


def main():
    parser = argparse.ArgumentParser(description="Validate a markdown task ledger with embedded JSON payloads.")
    parser.add_argument("ledger_file")
    args = parser.parse_args()

    path = Path(args.ledger_file)
    if not path.exists():
        print(f"ERROR: file not found: {path}", file=sys.stderr)
        return 1

    text = path.read_text(encoding="utf-8")
    headings = list(ENTRY_HEADING_RE.finditer(text))
    json_blocks = list(JSON_BLOCK_RE.finditer(text))
    errors: list[str] = []

    if not headings:
        errors.append("no task entry headings found")

    if len(headings) != len(json_blocks):
        errors.append("each task entry must contain exactly one json block")

    for index, heading_match in enumerate(headings):
        heading = heading_match.group(0).strip()
        start = heading_match.end()
        end = headings[index + 1].start() if index + 1 < len(headings) else len(text)
        section = text[start:end]
        section_blocks = list(JSON_BLOCK_RE.finditer(section))
        if len(section_blocks) != 1:
            errors.append(f"{heading}: expected exactly one json block")
            continue
        try:
            payload = json.loads(section_blocks[0].group(1))
        except json.JSONDecodeError as exc:
            errors.append(f"{heading}: invalid json payload ({exc})")
            continue
        if not isinstance(payload, dict):
            errors.append(f"{heading}: json payload must be an object")
            continue
        validate_entry(heading, payload, errors)

    if errors:
        for error in errors:
            print(f"ERROR: {path}: {error}", file=sys.stderr)
        return 1

    print(f"Task ledger validation passed: {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
