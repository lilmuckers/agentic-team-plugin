# OpenClaw Spawn Integration

## Purpose

Define the first direct integration path between the deployed archetype runtime bundles and OpenClaw session spawning.

## Core model

A helper should prepare a `sessions_spawn`-ready payload containing:
- archetype label
- resolved session target based on the hybrid topology
- message payload containing the active runtime bundle and task file

## Session target defaults

### Persistent per-project
- Orchestrator -> `session:<project>-orchestrator`
- Spec -> `session:<project>-spec`

### Ephemeral
- Builder -> `isolated`
- QA -> `isolated`

## Helpers

### `scripts/prepare-archetype-spawn.py`
Generate a JSON payload that is ready to be used with an OpenClaw spawn call.

### `scripts/direct-spawn-archetype.sh`
Thin shell wrapper around the payload generator.

## Integration contract

The next runtime layer should take the generated JSON and pass it into the appropriate OpenClaw spawn surface, with:
- the generated `label`
- the generated `sessionTarget`
- the generated `message` as the agent-turn body

## Why this matters

This is the first point where the framework directly models real separate agent sessions rather than only preparing documentation and passive wrappers.

It also creates a clean place for named agents such as Builder and QA to invoke ephemeral specialist subagents internally without promoting those specialists into top-level named-agent roles.
