#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ACTIVE_FRAMEWORK = Path.cwd() if (Path.cwd() / 'agents').exists() else ROOT
RUNTIME_DIR = ACTIVE_FRAMEWORK / '.runtime'
RUNTIME_DIR.mkdir(parents=True, exist_ok=True)

d = ACTIVE_FRAMEWORK / 'docs' / 'delivery'
p = ACTIVE_FRAMEWORK / 'policies'

# Per-agent additional reference paths (role doc is always included separately).
# Keep this list to files agents actively act on — not operator/framework-management docs.
agent_extra_paths = {
    'orchestrator': [
        d / 'orchestrator-tooling-helpers.md',
    ],
    'spec': [
        d / 'spec-tooling-helpers.md',
    ],
    'builder': [
        d / 'builder-tooling-helpers.md',
    ],
    'qa': [
        d / 'qa-tooling-helpers.md',
    ],
    'security': [
        d / 'security-tooling-helpers.md',
    ],
    'release-manager': [
        d / 'release-manager-tooling-helpers.md',
    ],
    'triage': [
        d / 'triage-tooling-helpers.md',
    ],
}

agent_names = ['orchestrator', 'spec', 'security', 'release-manager', 'builder', 'qa', 'triage']

for agent in agent_names:
    parts = []
    parts.append(f'# Runtime Bundle: {agent}\n')

    agent_file = ACTIVE_FRAMEWORK / 'agents' / f'{agent}.md'
    parts.append('## Agent definition\n')
    parts.append(agent_file.read_text().strip() + '\n')

    for path in agent_extra_paths.get(agent, []):
        if path.exists():
            parts.append(f'\n## Included reference: {path.relative_to(ACTIVE_FRAMEWORK)}\n')
            parts.append(path.read_text().strip() + '\n')
        else:
            print(f'WARNING: expected helper not found for {agent}: {path}')

    out_path = RUNTIME_DIR / f'{agent}.md'
    out_path.write_text('\n'.join(parts).strip() + '\n')
    print(f'Generated {out_path}')
