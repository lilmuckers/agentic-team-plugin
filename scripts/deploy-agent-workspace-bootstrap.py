#!/usr/bin/env python3
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

for agent, workspace in AGENT_WORKSPACES.items():
    workspace.mkdir(parents=True, exist_ok=True)
    bundle = ACTIVE / '.runtime' / f'{agent}.md'
    if not bundle.exists():
        raise SystemExit(f'Missing runtime bundle for {agent}: {bundle}')

    (workspace / 'AGENTS.md').write_text(AGENTS_TEMPLATE.format(agent=agent))
    (workspace / 'SOUL.md').write_text(SOUL_TEMPLATE.format(agent=agent))
    (workspace / 'USER.md').write_text(USER_TEMPLATE)
    (workspace / 'IDENTITY.md').write_text(IDENTITY_TEMPLATE.format(agent=agent))
    (workspace / 'FRAMEWORK_RUNTIME_BUNDLE.md').write_text(bundle.read_text())
    (workspace / 'FRAMEWORK_NOTES.md').write_text(
        f'# FRAMEWORK_NOTES.md\n\n'
        f'- agent: {agent}\n'
        f'- deployedAt: {now}\n'
        f'- activeFrameworkDir: {ACTIVE}\n'
        f'- runtimeBundle: {bundle}\n'
        f'- reloadBoundary: start a fresh named-agent session to pick up updates\n'
    )
    (workspace / 'FRAMEWORK_DEPLOYMENT.json').write_text(json.dumps({
        'agent': agent,
        'deployedAt': now,
        'activeFrameworkDir': str(ACTIVE),
        'runtimeBundle': str(bundle),
        'reloadBoundary': 'fresh-session',
    }, indent=2))

    print(f'Deployed workspace bootstrap files into {workspace}')
