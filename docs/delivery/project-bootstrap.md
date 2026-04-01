# Project Bootstrap Procedure

## Purpose

This document defines how to initialize a new software project repository so it fits the agentic delivery operating model.

The goal is to ensure every new project starts with:
- a clear specification path
- consistent GitHub templates
- visible backlog structure
- documented assumptions
- reviewable delivery workflow

## Bootstrap principle

A new project should not begin with implementation first.
It should begin with enough structure that humans and agents can reason about it clearly.

## Bootstrap phases

### Phase 1: Create or identify the project repository

Each project should have its own GitHub repository.

The repository becomes the execution space for:
- code
- issues
- PRs
- repo docs
- wiki content

## Phase 2: Install repo templates

Copy the reusable templates from this workspace into the new project repo:

- `repo-templates/.github/ISSUE_TEMPLATE/spec-task.md` -> `.github/ISSUE_TEMPLATE/spec-task.md`
- `repo-templates/.github/ISSUE_TEMPLATE/architecture-decision.md` -> `.github/ISSUE_TEMPLATE/architecture-decision.md`
- `repo-templates/.github/ISSUE_TEMPLATE/bugfix-task.md` -> `.github/ISSUE_TEMPLATE/bugfix-task.md`
- `repo-templates/.github/pull_request_template.md` -> `.github/pull_request_template.md`

Customize only where the project genuinely needs different wording or checks.

## Phase 3: Create GitHub labels

Create the standard labels used by the delivery system:

### Issue type labels
- `feature`
- `bug`
- `change`
- `chore`
- `docs`
- `investigation`

### Workflow/state labels
- `spec-needed`
- `architecture-needed`
- `ready-for-build`
- `in-build`
- `in-review`
- `needs-clarification`
- `blocked`
- `done`

### PR labels
- `needs-spec-review`
- `needs-qa`
- `changes-requested`
- `ready-to-merge`

These labels form the lightweight operational state model for Orchestrator.

## Phase 4: Initialize project documentation

Create initial documentation in the repo and/or wiki.

Recommended initial docs:
- project overview
- initial problem statement
- scope and non-goals
- architecture overview or architecture placeholder
- contribution/development notes if relevant

Minimum expectation:
A human reviewer should be able to understand what the project is for and where the current truth lives.

## Phase 5: Create initial specification artifacts

The Spec agent should produce:
- an initial project spec
- an assumption log or documented assumptions section
- initial architecture notes if needed
- an initial backlog broken into small deliverable chunks

These should be visible through the repo docs, wiki, and issues.

## Phase 6: Human review gate

Before backlog activation, Patrick reviews:
- project spec
- architecture direction
- initial backlog
- important assumptions

Until this review happens, the project should not move into active implementation except for explicitly approved spikes.

## Phase 7: Create initial issues

The first issues should usually include:

1. project specification / refinement issue
2. architecture exploration issue (if needed)
3. first implementation-ready backlog slice
4. tooling/setup issue if bootstrapping infrastructure is required
5. documentation issue if key docs are still missing

Do not create a giant pile of vague issues just to feel productive.
Small, clear, sequenced backlog is better.

## Phase 8: Confirm the first buildable issue

Before Builder starts, confirm at least one issue is truly ready for build by checking:
- problem statement exists
- scope is constrained
- acceptance criteria are visible
- assumptions are documented
- blockers are known
- docs/links are present where needed

If not, return it to Spec.

## Suggested repo layout

This varies by tech stack, but the repo should at least make room for:
- `.github/`
- `docs/` or equivalent documentation area
- source code
- tests

If a wiki is used, keep the repo docs and wiki responsibilities clear.

## Project readiness checklist

A project is considered bootstrapped when:
- [ ] Repository exists
- [ ] GitHub templates installed
- [ ] Standard labels created
- [ ] Initial project docs created
- [ ] Initial spec exists
- [ ] Initial assumptions documented
- [ ] Initial backlog exists
- [ ] Human review of spec/backlog completed
- [ ] At least one issue meets definition of ready

## Responsibilities during bootstrap

### Orchestrator
- starts the bootstrap flow
- keeps it moving
- ensures the first ready issue is real

### Spec
- owns the spec/backlog/doc initialization
- records assumptions
- coordinates architecture exploration if required

### Architecture sub-agent
- supports early design decisions where uncertainty is material

### Builder
- does not begin normal implementation until a ready issue exists
- may assist with repo setup only if explicitly assigned and scoped

### QA
- usually enters once PR-based work begins, though early review of quality gates may still be useful

## Anti-patterns

Avoid:
- starting implementation from chat-only understanding
- skipping labels/templates because "we'll sort it out later"
- creating epic-sized issues without decomposition
- burying assumptions in agent memory only
- activating a backlog without human review of spec and task breakdown

## Summary

Project bootstrap is the moment where a vague project idea becomes a structured delivery space.
If done properly, every later agent action becomes easier to audit, review, and recover.
