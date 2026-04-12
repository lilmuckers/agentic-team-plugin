#!/usr/bin/env python3
# Resolve the session target mode for the spawn/ephemeral-worker path.
#
# This script is used when spawning a fresh disposable worker via
# prepare-archetype-spawn.py or direct-spawn-archetype.sh. The target is
# always 'isolated' because spawning is only used for generic or temporary
# workers, never for project-scoped named agents.
#
# To reach an existing named project agent (spec-<project>, builder-<project>,
# qa-<project>, etc.) use scripts/dispatch-named-agent.sh directly. That path
# sends to the running named session and does not go through sessions_spawn.
import argparse

parser = argparse.ArgumentParser(description='Resolve the spawn session target mode for an archetype.')
parser.add_argument('--archetype', required=True)
parser.add_argument('--project', required=True)
args = parser.parse_args()

# Always isolated: spawning creates a fresh worker, never re-enters a named session.
print('isolated')
