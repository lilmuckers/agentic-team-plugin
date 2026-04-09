#!/usr/bin/env python3
import argparse

parser = argparse.ArgumentParser(description='Resolve the default session target mode for an archetype.')
parser.add_argument('--archetype', required=True)
parser.add_argument('--project', required=True)
args = parser.parse_args()

archetype = args.archetype.strip().lower()
project = args.project.strip().lower().replace(' ', '-').replace('_', '-')

if archetype in ('orchestrator', 'spec', 'security', 'release-manager'):
    print(f'session:{project}-{archetype}')
elif archetype in ('builder', 'qa'):
    print('isolated')
else:
    print('isolated')
