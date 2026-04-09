#!/usr/bin/env python3
import argparse
import difflib
import json
from pathlib import Path
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parent.parent
ACTIVE = ROOT / '.active' / 'framework'
AGENT_WORKSPACES = {
    'orchestrator': Path('/data/.openclaw/workspace-orchestrator'),
    'spec': Path('/data/.openclaw/workspace-spec'),
    'builder': Path('/data/.openclaw/workspace-builder'),
    'qa': Path('/data/.openclaw/workspace-qa'),
}

now = datetime.now(timezone.utc).isoformat()

AGENTS_TEMPLATE = """# AGENTS.md - Managed Agent Workspace\n\nThis workspace is managed from the reviewed `agentic-team-plugin` framework deployment.\n\n## Session Startup\n\nBefore doing anything else:\n\n1. Read `SOUL.md`\n2. Read `USER.md`\n3. Read `IDENTITY.md`\n4. Read `FRAMEWORK_RUNTIME_BUNDLE.md`\n5. Read `FRAMEWORK_NOTES.md`\n\nDo not assume these files hot-reload into an already-running session. A fresh session is the reload boundary.\n\n## Runtime model\n\n- This workspace is for the `{agent}` named agent\n- It should follow the deployed framework bundle and notes written here\n- Treat framework-managed files as source-of-truth for startup context\n"""

SOUL_TEMPLATE = """# SOUL.md\n\nYou are the `{agent}` named agent operating under the reviewed `agentic-team-plugin` framework.\n\nYour detailed runtime contract is in `FRAMEWORK_RUNTIME_BUNDLE.md`.\nYour deployment metadata is in `FRAMEWORK_NOTES.md`.\n\nUse those files as the governing startup context for this workspace.\n"""

USER_TEMPLATE = """# USER.md\n\n- Name: Patrick\n- What to call them: Patrick\n- Timezone: Europe/London\n- Notes: Human operator and framework owner. Use the reviewed framework and visible GitHub artefacts as the operating model.\n"""

IDENTITY_TEMPLATE = """# IDENTITY.md\n\n- Name: {agent}\n- Role: named delivery agent\n- Framework: agentic-team-plugin\n"""

def build_files(agent: str, bundle: Path):
    deployed_sha_file = ROOT / '.state' / 'framework' / 'deployed-sha.txt'
    deployed_sha = 'unknown'
    if deployed_sha_file.exists():
        deployed_sha = deployed_sha_file.read_text().split()[0]

    return {
        'AGENTS.md': AGENTS_TEMPLATE.format(agent=agent),
        'SOUL.md': SOUL_TEMPLATE.format(agent=agent),
        'USER.md': USER_TEMPLATE,
        'IDENTITY.md': IDENTITY_TEMPLATE.format(agent=agent),
        'FRAMEWORK_RUNTIME_BUNDLE.md': bundle.read_text(),
        'FRAMEWORK_NOTES.md': (
            f'# FRAMEWORK_NOTES.md\n\n'
            f'- agent: {agent}\n'
            f'- deployedAt: {now}\n'
            f'- deployedSha: {deployed_sha}\n'
            f'- loadedSha: {deployed_sha}\n'
            f'- activeFrameworkDir: {ACTIVE}\n'
            f'- runtimeBundle: {bundle}\n'
            f'- reloadBoundary: start a fresh named-agent session to pick up updates\n'
        ),
        'FRAMEWORK_DEPLOYMENT.json': json.dumps({
            'agent': agent,
            'deployedAt': now,
            'deployedSha': deployed_sha,
            'loadedSha': deployed_sha,
            'activeFrameworkDir': str(ACTIVE),
            'runtimeBundle': str(bundle),
            'reloadBoundary': 'fresh-session',
        }, indent=2),
    }


def main():
    parser = argparse.ArgumentParser(description='Deploy managed workspace bootstrap files for named agents.')
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--force', action='store_true')
    args = parser.parse_args()

    for agent, workspace in AGENT_WORKSPACES.items():
        workspace.mkdir(parents=True, exist_ok=True)
        bundle = ACTIVE / '.runtime' / f'{agent}.md'
        if not bundle.exists():
            raise SystemExit(f'Missing runtime bundle for {agent}: {bundle}')

        files = build_files(agent, bundle)
        if args.dry_run:
            print(f'=== {workspace} ===')
            for name, content in files.items():
                target = workspace / name
                existing = target.read_text() if target.exists() else ''
                if existing != content:
                    diff = difflib.unified_diff(
                        existing.splitlines(),
                        content.splitlines(),
                        fromfile=str(target),
                        tofile=f'{target} (new)',
                        lineterm='',
                    )
                    for line in diff:
                        print(line)
            continue

        if not args.force:
            existing_files = [workspace / name for name in files if (workspace / name).exists()]
            if existing_files:
                raise SystemExit(
                    f'Workspace {workspace} already contains managed files; rerun with --force or --dry-run first.'
                )

        for name, content in files.items():
            (workspace / name).write_text(content)

        print(f'Deployed workspace bootstrap files into {workspace}')


if __name__ == '__main__':
    main()
