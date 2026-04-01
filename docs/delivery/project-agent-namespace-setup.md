# Project Agent Namespace Setup

## Purpose

Define the practical setup flow for project-scoped named agents.

## Steps

1. Create the project-scoped named agents
2. Deploy the managed workspace bootstrap files into their workspaces
3. Invoke the project-scoped named agents with fresh sessions so they load the updated bootstrap files

## Helpers

### `scripts/create-project-scoped-agents.sh`
Create/ensure the four project-scoped named agents:
- `orchestrator-<project>`
- `spec-<project>`
- `builder-<project>`
- `qa-<project>`

### `scripts/deploy-project-agent-workspaces.py`
Write the managed workspace bootstrap files into:
- `/data/.openclaw/workspace-orchestrator-<project>/`
- `/data/.openclaw/workspace-spec-<project>/`
- `/data/.openclaw/workspace-builder-<project>/`
- `/data/.openclaw/workspace-qa-<project>/`

### `scripts/setup-project-agent-namespace.sh`
One-shot helper that runs both steps above.

## Activation rule

After setup or framework updates, invoke the project-scoped named agent in a fresh session so it loads the deployed bootstrap files.
