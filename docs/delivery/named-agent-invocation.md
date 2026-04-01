# Named Agent Invocation Model

## Purpose

Define how the configured named OpenClaw agents should be invoked through the CLI/Gateway path.

## Core path

Use:
- `openclaw agent --agent <id> --session-id <id> --message <text>`

This is the first verified runtime path we have found that directly targets the configured named agents.

## Preferred named-agent id model

Prefer project-scoped named agent ids:
- `orchestrator-<project-slug>`
- `spec-<project-slug>`
- `builder-<project-slug>`
- `qa-<project-slug>`

## Canonical session-id model

Within a project-scoped named agent, continuity may still be useful, but the primary isolation should come from the project-scoped agent id itself rather than assuming one global named agent can safely span multiple projects.

## Helpers

### `scripts/agent-session-id.py`
Generate canonical session ids for named-agent use.

### `scripts/invoke-named-agent.sh`
Invoke a named agent through `openclaw agent` using the canonical session-id convention.

### `scripts/list-agent-sessions.sh`
Inspect sessions for a specific named agent or across all configured agents.

## Why this matters

This avoids relying on the assistant-side `sessions_spawn` path for named-agent activation.
Instead, it uses the OpenClaw-native agent/Gateway route that already supports `--agent <id>`.

It also aligns with the revised deployment model: named-agent behavior should be treated as loading from managed workspace bootstrap/context files when a fresh named-agent session starts.

## Hybrid topology mapping

- Orchestrator -> persistent per-project session id
- Spec -> persistent per-project session id
- Builder -> fresh task-scoped session id
- QA -> fresh review-scoped session id
