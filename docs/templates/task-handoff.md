# Task Handoff Template

Use this when Orchestrator hands a task to Builder.

## Task Identity

- Issue: 
- Title: 
- Priority: 
- Task ID: 

## Why This Task Is Ready

- Clear problem statement: yes / no
- Scope defined: yes / no
- Acceptance criteria defined: yes / no
- Assumptions documented: yes / no
- Dependencies understood: yes / no

## Required Context

- Spec links:
- Architecture links:
- Repo/docs links:
- Related issues/PRs:

## Expected Deliverable

- PR expected: yes / no
- Docs update expected: yes / no
- Tests expected: yes / no

## Callback Contract

Worker must report back to the Orchestrator with:
- Task ID / issue handled
- Worker identity
- Outcome: `DONE`, `BLOCKED`, `FAILED`, or `NEEDS_REVIEW`
- Branch name
- PR link or artifact link, if created
- Tests/checks run
- Blockers / assumptions / risks
- Recommended next action

## Constraints

- 
- 

## Escalation Rules

Escalate back to Spec via Orchestrator if:
- acceptance criteria are insufficient to determine correct behavior
- implementation requires a project-level assumption
- the task is larger than stated or needs decomposition
- architecture or interface decisions materially exceed current issue scope
