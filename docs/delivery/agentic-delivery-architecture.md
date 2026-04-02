# Agentic Programming Delivery Architecture

## Purpose

This document defines an OpenClaw-based delivery architecture for software projects using a small set of persistent archetype agents, GitHub as the human-reviewable system of record, and task-scoped specialist sub-agents only where they add real value.

The goal is to create a delivery system that is:
- human-reviewable
- auditable
- resilient to context loss
- disciplined about assumptions
- capable of parallel execution without losing end-to-end accountability

## Core principles

1. **GitHub is the shared context space**
   Durable shared context must live in GitHub-visible artifacts, not only in chat transcripts or private agent context.

   The system of record is:
   - repository codebase
   - issues
   - pull requests
   - repository documentation
   - GitHub wiki

2. **Persistent agents should be few**
   Use a small number of long-lived agents with stable authority boundaries.
   Do not create many permanent peer specialists by default.

3. **Specialists are spawned only when justified**
   The Builder may spawn focused, task-specific specialist sub-agents when a task benefits from narrower domain expertise or parallel exploration.

4. **Spec owns assumptions**
   Project-level assumptions and scope-level clarifications are owned by the Spec agent.
   They must be written into documentation and/or GitHub artifacts.

5. **Builder owns delivery, not product truth**
   The Builder implements approved backlog items and may make narrow technical choices, but does not silently redefine product behavior or scope.

6. **PRs are the QA and review envelope**
   Code review, QA, and implementation discussion should happen in pull requests.

7. **Human review is required for project specification and backlog formation**
   A human remains in the loop for creation and approval of the project spec, architecture direction, and task backlog.

## Persistent agent hierarchy

```text
Patrick
  └── Orchestrator
        ├── Spec Agent
        │     └── Architecture Sub-Agent
        ├── Builder
        │     └── Task-Specific Specialist Sub-Agents
        └── QA / Reviewer
```

## Agent roles

### 1. Orchestrator

The Orchestrator is the front door, delivery coordinator, and active foreman.

Responsibilities:
- intake of new work
- routing work to the correct agent
- ensuring backlog items are small and deliverable
- ensuring issues meet the definition of ready before implementation begins
- assigning ready work to Builder
- maintaining a ledger of in-flight delegated tasks
- requiring completion/blocker callbacks from delegated workers
- summarizing status, risks, and blockers
- preventing uncontrolled scope drift

The Orchestrator is the default agent that talks to Patrick.
Specialists and named agents report to the Orchestrator, not directly to Patrick, unless explicitly requested.

The Orchestrator should **not** perform major implementation work directly.
It should behave like a Ralph-style coordinator: active, callback-driven, and responsible for deciding the next action whenever a worker returns state.

### 2. Spec Agent

The Spec agent owns the project specification and task decomposition.

Responsibilities:
- create and maintain the project specification
- turn large requests into small deliverable backlog items
- define acceptance criteria
- define scope boundaries and non-goals
- make project-level assumptions when clarification is required
- document assumptions, decisions, and clarifications in GitHub-visible places
- maintain relevant repository docs and wiki content
- refine issues so they are implementation-ready

Authority:
- owns project-level assumptions
- owns clarification of ambiguous backlog items
- may request architectural exploration through its Architecture sub-agent

### 3. Architecture Sub-Agent

The Architecture sub-agent is a subordinate of the Spec agent.

Responsibilities:
- explore candidate architectures
- analyze tradeoffs
- propose component boundaries
- define interfaces and data flows
- generate architecture notes or ADR-style decision records
- identify architectural risks and migration considerations

Authority:
- advisory to Spec
- does not directly assign work
- does not override Spec
- does not own final project scope

### 4. Builder

The Builder owns implementation delivery for approved backlog items.

Responsibilities:
- implement approved issues
- create branches, commits, and pull requests
- link implementation to the relevant issue(s)
- maintain coherence across code changes
- request clarification when issue scope is ambiguous
- optionally spawn focused specialist sub-agents when justified
- ensure implementation notes and deviations are visible in the PR

Authority:
- owns execution of implementation tasks
- may make local technical choices needed for delivery
- may decide whether specialist sub-agents are required
- may not redefine accepted scope, product behavior, or project-level assumptions

### 5. QA / Reviewer

The QA / Reviewer agent owns verification through the PR process.

Responsibilities:
- review pull requests against the issue and spec
- verify acceptance criteria
- evaluate test coverage and quality signals
- identify regressions, edge cases, maintainability issues, and missing documentation
- request changes or approve as appropriate

Authority:
- may block PRs pending required changes
- does not redefine project scope
- escalates ambiguous acceptance criteria back to Spec through Orchestrator

## Builder specialist sub-agents

### Role of specialist sub-agents

The Builder may spawn task-specific specialist sub-agents to keep capability focused where it materially improves delivery quality.

These specialists are normally **ephemeral, task-scoped sessions**, not permanent top-level agents.

Examples:
- JavaScript frontend specialist
- visual design specialist
- Java Spring Boot specialist
- iOS Swift specialist
- database/schema specialist
- infrastructure/devops specialist
- test automation specialist

### Why they are subordinate to Builder

Specialists support delivery but should not fragment ownership.
The Builder remains accountable for the end-to-end outcome.

This prevents:
- ownership confusion
- excessive coordination overhead
- domain silos with no integrator
- delivery by committee

### When Builder should spawn a specialist

Builder should consider spawning a specialist when:
- a task requires deep platform or framework conventions
- a clear separable subproblem exists
- the task spans multiple domains and parallel exploration is helpful
- the reduced context scope improves quality or speed

Builder should not spawn specialists merely because:
- a task touches multiple technologies superficially
- a specialist title exists
- the architecture would look more impressive on paper

### Specialist authority boundaries

Specialist sub-agents:
- may propose implementation details within their domain
- may produce code, recommendations, or focused plans
- may recommend UI, platform, or technical refinements
- do **not** own product assumptions
- do **not** change scope unilaterally
- do **not** redefine acceptance criteria

If a specialist surfaces a project-level ambiguity, that ambiguity must go back through Builder to Orchestrator and then to Spec.

## Shared context model

### GitHub as source of truth

All material shared context for the project should live in GitHub-visible artifacts so that humans can audit and review it.

Use GitHub artifacts as follows:

#### GitHub Issues
Use for:
- backlog items
- deliverable task chunks
- acceptance criteria
- task-local assumptions
- blockers and dependencies
- links to relevant wiki/repo docs
- open questions needing clarification

#### Pull Requests
Use for:
- implementation discussion
- QA and review comments
- tests/checks status
- implementation notes
- documented deviations from issue/spec
- merge decisions

#### GitHub Wiki
Use for:
- evolving project specification
- high-level architecture descriptions
- architectural rationale
- domain concepts
- design notes that benefit from broader visibility

#### Repository Documentation
Use for:
- versioned technical documentation close to the code
- setup and operational docs
- API or module documentation
- implementation-coupled references
- long-lived docs that should evolve with the codebase

#### Codebase
Use for:
- the implementation itself
- tests
- executable truth of the system behavior

## Human-in-the-loop checkpoints

Human review is required for:
- initial project specification
- architecture direction
- initial backlog and task decomposition
- significant changes to scope
- major architecture pivots
- other high-risk approval points defined by the project

This means the system should not autonomously create a project backlog and begin implementation without review of the spec and task list.

## Delivery workflow

The delivery workflow is callback-driven.
Named agents and subordinate specialists do not merely act on artifacts and go quiet; they must return their outcome to the Orchestrator so coordination can continue without waiting for periodic nudges.

### Phase 1: project definition and backlog formation

1. Patrick provides a project request or objective.
2. Orchestrator routes the work to Spec.
3. Spec may invoke the Architecture sub-agent for design exploration.
4. Spec produces:
   - project spec draft
   - architecture notes/design artifacts
   - backlog of discrete small deliverable chunks
   - documented assumptions
   - acceptance criteria
5. Patrick reviews the spec and backlog.
6. Spec updates based on review.
7. Approved backlog items become candidates for implementation.

### Phase 2: implementation loop

For each approved backlog item:

1. Orchestrator selects a backlog item that meets the definition of ready.
2. Orchestrator assigns the item to Builder.
3. Builder may spawn specialist sub-agents where justified.
4. Builder implements the issue and opens a PR.
5. QA / Reviewer performs review in the PR.
6. If ambiguity or scope clarification arises:
   - the issue is routed back to Spec via Orchestrator
   - Spec updates assumptions/docs/issues as needed
7. Builder updates the PR.
8. QA approves or requests further changes.
9. Once approved, the change is merged according to repository policy.

## Assumption policy

### Spec-owned assumptions

Spec owns:
- project-level assumptions
- business-rule assumptions
- behavior-defining clarifications
- scope decisions
- documented tradeoff decisions that affect future work planning

These must be recorded in GitHub-visible documentation, issues, wiki pages, repo docs, or PR discussions where appropriate.

### Builder-owned local technical choices

Builder may make narrow local technical decisions needed to proceed, such as:
- function naming
- internal code organization
- local refactoring structure
- implementation-specific patterns that do not change behavior or scope

If such choices materially affect behavior, interfaces, developer workflow, or future extensibility, they must be surfaced in the PR and, if project-level, escalated back to Spec.

## Definition of Ready

An issue is ready for Builder when it has:
- a clear problem statement
- defined scope boundaries
- acceptance criteria
- explicit assumptions or links to them
- dependencies or blockers noted
- relevant documentation links where needed
- enough clarity that implementation does not require silent product decisions

If these conditions are not met, Orchestrator should route the item back to Spec instead of assigning it.

## Definition of Done

A task is done when:
- implementation is completed
- tests/checks are appropriate for the level of risk
- the PR links back to the issue
- acceptance criteria are satisfied or explicit deviations are documented
- required review/QA has been completed
- docs are updated if the change affects behavior, architecture, or developer operations

## Recommended GitHub workflow conventions

### Issue labels

Suggested labels:
- `spec-needed`
- `architecture-needed`
- `ready-for-build`
- `in-build`
- `in-review`
- `needs-clarification`
- `blocked`
- `done`

### PR labels

Suggested labels:
- `needs-spec-review`
- `needs-qa`
- `changes-requested`
- `ready-to-merge`

### Linking conventions

Each PR should:
- reference the issue it implements
- summarize any implementation deviations
- note any assumptions made during implementation
- link to relevant spec/architecture docs where useful

## OpenClaw implementation guidance

### Persistent agents to create first

Start with these persistent agents:
- Orchestrator
- Spec
- Builder
- QA

Use an Architecture sub-agent under Spec as needed.
Use Builder specialist sub-agents as needed.

### Why not many permanent specialists from day one

Avoid creating many permanent specialist peer agents initially.
That usually creates unnecessary coordination complexity before there is evidence it is needed.

Instead:
- keep persistent authority simple
- use specialist prompts/roles as a reusable library
- spawn them only for tasks that clearly benefit

If repeated usage proves that a specialist is effectively permanent and heavily utilized, it can later be promoted into a more durable role.

## Anti-patterns to avoid

- letting Builder silently invent project-level product assumptions
- allowing specialists to become de facto product owners
- using chat transcripts as the only durable context
- creating oversized backlog items that are not independently deliverable
- sending many agents directly to Patrick with overlapping updates
- using many peer specialists without a single accountable Builder/integrator

## Summary

This architecture intentionally biases toward:
- durable GitHub-visible context
- small persistent authority structure
- explicit ownership of assumptions
- human approval of spec and backlog
- PR-centric implementation review
- selective specialist depth without fragmenting accountability

That keeps the system auditable, practical, and less likely to disappear into autonomous confusion.
