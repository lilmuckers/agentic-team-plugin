# Framework Deployment Model

## Purpose

Define how the delivery-agent framework moves from editable source to stable active deployment.

## Roles of each copy

### Development working copy
This repository checkout is the editable source tree.

Use it to:
- edit agent definitions
- add or refine skills
- update workflow and policy docs
- prepare commits and pull requests

This copy is expected to change frequently.

### GitHub `main`
`main` is the reviewed source-of-truth branch for approved framework changes.

Rules:
- ongoing changes should arrive through feature branches and pull requests
- reviewed merges to `main` are the only candidate source for deployment

### Active deployment copy
The active deployment copy is a stable snapshot used by runtime consumers.

Rules:
- do not edit it as a scratch working tree
- replace or promote it only from reviewed `main` commits
- record deployed commit SHA and timestamp on every promotion

## Promotion sequence

1. update local `main` from GitHub
2. validate that the working copy is on `main`
3. validate required framework files and helper scripts
4. sync managed framework files into the active copy
5. exclude local Rowan/OpenClaw state and downstream project templates
6. validate the active copy
7. generate runtime bundles for the live archetypes
8. record deployed SHA and timestamp

## Exclusions

The following are intentionally excluded from active deployment promotion:
- Rowan/OpenClaw identity files
- local memory and heartbeat state
- `.openclaw/` runtime metadata
- `repo-templates/` project bootstrap assets
- ad hoc local helper scripts not part of the framework runtime

## Runtime generation

Deployment now also generates runtime bundles in the active copy for:
- orchestrator
- spec
- builder
- qa

These bundles are intended to be the live source material for archetype sessions.

## Named-agent deployment

Named-agent deployment now needs to distinguish between:
- on-disk inspection payloads written into configured `agentDir` directories
- actual workspace bootstrap/context files that are likely loaded at named-agent session startup

See also:
- `docs/delivery/named-agent-deployment.md`
- `docs/delivery/workspace-bootstrap-deployment.md`

The revised preferred model is to deploy the files that affect workspace startup behavior, then roll to a fresh named-agent session so the runtime reloads them.

## Why this split exists

This separation gives us:
- clean Git review history
- safer rollback and provenance
- less risk of local assistant state leaking into the framework
- clearer boundaries between control-plane framework assets and downstream project assets
- a stable runtime source that is distinct from the mutable development working copy
