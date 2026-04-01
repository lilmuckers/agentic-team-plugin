#!/usr/bin/env python3
import argparse
from pathlib import Path

parser = argparse.ArgumentParser(description='Prepare a direct archetype agent-turn payload from the active runtime bundle.')
parser.add_argument('--archetype', required=True)
parser.add_argument('--task-file', required=True)
parser.add_argument('--output', required=True)
args = parser.parse_args()

root = Path(__file__).resolve().parent.parent
bundle = root / '.active' / 'framework' / '.runtime' / f'{args.archetype}.md'
if not bundle.exists():
    raise SystemExit(f'Runtime bundle not found: {bundle}')

task_file = Path(args.task_file)
if not task_file.exists():
    raise SystemExit(f'Task file not found: {task_file}')

message = (
    'Use the following deployed runtime bundle as the governing archetype context for this session.\n\n'
    '# Active runtime bundle\n\n'
    f'{bundle.read_text()}\n\n'
    '# Task\n\n'
    f'{task_file.read_text()}\n'
)

Path(args.output).write_text(message)
print(args.output)
