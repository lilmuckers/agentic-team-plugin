# GitHub Operating Model for Agentic Delivery

## Purpose

This document defines how the delivery agents use GitHub as the shared operational context for planning, implementation, review, and documentation.

## Core rule

If a human reviewer would need to see it later, it should live in GitHub.

Chat can coordinate work, but GitHub should hold the durable, reviewable record.

## System of record by artifact type

### Issues

Issues are the backlog and task execution contract.

Each buildable issue should ideally contain:
- problem statement
- scope
- acceptance criteria
- assumptions
- blockers/dependencies
- links to related docs/wiki/PRs

Use issues for:
- project backlog items
- small deliverable chunks of work
- clarification tracking
- task decomposition
- linking implementation to planning

### Pull Requests

PRs are the implementation and QA envelope.

Use PRs for:
- code review
- quality review
- CI/test outcomes
- discussion of implementation details
- documenting implementation-level deviations
- documenting local technical assumptions that matter

PRs should reference the issue(s) they implement.

### Wiki

Use the GitHub wiki for:
- project specification
- high-level architecture
- design rationale
- evolving project guidance
- decision records where broad human visibility matters

### Repository docs

Use repository documentation for:
- versioned technical docs
- setup instructions
- runbooks
- API/module documentation
- implementation-coupled documentation

## Agent responsibilities in GitHub

### Orchestrator

Uses GitHub to:
- inspect backlog readiness
- route ready issues to Builder
- identify blocked or unclear items
- track PR progress and review status
- summarize project status

### Spec

Uses GitHub to:
- create and refine issues
- maintain project specification and architecture docs
- record assumptions and clarifications
- maintain backlog structure
- update wiki and repository docs

### Architecture sub-agent

Uses GitHub indirectly through Spec outputs:
- architecture notes
- tradeoff analyses
- candidate designs
- decision recommendations

### Builder

Uses GitHub to:
- work from approved issues
- create branches and PRs
- document implementation notes in PRs
- link changes back to backlog items
- surface deviations or ambiguity

### QA / Reviewer

Uses GitHub to:
- review PRs
- record approval or change requests
- validate acceptance criteria
- keep quality discussion attached to the code change

## Suggested issue lifecycle

1. `spec-needed`
2. `architecture-needed` (optional)
3. `ready-for-build`
4. `in-build`
5. `in-review`
6. `done`

Possible interrupt states:
- `needs-clarification`
- `blocked`

## Suggested PR lifecycle

1. opened by Builder
2. labeled `needs-qa`
3. reviewed by QA / Reviewer
4. if required, labeled `changes-requested`
5. when ready, labeled `ready-to-merge`

## Documentation rules

### Assumptions

Project-level assumptions belong in:
- issue body/comments
- wiki/spec pages
- architecture docs
- repo docs when implementation-coupled

Implementation-local assumptions that matter belong in:
- the PR description
- code comments only when truly useful
- linked docs if they affect maintainability or future contributors

### Architectural decisions

Architectural decisions should be captured somewhere visible and linkable, not buried in chat.

Preferred locations:
- wiki architecture pages
- ADR-like repo docs
- issue comments for task-scoped architectural decisions

### Acceptance criteria

Acceptance criteria should be attached to the issue, not inferred from chat.

## Review rules

- QA happens through the PR, not in an isolated private thread only.
- If implementation reveals missing product decisions, route back to Spec.
- Builder should not silently update issue intent.
- If docs need changing, the relevant docs change should be part of the same PR when practical.

## Human review points

Human review should occur before:
- backlog activation from a new project spec
- major architecture approval
- major scope changes
- other high-risk transitions defined by the project

## Practical guidance

### Keep issues small

A backlog item should ideally be small enough to become one coherent PR.
If an issue looks like an epic disguised as a task, it probably needs decomposition.

### Keep PRs coherent

A PR should usually correspond to one deliverable change or one tightly related cluster of changes.
Avoid turning one PR into a travelling circus of half the roadmap.

### Keep docs close to change

If code changes alter behavior or operational understanding, update the relevant docs at the same time.

## Summary

GitHub is not just the code host in this architecture.
It is the human-auditable shared memory and review surface for the delivery system.
