# Named Agent Deployment Model

## Purpose

Describe the deployment bridge for named agents and point to the revised model based on actual runtime findings.

## Important update

The framework originally deployed deterministic payloads into the configured named-agent `agentDir` directories.
That remains useful for inspection and metadata, but runtime testing did **not** prove that arbitrary `agentDir` files are automatically consumed by named-agent invocation.

## Revised model

See:
- `docs/delivery/workspace-bootstrap-deployment.md`

The revised preferred model is:
1. deploy reviewed framework state into the named-agent workspace bootstrap/context files
2. start a fresh named-agent session
3. treat that new session as the activation boundary for the updated behavior

## Legacy payloads

The on-disk payloads in `/data/.openclaw/agents/<agent>/` remain useful as:
- deployment metadata
- inspection artefacts
- deterministic snapshots of the active framework bundle

But they should not be assumed to be the direct runtime prompt-loading path unless proven otherwise.
