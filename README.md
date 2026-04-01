# agentic-team-plugin

Versioned framework for a reusable agentic delivery team: orchestrator, builder, spec, QA, shared skills, workflows, policies, and deployment sync mechanics.

## Purpose

This repository is the source of truth for the delivery-team framework, not for Rowan's personal OpenClaw workspace identity.

It is intended to:
- define reusable agent roles
- define reusable skills for software delivery workflows
- capture workflow contracts and policies
- support a dev -> review -> deploy model
- allow a stable active deployment copy to be promoted from reviewed GitHub changes

## Operating model

- `main` is the approved framework baseline.
- All ongoing changes should use feature branches + pull requests.
- A separate active deployment copy should be synced from reviewed commits on `main`.
- Rowan's own OpenClaw identity and memory files are intentionally out of scope for this repository.

## Repo boundary

This repository is for the delivery-agent framework only.

Included here intentionally:
- delivery agent role definitions
- reusable skills and templates
- delivery architecture and operating-model docs
- repo-management policy and operating model
- project bootstrap assets for downstream repos
- deployment manifests and sync tooling for this framework

Excluded intentionally:
- Rowan's local `SOUL.md`, `IDENTITY.md`, `USER.md`, `MEMORY.md`, `AGENTS.md`, `TOOLS.md`, and heartbeat state
- local OpenClaw runtime metadata
- private memory and chat continuity files

## Layout

- `agents/` role definitions for the delivery team
- `skills/` reusable skills the team can invoke
- `workflows/` multi-agent workflow definitions
- `policies/` governance and safety rules
- `templates/` reusable text artifacts
- `deploy/` sync/deploy rules and scripts
- `schemas/` shared JSON schemas
- `tests/` light validation fixtures and examples
- `docs/` design notes and repo conventions
- runtime bundle generation for deployed archetype sessions
- `repo-templates/` downstream project GitHub templates
- `scripts/bootstrap-project-repo.sh` bootstrap helper for downstream repos
- repo-level governance for `SPEC.md`, semantic commit conventions, agent-visible identity attribution, and GitHub-renderable markdown posting

## Initial scope

This first version establishes:
- core roles: orchestrator, builder, spec, qa
- three starter reusable skills: github-prs, commit-messages, releases
- baseline workflows for feature, bugfix, and release
- a deploy manifest to distinguish managed vs local files
- a sync script stub for promoting reviewed framework versions

## Future direction

Recommended deployment model:
1. edit in a working copy
2. review via GitHub PRs
3. merge to `main`
4. sync to a staging copy
5. validate
6. promote to active deployment
