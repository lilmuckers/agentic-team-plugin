# Named Agent Routing Precedence

## Purpose

Define the routing rule that top-level project-scoped named agents must be used as the primary delivery targets when they exist.

## Core rule
If a project-scoped named agent exists for a top-level role, Orchestrator should route to that named agent first.

Examples:
- Orchestrator -> `spec-<project-slug>`
- Orchestrator -> `security-<project-slug>`
- Orchestrator -> `release-manager-<project-slug>`
- Orchestrator -> `builder-<project-slug>`
- Orchestrator -> `qa-<project-slug>`

## Not allowed
Orchestrator should not substitute a generic role-shaped ephemeral subagent for a top-level named role when the project-scoped named agent for that role exists and is available.

Examples of incorrect behavior:
- routing spec work to a generic Spec-style subagent instead of `spec-<project-slug>`
- routing security review ownership to a generic security-shaped subagent instead of `security-<project-slug>`
- routing release coordination to a generic release-shaped subagent instead of `release-manager-<project-slug>`
- routing build coordination work to a generic Builder-style subagent instead of `builder-<project-slug>`
- routing top-level review ownership to a generic QA-style subagent instead of `qa-<project-slug>`

## Allowed use of subagents
Subagents are still appropriate when:
- the owning named agent spawns narrow specialists beneath itself
- no project-scoped named agent exists for the needed top-level role
- the task is an explicitly narrow helper task rather than top-level role ownership

## Why this rule exists
This preserves:
- continuity
- accountability
- inspectability
- correct ownership of project truth, build coordination, and review decisions
