#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ACTIVE_FRAMEWORK = Path.cwd() if (Path.cwd() / 'agents').exists() else ROOT
RUNTIME_DIR = ACTIVE_FRAMEWORK / '.runtime'
RUNTIME_DIR.mkdir(parents=True, exist_ok=True)

common_paths = [
    ACTIVE_FRAMEWORK / 'policies' / 'repo-management.md',
    ACTIVE_FRAMEWORK / 'docs' / 'delivery' / 'repo-management-operating-model.md',
    ACTIVE_FRAMEWORK / 'docs' / 'delivery' / 'deployment-model.md',
    ACTIVE_FRAMEWORK / 'docs' / 'delivery' / 'agent-tooling-helpers.md',
]

agent_names = ['orchestrator', 'spec', 'security', 'release-manager', 'builder', 'qa']

for agent in agent_names:
    parts = []
    parts.append(f'# Runtime Bundle: {agent}\n')
    agent_file = ACTIVE_FRAMEWORK / 'agents' / f'{agent}.md'
    parts.append('## Agent definition\n')
    parts.append(agent_file.read_text().strip() + '\n')
    for path in common_paths:
        if path.exists():
            parts.append(f'\n## Included reference: {path.relative_to(ACTIVE_FRAMEWORK)}\n')
            parts.append(path.read_text().strip() + '\n')
    out_path = RUNTIME_DIR / f'{agent}.md'
    out_path.write_text('\n'.join(parts).strip() + '\n')
    print(f'Generated {out_path}')
