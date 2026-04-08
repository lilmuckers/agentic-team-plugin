# Spec Process Policy

## Core rule
New feature specification is a conversational process before it becomes a committed record.

## Required flow
1. Clarify the problem, user, and constraints.
2. Present options or tradeoffs where they matter.
3. Reach explicit agreement on the intended direction.
4. Commit the resulting agreement into `SPEC.md`, linked issues, and any supporting docs.

## Required SPEC.md sections for user-facing work
When a feature has user-facing elements that materially affect usability or presentation, `SPEC.md` must include:
- `## User Flows`
- `## Usability Requirements`
- `## Design Direction`
- `## Test Strategy`
- `## Acceptance Criteria`

## Specialist involvement
When user-facing decisions materially affect the outcome, Spec must involve the `ux-designer` specialist and, when visual direction is materially affected, the `visual-designer` specialist.

Minor UI copy tweaks or trivial layout changes do not require specialist involvement.

## Approval rule
The committed `SPEC.md` is the durable record of what was agreed. If the conversation and the file diverge, the file must be corrected before work proceeds.
