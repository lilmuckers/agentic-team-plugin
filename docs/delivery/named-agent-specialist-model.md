# Named-Agent and Specialist-Subagent Model

## Purpose

Define how named OpenClaw agents and ephemeral specialist subagents should work together in the delivery framework.

## Top-level named agents

The top-level delivery archetypes should be represented as project-scoped named agents:
- `orchestrator-<project-slug>`
- `spec-<project-slug>`
- `security-<project-slug>`
- `release-manager-<project-slug>`
- `builder-<project-slug>`
- `qa-<project-slug>`

These are the durable roles humans reason about and direct within one project namespace.

## Specialist subagents

Specialist subagents are ephemeral helpers used inside a named agent's task flow.
They are disposable, narrow, and subordinate.

They should not be treated as first-class governance roles.

Templates for reusable specialists live in `agents/specialists/`. The spawning agent must choose a template, add a task-specific refinement, and run `scripts/prepare-specialist-spawn.py` before spawning. Templates are starting points, not ready-to-run prompts.

## Recommended usage by archetype

### Orchestrator
Use specialist subagents sparingly.

Appropriate uses:
- status synthesis
- dependency analysis
- narrow planning support

Orchestrator should primarily coordinate named archetypes rather than hide work inside many subagents.

### Spec
Spec may use specialist subagents for:
- library/framework evaluation
- technical option comparison
- UX design
- visual design
- migration/scoping analysis

Spec remains the owner of project truth, assumptions, and readiness decisions.

### Builder
Builder is the primary consumer of specialist subagents.

The top-level project-scoped Builder agent should not do the actual implementation work directly by default.
Instead, it should supervise and integrate specialist Builder subagents.

Typical specialist types:
- frontend-ui
- backend-integration
- api-design
- typescript-engineer
- python-engineer
- test-harness
- CI/container

Builder remains accountable for the issue, the branch, the PR, and the integrated delivery output.

### Security
Security may use specialist subagents for:
- threat modelling
- dependency auditing
- focused security verification

Security remains accountable for security requirements, security findings, and `security-approved` decisions.

### Release Manager
Release Manager may use specialist subagents sparingly for:
- release note drafting
- CI/CD and packaging review
- deployment environment checks

Release Manager remains accountable for release state, tag progression, and final GitHub release publication.

### QA
QA may use specialist subagents for:
- regression analysis
- edge-case/race-condition review
- docs/setup verification
- usability review
- CI/check interpretation

QA remains accountable for the review outcome.

## Authority boundaries

### Named agents own
- project truth and scope decisions (Spec)
- routing and conflict resolution (Orchestrator)
- security sign-off and threat-model continuity (Security)
- release state and publication flow (Release Manager)
- implementation delivery (Builder)
- review outcomes (QA)

### Specialist subagents do not own
- project truth
- final scope decisions
- mergeability decisions
- review authority
- policy or workflow overrides

They contribute focused work only.

## Default lifecycle model

- Orchestrator -> persistent per-project named session where supported
- Spec -> persistent per-project named session where supported
- Security -> persistent per-project named session where supported
- Release Manager -> persistent per-project named session where supported
- Builder -> task-scoped named-agent execution
- QA -> review-scoped named-agent execution
- Specialist subagents -> ephemeral and narrow by default

## Why this split exists

This model keeps:
- the human-facing delivery structure clean
- accountability attached to the top-level named agents
- narrow technical work delegable without turning every specialist into a governance center
