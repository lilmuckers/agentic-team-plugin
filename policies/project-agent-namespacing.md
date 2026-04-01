# Project Agent Namespacing Policy

## Core rule
Named delivery agents should be created per project namespace rather than shared globally across unrelated projects.

Preferred pattern:
- `orchestrator-<project-slug>`
- `spec-<project-slug>`
- `builder-<project-slug>`
- `qa-<project-slug>`

## Rationale
This avoids context bleed between projects and keeps the continuity of each named agent attached to a single project domain.

## Builder execution rule
The top-level project-scoped Builder agent is a coordination and integration layer, not the primary implementation worker.

Top-level Builder should:
- interpret the issue
- define the implementation slice
- choose specialist Builder subagents
- integrate outputs into a coherent branch/PR recommendation

Actual build/delivery work should happen in ephemeral Builder subagents by default.

## QA execution rule
QA may use ephemeral specialist subagents for narrow review slices, but the top-level project-scoped QA agent remains accountable for the review outcome.

## Override rule
The human operator may explicitly authorize a different isolation model, but the default framework behavior should follow project-scoped named-agent namespaces.
