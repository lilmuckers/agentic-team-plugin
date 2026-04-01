# Named-Agent and Specialist-Subagent Model

## Purpose

Define how named OpenClaw agents and ephemeral specialist subagents should work together in the delivery framework.

## Top-level named agents

The top-level delivery archetypes should be represented as named agents:
- Orchestrator
- Spec
- Builder
- QA

These are the durable roles humans reason about and direct.

## Specialist subagents

Specialist subagents are ephemeral helpers used inside a named agent's task flow.
They are disposable, narrow, and subordinate.

They should not be treated as first-class governance roles.

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
- architecture research
- library/framework evaluation
- migration/scoping analysis
- technical option comparison

Spec remains the owner of project truth, assumptions, and readiness decisions.

### Builder
Builder is the primary consumer of specialist subagents.

Typical specialist types:
- frontend-ui
- backend-integration
- spotify/auth integration
- visualization/animation
- test-harness
- CI/container

Builder remains accountable for the issue, the branch, the PR, and the integrated delivery output.

### QA
QA may use specialist subagents for:
- regression analysis
- edge-case/race-condition review
- docs/setup verification
- accessibility review
- CI/check interpretation

QA remains accountable for the review outcome.

## Authority boundaries

### Named agents own
- project truth and scope decisions (Spec)
- routing and conflict resolution (Orchestrator)
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
- Builder -> task-scoped named-agent execution
- QA -> review-scoped named-agent execution
- Specialist subagents -> ephemeral and narrow by default

## Why this split exists

This model keeps:
- the human-facing delivery structure clean
- accountability attached to the top-level named agents
- narrow technical work delegable without turning every specialist into a governance center
