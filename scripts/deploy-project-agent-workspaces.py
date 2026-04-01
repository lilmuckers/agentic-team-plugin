#!/usr/bin/env python3
import argparse
import json
from pathlib import Path
from datetime import datetime, timezone

parser = argparse.ArgumentParser(description='Deploy managed bootstrap files into project-scoped named-agent workspaces.')
parser.add_argument('--project', required=True)
args = parser.parse_args()

project = args.project.strip().lower().replace(' ', '-').replace('_', '-')
ROOT = Path(__file__).resolve().parent.parent
ACTIVE = ROOT / '.active' / 'framework'
AGENTS = ['orchestrator', 'spec', 'builder', 'qa']
now = datetime.now(timezone.utc).isoformat()

for agent in AGENTS:
    workspace = Path(f'/data/.openclaw/workspace-{agent}-{project}')
    workspace.mkdir(parents=True, exist_ok=True)
    bundle = ACTIVE / '.runtime' / f'{agent}.md'
    if not bundle.exists():
        raise SystemExit(f'Missing runtime bundle for {agent}: {bundle}')

    workspace.joinpath('AGENTS.md').write_text(
        '# AGENTS.md - Managed Project Agent Workspace\n\n'
        f'This workspace is managed from the reviewed `agentic-team-plugin` framework for project namespace: {project}.\n\n'
        '## Session Startup\n\n'
        'Before doing anything else:\n'
        '1. Read `SOUL.md`\n'
        '2. Read `USER.md`\n'
        '3. Read `IDENTITY.md`\n'
        '4. Read `FRAMEWORK_RUNTIME_BUNDLE.md`\n'
        '5. Read `FRAMEWORK_NOTES.md`\n\n'
        'A fresh session is the reload boundary for these files.\n'
    )
    workspace.joinpath('SOUL.md').write_text(
        '# SOUL.md\n\n'
        f'You are `{agent}-{project}`, a project-scoped named agent.\n\n'
        'Your governing runtime contract is in `FRAMEWORK_RUNTIME_BUNDLE.md`.\n'
        'Use the framework-managed files in this workspace as startup context.\n'
    )
    workspace.joinpath('USER.md').write_text(
        '# USER.md\n\n'
        '- Name: Patrick\n'
        '- What to call them: Patrick\n'
        '- Timezone: Europe/London\n'
        '- Notes: Human operator and framework owner.\n'
    )
    workspace.joinpath('IDENTITY.md').write_text(
        '# IDENTITY.md\n\n'
        f'- Name: {agent}-{project}\n'
        '- Role: project-scoped named delivery agent\n'
        f'- Project: {project}\n'
    )
    workspace.joinpath('FRAMEWORK_RUNTIME_BUNDLE.md').write_text(bundle.read_text())
    workspace.joinpath('FRAMEWORK_NOTES.md').write_text(
        '# FRAMEWORK_NOTES.md\n\n'
        f'- project: {project}\n'
        f'- agent: {agent}\n'
        f'- deployedAt: {now}\n'
        f'- source bundle: {bundle}\n'
        '- reload boundary: fresh session required\n'
    )
    workspace.joinpath('FRAMEWORK_DEPLOYMENT.json').write_text(json.dumps({
        'project': project,
        'agent': agent,
        'deployedAt': now,
        'runtimeBundle': str(bundle),
        'reloadBoundary': 'fresh-session',
    }, indent=2))
    print(f'Deployed project-scoped workspace bootstrap into {workspace}')
