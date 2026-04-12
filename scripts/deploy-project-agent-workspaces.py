#!/usr/bin/env python3
import argparse
import json
from datetime import datetime, timezone
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from scripts.lib.config import load_config


def build_files(project: str, agent: str, bundle: Path, active_dir: Path, deployed_sha: str, timestamp: str, config, workspace_root: Path):
    return {
        'AGENTS.md': (
            '# AGENTS.md - Managed Project Agent Workspace\n\n'
            f'This workspace is managed from the reviewed `agentic-team-plugin` framework for project namespace: {project}.\n\n'
            '## Session Startup\n\n'
            'Before doing anything else:\n'
            '1. Read `SOUL.md`\n'
            '2. Read `USER.md`\n'
            '3. Read `IDENTITY.md`\n'
            '4. Read `FRAMEWORK_RUNTIME_BUNDLE.md`\n'
            '5. Read `FRAMEWORK_NOTES.md`\n\n'
            'A fresh session is the reload boundary for these files.\n\n'
            '## Project repo checkout\n\n'
            f'Clone the project repo into the `repo/` subdirectory of this workspace — see `repoCheckoutPath` in `FRAMEWORK_NOTES.md`.\n\n'
            'NEVER clone at the workspace root. Your workspace config files (SOUL.md, IDENTITY.md, AGENTS.md, FRAMEWORK_*.md, etc.) '
            'must not be inside the project git working tree. If two agents share a checkout they will stomp each other\'s branches.\n'
        ),
        'SOUL.md': (
            '# SOUL.md\n\n'
            f'You are `{agent}-{project}`, a project-scoped named agent.\n\n'
            'Your governing runtime contract is in `FRAMEWORK_RUNTIME_BUNDLE.md`.\n'
            'Use the framework-managed files in this workspace as startup context.\n'
        ),
        'USER.md': (
            '# USER.md\n\n'
            f'- Name: {config.operator_name}\n'
            f'- What to call them: {config.operator_callname}\n'
            f'- Timezone: {config.operator_timezone}\n'
            '- Notes: Human operator and framework owner.\n'
        ),
        'IDENTITY.md': (
            '# IDENTITY.md\n\n'
            f'- Name: {agent}-{project}\n'
            '- Role: project-scoped named delivery agent\n'
            f'- Project: {project}\n'
        ),
        'FRAMEWORK_RUNTIME_BUNDLE.md': bundle.read_text(),
        'FRAMEWORK_NOTES.md': (
            '# FRAMEWORK_NOTES.md\n\n'
            f'- project: {project}\n'
            f'- agent: {agent}\n'
            f'- deployedAt: {timestamp}\n'
            f'- deployedSha: {deployed_sha}\n'
            f'- loadedSha: {deployed_sha}\n'
            f'- activeFrameworkDir: {active_dir}\n'
            f'- source bundle: {bundle}\n'
            '- reload boundary: fresh session required\n'
            f'- repoCheckoutPath: {workspace_root}/workspace-{agent}-{project}/repo\n'
        ),
        'FRAMEWORK_DEPLOYMENT.json': json.dumps(
            {
                'project': project,
                'agent': agent,
                'deployedAt': timestamp,
                'deployedSha': deployed_sha,
                'loadedSha': deployed_sha,
                'activeFrameworkDir': str(active_dir),
                'runtimeBundle': str(bundle),
                'reloadBoundary': 'fresh-session',
                'repoCheckoutPath': f'{workspace_root}/workspace-{agent}-{project}/repo',
            },
            indent=2,
        ),
    }


def main():
    config = load_config()
    parser = argparse.ArgumentParser(description='Deploy managed bootstrap files into project-scoped named-agent workspaces.')
    parser.add_argument('--project', required=True)
    parser.add_argument('--workspace-root', default=config.workspace_root)
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()

    project = args.project.strip().lower().replace(' ', '-').replace('_', '-')
    root = Path(__file__).resolve().parent.parent
    active = root / '.active' / 'framework'
    deployed_sha_file = root / '.state' / 'framework' / 'deployed-sha.txt'
    deployed_sha = deployed_sha_file.read_text().split()[0] if deployed_sha_file.exists() else 'unknown'
    agents = ['orchestrator', 'spec', 'security', 'release-manager', 'builder', 'qa']
    timestamp = datetime.now(timezone.utc).isoformat()
    workspace_root = Path(args.workspace_root)

    for agent in agents:
        workspace = workspace_root / f'workspace-{agent}-{project}'
        bundle = active / '.runtime' / f'{agent}.md'
        if not bundle.exists():
            raise SystemExit(f'Missing runtime bundle for {agent}: {bundle}')

        files = build_files(project, agent, bundle, active, deployed_sha, timestamp, config, workspace_root)

        if args.dry_run:
            print(f'=== {workspace} ===')
            for name, content in files.items():
                print(f'--- {name} ---')
                print(content.rstrip())
            continue

        workspace.mkdir(parents=True, exist_ok=True)
        for name, content in files.items():
            workspace.joinpath(name).write_text(content)
        print(f'Deployed project-scoped workspace bootstrap into {workspace}')


if __name__ == '__main__':
    main()
