# Direct Archetype Session Spawn Model

## Purpose

Define the first direct runtime path for spawning independent archetype sessions from the deployed active framework bundles.

## Core model

An independent archetype session should be spawned using:
1. the active runtime bundle for the archetype
2. a task file that describes the current work item
3. an agent-turn payload that combines both

## Bundle source

Always resolve the runtime bundle from:
- `.active/framework/.runtime/<archetype>.md`

Do not source live archetype sessions from the mutable development working copy.

## Helper scripts

### `scripts/spawn-archetype-agent.sh`
Prepare a spawn-ready payload summary for an archetype and task file.

### `scripts/run-archetype-agent.py`
Generate an explicit message payload file that can be supplied to a spawned agent session.

## Integration contract

The payload passed into the independent session should:
- include the full deployed runtime bundle
- include the task file contents
- state clearly that the deployed runtime bundle governs the archetype session

## What this enables

This is the first concrete step from:
- Rowan applying archetype contracts manually

to:
- archetype sessions being launched from deployed framework state

## Current limitation

This layer prepares the direct spawn payload, but the final session-spawn call still needs to be wired through the runtime/tooling surface used by Rowan.

## Next evolution

A later step may directly wrap `sessions_spawn` or another orchestration surface so the helper itself launches the independent archetype session end-to-end.
