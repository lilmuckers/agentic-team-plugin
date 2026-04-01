#!/usr/bin/env python3
import argparse
import sys
from pathlib import Path


def check_file(path: Path):
    text = path.read_text()
    warnings = []
    if not text.startswith('> _posted by **'):
        warnings.append('does not start with standard agent header')
    if '\t' in text:
        warnings.append('contains tab characters; prefer spaces')
    if any(len(line) > 160 for line in text.splitlines()):
        warnings.append('contains lines longer than 160 characters')
    if '```' in text and text.count('```') % 2 != 0:
        warnings.append('contains unbalanced fenced code blocks')
    return warnings


def main():
    parser = argparse.ArgumentParser(description='Light lint for GitHub-facing agent markdown.')
    parser.add_argument('files', nargs='+')
    args = parser.parse_args()

    had_warning = False
    for file_name in args.files:
        path = Path(file_name)
        if not path.exists():
            print(f'ERROR: file not found: {path}', file=sys.stderr)
            return 1
        warnings = check_file(path)
        for warning in warnings:
            had_warning = True
            print(f'WARN: {path}: {warning}')

    if not had_warning:
        print('Lint passed')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
