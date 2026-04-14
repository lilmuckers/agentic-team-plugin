#!/usr/bin/env python3
import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

ENTRY_RE = re.compile(r"^##\s+Task\s+(.+?)\s*$", re.MULTILINE)
JSON_BLOCK_RE = re.compile(r"```json\n(.*?)\n```", re.DOTALL)
ACTIVE_STATES = {"queued", "in_progress", "stalled", "blocked", "needs_review"}


def parse_iso8601(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(timezone.utc)


def iter_entries(text: str):
    headings = list(ENTRY_RE.finditer(text))
    for index, heading_match in enumerate(headings):
        heading = heading_match.group(0).strip()
        start = heading_match.end()
        end = headings[index + 1].start() if index + 1 < len(headings) else len(text)
        section = text[start:end]
        blocks = JSON_BLOCK_RE.findall(section)
        if len(blocks) != 1:
            continue
        try:
            payload = json.loads(blocks[0])
        except json.JSONDecodeError:
            continue
        yield heading, payload


def main() -> int:
    parser = argparse.ArgumentParser(description="Report overdue task-ledger entries for OpenClaw cron/watchdog use.")
    parser.add_argument("ledger_file")
    parser.add_argument("--grace-minutes", type=int, default=0, help="Additional grace window beyond expected_callback_at.")
    parser.add_argument("--state", action="append", dest="states", help="Restrict checks to specific active states.")
    args = parser.parse_args()

    path = Path(args.ledger_file)
    if not path.exists():
        print(f"ERROR: file not found: {path}", file=sys.stderr)
        return 1

    now = datetime.now(timezone.utc)
    allowed_states = set(args.states or ACTIVE_STATES)
    overdue = []

    for heading, payload in iter_entries(path.read_text(encoding="utf-8")):
        state = payload.get("state")
        if state not in allowed_states:
            continue
        expected = payload.get("expected_callback_at")
        if not isinstance(expected, str) or not expected.strip():
            continue
        try:
            due = parse_iso8601(expected)
        except ValueError:
            print(f"ERROR: {heading}: invalid expected_callback_at '{expected}'", file=sys.stderr)
            return 1
        due = due.replace(second=0, microsecond=0)
        overdue_by_minutes = int((now - due).total_seconds() // 60)
        if overdue_by_minutes < args.grace_minutes:
            continue
        overdue.append(
            {
                "task": payload.get("task"),
                "state": state,
                "owner": payload.get("owner", "unknown"),
                "expected_callback_at": expected,
                "overdue_by_minutes": overdue_by_minutes,
                "current_action": payload.get("current_action", ""),
                "next_action": payload.get("next_action", ""),
            }
        )

    if not overdue:
        print("No overdue task-ledger entries found.")
        return 0

    print(json.dumps({"generated_at": now.replace(microsecond=0).isoformat().replace("+00:00", "Z"), "overdue": overdue}, indent=2))
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
