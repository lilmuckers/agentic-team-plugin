#!/usr/bin/env python3
"""
Validate a callback report against the compact line-keyed callback schema.
See schemas/callback.md for the full specification.
"""
import argparse
import re
import sys
from pathlib import Path

VALID_STATUSES = {"DONE", "BLOCKED", "FAILED", "NEEDS_REVIEW"}

# Keys that must appear in every callback, in this order
REQUIRED_KEYS = ["FROM", "TO", "TASK", "STATUS", "BLOCKERS", "NEXT"]

# Keys required only when STATUS is DONE or NEEDS_REVIEW
REF_REQUIRED_FOR = {"DONE", "NEEDS_REVIEW"}

# Keys required only when STATUS is NEEDS_REVIEW
CHECKS_REQUIRED_FOR = {"NEEDS_REVIEW"}

URL_RE = re.compile(r"^https?://\S+$")
KEY_LINE_RE = re.compile(r"^([A-Z][A-Z0-9_]*):\s*(.*)$")


def parse_callback(text: str):
    """Return ordered list of (key, value) pairs and a set of errors."""
    pairs = []
    errors = []
    for lineno, raw in enumerate(text.splitlines(), 1):
        line = raw.strip()
        if not line:
            continue  # tolerate trailing newlines
        m = KEY_LINE_RE.match(line)
        if not m:
            errors.append(f"line {lineno}: unrecognised format — expected KEY: value, got: {raw!r}")
            continue
        pairs.append((m.group(1), m.group(2).strip()))
    return pairs, errors


def validate_callback(path: Path):
    text = path.read_text(encoding="utf-8")
    pairs, errors = parse_callback(text)

    keys = [k for k, _ in pairs]
    kv = {k: v for k, v in pairs}

    # ── required keys present ────────────────────────────────────────────────
    for key in REQUIRED_KEYS:
        if key not in keys:
            errors.append(f"missing required key: {key}")

    # ── no duplicate keys ────────────────────────────────────────────────────
    seen = set()
    for key in keys:
        if key in seen:
            errors.append(f"duplicate key: {key}")
        seen.add(key)

    # ── key ordering (required keys must appear before optional ones) ────────
    required_positions = [keys.index(k) for k in REQUIRED_KEYS if k in keys]
    if required_positions != sorted(required_positions):
        errors.append(
            "required keys must appear in order: " + ", ".join(REQUIRED_KEYS)
        )

    # ── STATUS is valid ──────────────────────────────────────────────────────
    status = kv.get("STATUS", "").upper()
    if status and status not in VALID_STATUSES:
        errors.append(
            f"STATUS must be one of: {', '.join(sorted(VALID_STATUSES))} — got: {status!r}"
        )

    # ── TO names a specific agent ────────────────────────────────────────────
    to = kv.get("TO", "").strip()
    if to and not re.match(r"^[a-z][a-z0-9-]*$", to):
        errors.append(
            f"TO must be a valid agent id (lowercase, hyphens allowed) — got: {to!r}"
        )

    # ── REF required and must be a URL for DONE / NEEDS_REVIEW ──────────────
    if status in REF_REQUIRED_FOR:
        ref = kv.get("REF", "").strip()
        if not ref:
            errors.append(f"REF is required when STATUS is {status}")
        elif not URL_RE.match(ref):
            errors.append(f"REF must be a URL — got: {ref!r}")

    # ── CHECKS required for NEEDS_REVIEW ────────────────────────────────────
    if status in CHECKS_REQUIRED_FOR:
        checks = kv.get("CHECKS", "").strip()
        if not checks:
            errors.append("CHECKS is required when STATUS is NEEDS_REVIEW")

    # ── BLOCKERS must not be empty ───────────────────────────────────────────
    blockers = kv.get("BLOCKERS", "").strip()
    if "BLOCKERS" in kv and not blockers:
        errors.append("BLOCKERS must not be empty — use 'none' if there are no blockers")

    # ── BLOCKERS: none is only valid for DONE / NEEDS_REVIEW ────────────────
    if status in {"BLOCKED", "FAILED"} and blockers.lower() == "none":
        errors.append(
            f"BLOCKERS must contain actionable detail when STATUS is {status} — 'none' is not valid"
        )

    # ── NEXT must not be empty ───────────────────────────────────────────────
    next_action = kv.get("NEXT", "").strip()
    if "NEXT" in kv and not next_action:
        errors.append("NEXT must not be empty")

    # ── non-empty required keys ──────────────────────────────────────────────
    for key in ["FROM", "TO", "TASK"]:
        if key in kv and not kv[key].strip():
            errors.append(f"{key} must not be empty")

    return errors


def main():
    parser = argparse.ArgumentParser(
        description="Validate a callback report against the compact callback schema."
    )
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
