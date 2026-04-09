# Project-Scoped Named Agent Namespaces

## Purpose

Define the preferred naming and isolation model for named delivery agents across multiple projects.

## Core rule
Do not rely on one global `orchestrator`, `spec`, `security`, `release-manager`, `builder`, or `qa` agent to span multiple projects.

Instead, create project-scoped named agents such as:
- `orchestrator-<project-slug>`
- `spec-<project-slug>`
- `security-<project-slug>`
- `release-manager-<project-slug>`
- `builder-<project-slug>`
- `qa-<project-slug>`

## Why this matters
Named-agent continuity is valuable, but if one named agent spans multiple projects it risks context bleed.

Project-scoped agent namespaces provide:
- hard project isolation
- clearer agent/session ownership
- simpler debugging and inspection
- better alignment between project identity and agent continuity

## Recommended examples
For project slug `musical-statues`:
- `orchestrator-musical-statues`
- `spec-musical-statues`
- `builder-musical-statues`
- `qa-musical-statues`
- `security-musical-statues`
- `release-manager-musical-statues`

## Lifecycle model inside the namespace
- `orchestrator-<project>` -> stable project coordinator
- `spec-<project>` -> stable project truth/spec owner
- `security-<project>` -> stable security reviewer and sign-off owner
- `release-manager-<project>` -> stable release coordinator and publisher
- `builder-<project>` -> top-level builder coordinator
- `qa-<project>` -> top-level review coordinator

## Builder-specific rule
The top-level project-scoped Builder agent should not perform the actual delivery implementation directly.
It should:
- scope the work
- choose the right specialist subagents
- integrate their outputs
- own the issue/branch/PR context

The actual implementation work should be executed by ephemeral Builder subagents.

## QA-specific note
QA may also use ephemeral specialist subagents internally for narrow review/verification work, but QA remains accountable for the review outcome.
