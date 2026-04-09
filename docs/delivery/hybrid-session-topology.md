# Hybrid Archetype Session Topology

## Purpose

Define the recommended runtime session model for the delivery archetypes.

## Recommended topology

### Persistent per-project sessions
Use one long-lived session per project for:
- Orchestrator
- Spec
- Security
- Release Manager

### Ephemeral per-task sessions
Use fresh task-scoped sessions for:
- Builder
- QA

## Why this split exists

### Orchestrator benefits from continuity
Orchestrator needs continuity for:
- active work lanes
- backlog flow
- blocked decisions
- routing state
- mergeability coordination

### Spec benefits from continuity
Spec needs continuity for:
- project definition
- assumptions
- wiki structure and content
- `SPEC.md`
- architecture direction
- issue-readiness standards

### Builder benefits from clean context
Builder should usually work with clean context per issue or spike so that:
- scope stays tight
- branch discipline stays clean
- assumptions do not bleed across tasks
- implementation remains issue-focused

### QA benefits from scoped review context
QA should usually review with context scoped to the current PR or delivery slice so quality judgment stays tied to evidence rather than stale session context.

### Security benefits from continuity
Security needs continuity for:
- threat models
- accepted risks
- trust-boundary context
- recurring security findings across multiple changes

### Release Manager benefits from continuity
Release Manager needs continuity for:
- active release state
- beta and rc iteration history
- release blockers
- publication notes and next-release planning

## Session naming guidance

### Persistent sessions
Use stable project-scoped names such as:
- `session:musical-statues-orchestrator`
- `session:musical-statues-spec`
- `session:musical-statues-security`
- `session:musical-statues-release-manager`

### Ephemeral sessions
Use task-scoped labels such as:
- `musical-statues-builder-issue-2`
- `musical-statues-builder-issue-4`
- `musical-statues-qa-pr-7`

## Override rule

This is the default topology, not an absolute law.
The human operator may explicitly direct a different session shape when needed.

## Runtime contract

When independent archetype sessions are spawned:
- Orchestrator and Spec should target persistent project sessions by default where the surface/runtime supports it
- Security and Release Manager should also target persistent project sessions by default where the surface/runtime supports it
- Builder and QA should spawn fresh sessions by default
- all of them should consume the active deployed runtime bundles
- Builder and QA may use ephemeral specialist subagents internally for narrow task slices

See also:
- `docs/delivery/named-agent-specialist-model.md`
