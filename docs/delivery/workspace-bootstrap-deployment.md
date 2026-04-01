# Workspace Bootstrap Deployment Model

## Purpose

Define the revised deployment model for named agents based on what the runtime actually appears to consume: workspace bootstrap/context files that are loaded at session start.

## Key runtime lesson

The named-agent runtime did **not** prove automatic consumption of arbitrary files written into the configured `agentDir`.

The more credible load boundary is the named-agent workspace bootstrap/context files such as:
- `AGENTS.md`
- `SOUL.md`
- `USER.md`
- related workspace files that `AGENTS.md` instructs the agent to read at session startup

## Reload boundary

Changes to those files should be treated as taking effect when a **new session** is started for the named agent.
They should not be assumed to hot-reload into an already-running named-agent session.

## Revised source chain

1. GitHub framework repo (`main` after review)
2. active framework deployment in `.active/framework/`
3. generated runtime bundles in `.active/framework/.runtime/`
4. managed named-agent workspace bootstrap files
5. new named-agent session start / session rollover

## Deployment target

The deployment layer should manage the named-agent workspaces, not only the `agentDir` directories.

Examples:
- `/data/.openclaw/workspace-orchestrator/`
- `/data/.openclaw/workspace-spec/`
- `/data/.openclaw/workspace-builder/`
- `/data/.openclaw/workspace-qa/`

## What should be managed

At minimum, the framework should define how to write or generate the files that actually steer startup behavior.
For example:
- `AGENTS.md`
- `SOUL.md`
- additional referenced workspace files where appropriate

See also:
- `docs/delivery/managed-workspace-files.md`

## Session rollover rule

After deployment updates the managed workspace bootstrap files, a fresh named-agent session should be started to pick up the new behavior.

This means deployment and activation are separate steps:
- deploy files
- roll session

## Why this model is better

This aligns the framework with the runtime behavior we actually observed instead of assuming arbitrary `agentDir` files are automatically prompt-loaded.
