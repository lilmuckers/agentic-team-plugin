#!/usr/bin/env python3
import argparse
import json
from datetime import datetime, timezone
from pathlib import Path
import re

ENTRY_RE = re.compile(r"(^##\s+Task\s+.+?$)(.*?)(?=^##\s+Task\s+.+?$|\Z)", re.MULTILINE | re.DOTALL)
JSON_BLOCK_RE = re.compile(r"```json\n(.*?)\n```", re.DOTALL)
ALLOWED_STATES = {"queued", "in_progress", "stalled", "blocked", "needs_review", "done"}


def render_entry(task_id: str, title: str, payload: dict) -> str:
    return f"## Task {task_id} - {title}\n\n```json\n{json.dumps(payload, indent=2)}\n```\n"


def main():
    parser = argparse.ArgumentParser(description="Create or update a task-ledger entry.")
    parser.add_argument("ledger_file")
    parser.add_argument("task_id")
    parser.add_argument("title")
    parser.add_argument("state", choices=sorted(ALLOWED_STATES))
    parser.add_argument("current_action")
    parser.add_argument("next_action")
    parser.add_argument("--by", default="Orchestrator")
    parser.add_argument("--history-action", default="Task updated")
    parser.add_argument("--owner")
    parser.add_argument("--expected-callback-at")
    args = parser.parse_args()

    ledger_path = Path(args.ledger_file)
    text = ledger_path.read_text(encoding="utf-8") if ledger_path.exists() else "# Task Ledger\n\n"
    timestamp = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")

    updated = False
    new_chunks = []

    for match in ENTRY_RE.finditer(text):
        heading = match.group(1)
        body = match.group(2)
        if f"## Task {args.task_id} - " not in heading:
            new_chunks.append(match.group(0).strip() + "\n")
            continue

        json_match = JSON_BLOCK_RE.search(body)
        payload = json.loads(json_match.group(1)) if json_match else {}
        payload["task"] = args.task_id
        payload["state"] = args.state
        payload["current_action"] = args.current_action
        payload["next_action"] = args.next_action
        if args.owner is not None:
            payload["owner"] = args.owner
        if args.expected_callback_at is not None:
            payload["expected_callback_at"] = args.expected_callback_at
        history = payload.get("history") or []
        history.append({"at": timestamp, "action": args.history_action, "by": args.by})
        payload["history"] = history
        new_chunks.append(render_entry(args.task_id, args.title, payload).strip() + "\n")
        updated = True

    if not updated:
        payload = {
            "task": args.task_id,
            "state": args.state,
            "current_action": args.current_action,
            "next_action": args.next_action,
            **({"owner": args.owner} if args.owner is not None else {}),
            **({"expected_callback_at": args.expected_callback_at} if args.expected_callback_at is not None else {}),
            "history": [
                {"at": timestamp, "action": args.history_action, "by": args.by}
            ],
        }
        stripped = text.rstrip()
        if stripped and not ENTRY_RE.search(text):
            text = stripped + "\n\n"
            new_text = text + render_entry(args.task_id, args.title, payload)
        else:
            prefix = text[: ENTRY_RE.search(text).start()] if ENTRY_RE.search(text) else text
            existing_entries = "".join(new_chunks)
            new_text = prefix.rstrip() + "\n\n" + existing_entries + render_entry(args.task_id, args.title, payload)
        ledger_path.write_text(new_text, encoding="utf-8")
        return

    prefix_match = ENTRY_RE.search(text)
    prefix = text[:prefix_match.start()] if prefix_match else text
    new_text = prefix.rstrip() + "\n\n" + "\n".join(chunk.strip() for chunk in new_chunks if chunk.strip()) + "\n"
    ledger_path.write_text(new_text, encoding="utf-8")


if __name__ == "__main__":
    main()
