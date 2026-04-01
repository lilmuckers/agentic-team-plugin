# Named Agent Deployment Model

## Purpose

Define how reviewed framework state is deployed into the configured named OpenClaw agents on disk.

## Source chain

1. GitHub framework repo (`main` after review)
2. active framework deployment in `.active/framework/`
3. generated runtime bundles in `.active/framework/.runtime/`
4. deployed named-agent payloads in `/data/.openclaw/agents/<agent>/`

## Named agents covered

The base archetype names are:
- `orchestrator`
- `spec`
- `builder`
- `qa`

Preferred operational model for real projects:
- `orchestrator-<project-slug>`
- `spec-<project-slug>`
- `builder-<project-slug>`
- `qa-<project-slug>`

## Deployment contract

For each named agent, deployment writes:
- `RUNTIME_BUNDLE.md`
- `README.md`
- `DEPLOYMENT.json`

These files are generated from the reviewed active framework state.
They should not drift through manual edits.

## Why this matters

The configured named agents currently exist in OpenClaw config, but their agent directories start empty.
This deployment layer gives them concrete, inspectable runtime payloads sourced from the framework.

## Runtime implication

This does not by itself prove how the OpenClaw runtime loads those directories internally.
However, it creates the correct deterministic bridge from reviewed framework state into the named-agent directories the runtime is configured to use.
