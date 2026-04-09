#!/usr/bin/env python3
import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

HEADER = "## Current Release"


def replace_json_block(text: str, payload: dict) -> str:
    block = "```json\n" + json.dumps(payload, indent=2) + "\n```"
    marker = HEADER + "\n\n"
    if marker not in text:
        raise SystemExit(f"Missing section: {HEADER}")
    start = text.index(marker) + len(marker)
    end = text.find("```", start)
    if end == -1:
        raise SystemExit("Missing fenced json block under ## Current Release")
    end = text.find("```", end + 3)
    if end == -1:
        raise SystemExit("Unterminated fenced json block under ## Current Release")
    end += 3
    return text[:start] + block + text[end:]


def main():
    parser = argparse.ArgumentParser(description="Update docs/delivery/release-state.md current release JSON block.")
    parser.add_argument("path")
    parser.add_argument("--version", required=True)
    parser.add_argument("--stage", required=True, choices=["planning", "beta", "rc", "final"])
    parser.add_argument("--status", default="in_progress", choices=["in_progress", "blocked", "ready", "published"])
    parser.add_argument("--tracking-issue", required=True)
    parser.add_argument("--beta-iteration", type=int, default=0)
    parser.add_argument("--rc-iteration", type=int, default=0)
    parser.add_argument("--target-date")
    parser.add_argument("--updated-by", required=True)
    args = parser.parse_args()

    path = Path(args.path)
    text = path.read_text()
    payload = {
        "version": args.version,
        "stage": args.stage,
        "status": args.status,
        "tracking_issue": args.tracking_issue,
        "beta_iteration": args.beta_iteration,
        "rc_iteration": args.rc_iteration,
        "target_date": args.target_date,
        "updated_at": datetime.now(timezone.utc).isoformat(),
        "updated_by": args.updated_by,
    }
    path.write_text(replace_json_block(text, payload))
    print(f"Updated release state: {path}")


if __name__ == "__main__":
    main()
