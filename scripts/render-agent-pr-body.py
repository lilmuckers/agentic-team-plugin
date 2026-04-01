#!/usr/bin/env python3
import argparse
import sys
from pathlib import Path

parser = argparse.ArgumentParser(description="Render a GitHub-ready PR body with agent header.")
parser.add_argument("--archetype", required=True, help="Archetype name, e.g. Builder")
parser.add_argument("--input", help="Path to markdown body file. Reads stdin if omitted.")
args = parser.parse_args()

if args.input:
    body = Path(args.input).read_text()
else:
    body = sys.stdin.read()

body = body.lstrip("\n")
header = f"> _posted by **{args.archetype}**_\n\n"
sys.stdout.write(header + body)
