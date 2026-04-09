# Named Agent Routing Policy

## Core rule
When a project-scoped named agent exists for a top-level delivery role, it has routing precedence over generic role-shaped subagents.

## Orchestrator rule
Orchestrator must route top-level role work to the corresponding project-scoped named agent when available.

That includes:
- Spec work -> `spec-<project-slug>`
- Security work -> `security-<project-slug>`
- Release coordination -> `release-manager-<project-slug>`
- Builder coordination work -> `builder-<project-slug>`
- QA review ownership -> `qa-<project-slug>`

## Subagent rule
Generic subagents may support the owning named agent, but they do not replace the owning named agent when it exists.

## Why this matters
This avoids silent drift away from the intended architecture, where top-level roles are stable named agents and subagents are narrow helpers rather than substitutes.
