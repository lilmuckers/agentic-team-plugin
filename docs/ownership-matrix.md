# Ownership Matrix

This repository manages the delivery-agent framework, not Rowan's personal OpenClaw identity files.

## In scope
- agent role definitions
- six top-level named-agent role definitions
- reusable delivery skills
- workflow contracts
- governance and deployment policies
- control-plane documentation for the framework
- release-state and security-review control-plane scaffolding
- downstream project bootstrap assets
- deploy manifests and sync scripts

## Out of scope
- Rowan's `SOUL.md`, `IDENTITY.md`, `USER.md`, `MEMORY.md`
- local private notes or machine-specific tools state
- runtime memory or chat transcripts
- OpenClaw runtime metadata under `.openclaw/`

## File classes
- managed: deployed from this repository into the active framework copy
- local: never overwritten by framework sync
- state: runtime-only, not versioned here
- project-template: copied into downstream project repositories, not into the active framework copy

## Path guidance
- `agents/`, `skills/`, `workflows/`, `policies/`, `templates/`, `schemas/`, `docs/delivery/` -> managed
- `docs/agents/` -> managed human-reference docs, not canonical runtime agent definitions
- `repo-templates/` -> project-template
- workspace-root Rowan/OpenClaw files -> local
- `.active/`, `.state/` -> state
