# Proposal and Review Docs

This directory is the holding area for framework material that is not part of the active implemented documentation set.

Use it for:
- design briefs kept for history after implementation
- future-state proposals that are not yet enforced in runtime/tooling
- review documents containing recommendations, critiques, or roadmap-level cleanup ideas

## Current contents

- `triage-agent.md` — historical design brief for Triage. Triage itself is implemented; the active docs are `agents/triage.md` and `docs/agents/triage.md`.
- `action-taxonomy.md` — future structured event/auditability model. The currently implemented auditability surface is documented in `docs/delivery/action-taxonomy.md`.
- `schemas/` — proposal-layer schema artifacts for the future action taxonomy.
- `framework-workflow-review.md` — review and recommendation document, not canonical behavioral truth.

## Boundary

If a document describes current implemented behavior, keep it in the normal active docs tree.
If a document describes a future design, a recommendation set, or a historical design brief, keep it here.
