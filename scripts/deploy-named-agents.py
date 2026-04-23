#!/usr/bin/env python3
import json
import sys
from pathlib import Path
from datetime import datetime, timezone

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from scripts.lib.config import load_config

ROOT = Path(__file__).resolve().parent.parent
ACTIVE = ROOT / '.active' / 'framework'
RUNTIME = ACTIVE / '.runtime'
CONFIG = load_config()
AGENTS_ROOT = Path(CONFIG.workspace_root) / 'agents'

agent_names = ['orchestrator', 'spec', 'security', 'release-manager', 'builder', 'qa', 'triage']
now = datetime.now(timezone.utc).isoformat()

for agent in agent_names:
    bundle = RUNTIME / f'{agent}.md'
    if not bundle.exists():
        raise SystemExit(f'Missing runtime bundle for agent: {agent}')

    agent_dir = AGENTS_ROOT / agent
    agent_dir.mkdir(parents=True, exist_ok=True)

    (agent_dir / 'RUNTIME_BUNDLE.md').write_text(bundle.read_text())
    (agent_dir / 'README.md').write_text(
        f'# {agent}\n\n'
        'This directory is deployed from the reviewed agentic-team-plugin framework.\n\n'
        f'- source runtime bundle: {bundle}\n'
        '- do not hand-edit drift into this directory; redeploy from reviewed framework state\n'
    )
    (agent_dir / 'DEPLOYMENT.json').write_text(json.dumps({
        'agent': agent,
        'deployedAt': now,
        'runtimeBundle': str(bundle),
        'activeFrameworkDir': str(ACTIVE),
    }, indent=2))

    print(f'Deployed named agent payload into {agent_dir}')
