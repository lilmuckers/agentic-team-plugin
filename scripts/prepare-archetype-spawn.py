#!/usr/bin/env python3
import argparse
import json
from pathlib import Path

parser = argparse.ArgumentParser(description='Prepare a sessions_spawn-ready payload for an archetype.')
parser.add_argument('--archetype', required=True)
parser.add_argument('--project', required=True)
parser.add_argument('--task-file', required=True)
parser.add_argument('--label')
args = parser.parse_args()

root = Path(__file__).resolve().parent.parent
bundle = root / '.active' / 'framework' / '.runtime' / f'{args.archetype}.md'
if not bundle.exists():
    raise SystemExit(f'Runtime bundle not found: {bundle}')

task_file = Path(args.task_file)
if not task_file.exists():
    raise SystemExit(f'Task file not found: {task_file}')

archetype = args.archetype.strip().lower()
project_slug = args.project.strip().lower().replace(' ', '-').replace('_', '-')

# Always spawn an isolated session. This script is for fresh disposable workers.
# To send work to an existing named project agent (spec-<project>, builder-<project>,
# qa-<project>, etc.) use scripts/dispatch-named-agent.sh instead.
session_target = 'isolated'

label = args.label or f'{project_slug}-{archetype}'
message = (
    'Use the following deployed runtime bundle as the governing archetype context for this session.\n\n'
    '# Active runtime bundle\n\n'
    f'{bundle.read_text()}\n\n'
    '# Task\n\n'
    f'{task_file.read_text()}\n'
)

payload = {
    'label': label,
    'sessionTarget': session_target,
    'message': message,
}
print(json.dumps(payload, indent=2))
