# Recommended GitHub Labels

## Issue labels

- `spec-needed` — issue requires specification/refinement before build
- `architecture-needed` — design exploration required
- `ready-for-build` — issue satisfies definition of ready
- `in-build` — active implementation underway
- `in-review` — PR open / awaiting review or iteration
- `needs-clarification` — project-level ambiguity needs Spec input
- `blocked` — external or dependency blocker prevents progress
- `done` — task completed
- `security-scope` — issue or PR touches security-sensitive scope and requires Security participation
- `security-review-required` — PR is awaiting formal Security review before QA / merge
- `release-tracking` — release coordination issue owned by Release Manager

## PR labels

- `needs-spec-review` — PR reveals specification ambiguity or requires Spec review
- `needs-qa` — PR is ready for quality review
- `changes-requested` — review found required changes
- `ready-to-merge` — review completed and merge is appropriate
- `qa-approved` — QA has completed review and approved the PR
- `spec-satisfied` — Spec confirms project-level assumptions, docs, and intent are satisfied
- `orchestrator-approved` — Orchestrator confirms merge-gate conditions are met and merge is appropriate now
- `security-approved` — Security confirms security-scope requirements are satisfied

## Usage guidance

Labels are a lightweight control plane for Orchestrator.
Use them to make backlog state and PR state human-readable and machine-queryable enough for agents to operate consistently.

For PRs carrying `security-scope` or `security-review-required`, the merge gate should also require `security-approved`.
