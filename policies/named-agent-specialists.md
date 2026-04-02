# Named Agent and Specialist Policy

## Core rule
Top-level delivery roles should remain named agents.
Ephemeral specialist subagents may be used inside those named-agent workflows where they improve focus, quality, or speed.

## Named agents
The framework recognizes these top-level delivery roles as named agents:
- Orchestrator
- Spec
- Builder
- QA

## Specialist usage rules

### Allowed
- Builder may spawn specialist subagents for narrow implementation slices
- QA may spawn specialist subagents for narrow verification slices
- Spec may spawn specialist subagents for bounded research or option analysis
- Orchestrator may spawn narrow helpers sparingly when useful

### Not allowed
Specialist subagents must not:
- redefine project truth
- redefine project scope
- make final mergeability decisions
- overrule Orchestrator, Spec, Builder, or QA ownership
- act as hidden governance layers

## Accountability
- Orchestrator remains accountable for routing and coordination decisions
- Spec remains accountable for project-level assumptions and readiness
- Builder remains accountable for integrated delivery output
- QA remains accountable for review outcomes

All named agents and subordinate specialists must report completion, blockage, failure, or review state back through their owning coordination path, with the Orchestrator as the top-level callback owner.

## Visibility
If specialist subagents materially influence delivery, their outputs should be surfaced through the owning named agent in the appropriate visible project artifact (issue, PR, or wiki update) where relevant.

## Callback rule
The default callback path is:
- specialist subagent → owning named agent
- named agent → Orchestrator
- Orchestrator → Patrick when human attention is needed or a concise status update is warranted

Cron or heartbeat polling may be used to detect missed callbacks or overdue work, but not as the primary coordination mechanism.
