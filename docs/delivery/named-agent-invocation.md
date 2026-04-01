# Named Agent Invocation Model

## Purpose

Define how the configured named OpenClaw agents should be invoked through the CLI/Gateway path.

## Core path

Use:
- `openclaw agent --agent <id> --session-id <id> --message <text>`

This is the first verified runtime path we have found that directly targets the configured named agents.

## Canonical session-id model

### Persistent project sessions
- Orchestrator -> `<project>-orchestrator`
- Spec -> `<project>-spec`

### Ephemeral task/review sessions
- Builder -> `<project>-builder-<task>`
- QA -> `<project>-qa-<task>`

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

## Hybrid topology mapping

- Orchestrator -> persistent per-project session id
- Spec -> persistent per-project session id
- Builder -> fresh task-scoped session id
- QA -> fresh review-scoped session id
