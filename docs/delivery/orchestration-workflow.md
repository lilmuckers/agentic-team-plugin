# Orchestration Workflow

## Purpose

This document turns the delivery architecture into a concrete operating flow.

The operating model is explicitly **Ralph-like**: the Orchestrator is an active foreman, not a passive relay. Delegated agents must report back to the Orchestrator when they finish, fail, get blocked, or need review. Cron-based nudges are only a watchdog path.

## End-to-end flow

### 1. Intake

Patrick provides:
- project idea
- feature request
- bug report
- architectural change
- delivery priority update

Orchestrator classifies the request.

### 2. Specification phase

If work is not implementation-ready, Orchestrator sends it to Spec.

Spec must produce or refine:
- issue(s)
- acceptance criteria
- assumptions
- relevant docs/wiki updates

If design uncertainty is material, Spec invokes the Architecture sub-agent.

When Spec finishes, it must report back to the Orchestrator with:
- the work item handled
- visible artifacts created or updated
- whether the item is now ready, still blocked, or needs human review
- the recommended next step

### 3. Human review gate

Before a new project backlog becomes active, Patrick reviews:
- project spec
- architecture direction
- backlog/task list

Spec updates based on review.

### 4. Ready-for-build check

Orchestrator checks whether an issue meets the definition of ready.

If yes:
- label or treat it as `ready-for-build`
- assign to Builder

If no:
- return to Spec

### 5. Build phase

Builder:
- works from the issue and linked docs
- decides whether specialist sub-agents are needed
- implements the change
- opens a PR

Builder should prefer one coherent PR per issue or tightly related deliverable.

When Builder finishes or hits a problem, Builder must report back to the Orchestrator with:
- issue handled
- branch name
- PR link if created
- tests/checks run
- status: `DONE`, `BLOCKED`, `FAILED`, or `NEEDS_REVIEW`
- blockers, assumptions, and recommended next action

### 6. Review / QA phase

QA / Reviewer reviews the PR.

Possible outcomes:
- approve
- request changes
- escalate clarification need back to Spec via Orchestrator

QA and Reviewer must report their review outcome back to the Orchestrator, even when feedback is also left visibly on the PR.

### 7. Clarification loop

If the PR reveals missing project-level decisions:
- QA or Builder flags ambiguity
- Orchestrator routes to Spec
- Spec documents the clarified assumption or requirement
- issue/docs/wiki are updated as needed
- Builder updates PR accordingly

### 8. Merge / completion

Once review is complete and repository policy allows:
- PR is merged
- issue is closed or updated
- docs remain aligned with the delivered state

## Agent-specific workflow rules

### Orchestrator rules

- never assign work that fails definition of ready
- prefer small, shippable issue granularity
- keep Patrick updated concisely
- treat blocked/unclear work as a Spec problem, not a Builder improvisation problem
- maintain an explicit list or ledger of in-flight delegated tasks
- require every worker to callback on completion, blockage, failure, or review handoff
- treat missing callbacks as an exception path to investigate
- use cron/heartbeat only to watch for missed callbacks or overdue work

### Spec rules

- every meaningful assumption must be visible somewhere durable
- issues should be small enough to produce coherent PRs
- architecture exploration should feed specification, not drift off into decorative theory
- always report completion state and next-step recommendation back to the Orchestrator

### Builder rules

- if a task requires project-level assumptions, stop and escalate
- specialists are optional tools, not additional owners
- implementation notes belong in the PR if they matter to reviewers or future maintainers
- always report completion state and next-step recommendation back to the Orchestrator

### QA rules

- review the contract, not just the code style
- raise unclear acceptance criteria explicitly
- prefer concrete change requests over vague displeasure
- always report review outcome back to the Orchestrator

## Specialist spawning rules

Builder may spawn a specialist when:
- deep domain knowledge is clearly beneficial
- a subproblem can be cleanly isolated
- parallel exploration reduces delivery risk or cycle time

Builder should avoid specialist spawning when:
- the task is small enough to complete coherently alone
- the split would create more coordination cost than implementation value
- the specialist would need to invent product intent

## Suggested specialist roster

Not all are needed immediately. These are reusable specialist patterns.

- frontend/javascript
- visual-design
- backend-java-springboot
- ios-swift
- database-schema
- infrastructure-devops
- test-automation

## Workflow summary

The architecture is designed so that:
- Spec owns meaning
- Builder owns delivery
- QA owns verification
- Orchestrator owns flow
- GitHub owns durable shared context
