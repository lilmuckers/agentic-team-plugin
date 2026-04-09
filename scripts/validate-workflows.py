#!/usr/bin/env python3
import argparse
import sys
from pathlib import Path


REQUIRED_TOP_LEVEL = {"name", "description", "steps", "on_blocked", "on_failure", "loops"}
REQUIRED_STEP_KEYS = {"id", "agent", "preconditions", "postconditions", "output"}
REQUIRED_LOOP_KEYS = {"from", "to", "trigger"}


def parse_scalar(value: str):
    value = value.strip()
    if (value.startswith('"') and value.endswith('"')) or (value.startswith("'") and value.endswith("'")):
        return value[1:-1]
    return value


def load_yaml(path: Path):
    lines = path.read_text(encoding="utf-8").splitlines()
    data = {}
    current_key = None
    current_step = None
    current_loop = None
    step_list_key = None

    for raw in lines:
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        indent = len(raw) - len(raw.lstrip(" "))
        line = raw.strip()

        if indent == 0 and ":" in line and not line.startswith("- "):
            key, value = line.split(":", 1)
            key = key.strip()
            value = value.strip()
            current_key = key
            current_step = None
            current_loop = None
            step_list_key = None
            if value:
                data[key] = parse_scalar(value)
            else:
                data[key] = [] if key in {"steps", "on_blocked", "on_failure", "loops"} else {}
            continue

        if current_key in {"on_blocked", "on_failure"} and indent >= 2 and line.startswith("- "):
            data[current_key].append(parse_scalar(line[2:]))
            continue

        if current_key == "steps":
            if indent == 2 and line.startswith("- "):
                current_step = {}
                data["steps"].append(current_step)
                step_list_key = None
                remainder = line[2:]
                if remainder and ":" in remainder:
                    key, value = remainder.split(":", 1)
                    current_step[key.strip()] = parse_scalar(value)
                continue
            if indent == 4 and ":" in line and current_step is not None:
                key, value = line.split(":", 1)
                key = key.strip()
                value = value.strip()
                if value:
                    current_step[key] = parse_scalar(value)
                    step_list_key = None
                else:
                    current_step[key] = []
                    step_list_key = key
                continue
            if indent == 6 and line.startswith("- ") and current_step is not None and step_list_key:
                current_step[step_list_key].append(parse_scalar(line[2:]))
                continue

        if current_key == "loops":
            if indent == 2 and line.startswith("- "):
                current_loop = {}
                data["loops"].append(current_loop)
                remainder = line[2:]
                if remainder and ":" in remainder:
                    key, value = remainder.split(":", 1)
                    current_loop[key.strip()] = parse_scalar(value)
                continue
            if indent == 4 and ":" in line and current_loop is not None:
                key, value = line.split(":", 1)
                current_loop[key.strip()] = parse_scalar(value)
                continue

    return data


def validate_workflow(path: Path):
    errors = []
    try:
        data = load_yaml(path)
    except Exception as exc:
        return [f"invalid yaml: {exc}"]

    if not isinstance(data, dict):
        return ["workflow must be a mapping"]

    missing = REQUIRED_TOP_LEVEL - data.keys()
    if missing:
        errors.append("missing top-level fields: " + ", ".join(sorted(missing)))

    steps = data.get("steps")
    if not isinstance(steps, list) or not steps:
        errors.append("'steps' must be a non-empty list")
    else:
        seen = set()
        for index, step in enumerate(steps, start=1):
            if not isinstance(step, dict):
                errors.append(f"step {index} must be a mapping")
                continue
            step_missing = REQUIRED_STEP_KEYS - step.keys()
            if step_missing:
                errors.append(f"step {index} missing fields: {', '.join(sorted(step_missing))}")
                continue
            step_id = step["id"]
            if step_id in seen:
                errors.append(f"duplicate step id: {step_id}")
            seen.add(step_id)
            for key in ["id", "agent", "output"]:
                if not isinstance(step.get(key), str) or not step[key].strip():
                    errors.append(f"step {index} field '{key}' must be a non-empty string")
            for key in ["preconditions", "postconditions"]:
                value = step.get(key)
                if not isinstance(value, list) or not value or not all(isinstance(item, str) and item.strip() for item in value):
                    errors.append(f"step {index} field '{key}' must be a non-empty list of strings")

    for key in ["on_blocked", "on_failure"]:
        value = data.get(key)
        if not isinstance(value, list) or not value or not all(isinstance(item, str) and item.strip() for item in value):
            errors.append(f"'{key}' must be a non-empty list of strings")

    loops = data.get("loops")
    step_ids = {step.get("id") for step in steps if isinstance(step, dict)} if isinstance(steps, list) else set()
    if not isinstance(loops, list) or not loops:
        errors.append("'loops' must be a non-empty list")
    else:
        for index, loop in enumerate(loops, start=1):
            if not isinstance(loop, dict):
                errors.append(f"loop {index} must be a mapping")
                continue
            loop_missing = REQUIRED_LOOP_KEYS - loop.keys()
            if loop_missing:
                errors.append(f"loop {index} missing fields: {', '.join(sorted(loop_missing))}")
                continue
            for key in REQUIRED_LOOP_KEYS:
                if not isinstance(loop.get(key), str) or not loop[key].strip():
                    errors.append(f"loop {index} field '{key}' must be a non-empty string")
            if loop.get("from") not in step_ids:
                errors.append(f"loop {index} references unknown from-step '{loop.get('from')}'")
            if loop.get("to") not in step_ids:
                errors.append(f"loop {index} references unknown to-step '{loop.get('to')}'")

    return errors


def main():
    parser = argparse.ArgumentParser(description="Validate workflow YAML contracts.")
    parser.add_argument("paths", nargs="*")
    args = parser.parse_args()

    paths = [Path(p) for p in (args.paths or ["workflows/implement-feature.yaml", "workflows/fix-bug.yaml", "workflows/prepare-release.yaml"])]
    had_error = False
    for path in paths:
        if not path.exists():
            print(f"ERROR: file not found: {path}", file=sys.stderr)
            had_error = True
            continue
        errors = validate_workflow(path)
        if errors:
            had_error = True
            for error in errors:
                print(f"ERROR: {path}: {error}", file=sys.stderr)
        else:
            print(f"Workflow validation passed: {path}")

    return 1 if had_error else 0


if __name__ == "__main__":
    raise SystemExit(main())
