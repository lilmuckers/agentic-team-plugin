#!/usr/bin/env python3
import argparse
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description="Merge a specialist template with a task-specific refinement file.")
    parser.add_argument("template")
    parser.add_argument("refinement_file")
    parser.add_argument("--output")
    args = parser.parse_args()

    template_path = Path(args.template)
    refinement_path = Path(args.refinement_file)

    if not template_path.exists():
        raise SystemExit(f"Template not found: {template_path}")
    if not refinement_path.exists():
        raise SystemExit(f"Refinement file not found: {refinement_path}")

    template_text = template_path.read_text(encoding="utf-8").strip()
    refinement_text = refinement_path.read_text(encoding="utf-8").strip()

    output = (
        f"{template_text}\n\n"
        "## Task-Specific Refinement\n\n"
        f"{refinement_text}\n"
    )

    if args.output:
        Path(args.output).write_text(output, encoding="utf-8")
    else:
        print(output)


if __name__ == "__main__":
    main()
