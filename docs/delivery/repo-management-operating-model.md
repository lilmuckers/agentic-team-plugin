# Repository Management Operating Model

## Purpose

Translate the delivery-framework repo-management rules into one explicit operating model that project repos can follow.

## Durable context locations

### GitHub wiki
Use the wiki for:
- product definition
- solution design
- architecture
- project-level assumptions and rationale
- decision records
- project goals and non-goals

### GitHub issues
Use issues for:
- tasks to be done
- target agent archetype labels
- acceptance criteria
- discrete scope boundaries
- visible clarification threads

### Pull requests
Use PRs for:
- implementation progress
- assumption logs
- validation status
- QA feedback
- visible discussion about delivery decisions

### ACP
Use ACP for:
- triggering another agent to inspect visible external context
- running internal multi-agent delivery work
- coordinating sub-agent execution

Do not use ACP as the only durable home of project-level decisions when an issue, PR, or wiki page should hold them.

## Branch and PR lifecycle

1. Builder starts a feature branch.
2. Builder pushes the branch as soon as there is a meaningful commit.
3. Builder opens a draft PR immediately.
4. Builder continues implementation and updates the PR with assumptions, validation, and follow-ups.
5. Builder requests review from QA and, where needed, from Spec or Orchestrator.
6. QA reviews the PR.
7. If there is disagreement, Orchestrator decides.
8. QA approval allows mergeability review, but Spec and Orchestrator decide whether the PR is ready to merge in project context.

## Assumption model

### Spec assumptions
Spec makes assumptions that affect:
- project behavior
- architecture
- scope boundaries
- cross-cutting quality thresholds

These must be documented in the wiki and referenced from issues or PRs as appropriate.

### Builder assumptions
Builder may make narrow assumptions limited to the issue being implemented.

If those assumptions affect broader project truth, Builder should escalate through an issue or PR comment and trigger Spec or Orchestrator review via ACP.

## Documentation responsibilities

### Spec
- keep wiki documentation aligned with merged behavior and project goals
- ensure assumptions and rationale remain discoverable
- keep project docs current as the project evolves

### Project README
The root `README.md` must always provide enough setup and run guidance for a new operator or contributor to get moving quickly.

## Quality baseline

Expected baseline:
- high unit test coverage
- high code quality using standard tooling
- integration tests as part of the model
- regression automation for bugs, edge cases, and race conditions where practical
- GitHub Actions workflows to run sensible checks
- backend build/test execution in Docker where practical for parity across environments
