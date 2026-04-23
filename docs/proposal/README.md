# Proposal and Review Docs

This directory is the holding area for framework material that is not part of the active implemented documentation set.

Use it for:
- design briefs kept for history after implementation
- future-state proposals that are not yet enforced in runtime/tooling
- review documents containing recommendations, critiques, or roadmap-level cleanup ideas

## Status index

| Proposal doc | Status | Active documentation / notes |
|---|---|---|
| `triage-agent.md` | Implemented and documented | Active docs now live at `agents/triage.md`, `docs/agents/triage.md`, `docs/delivery/triage-tooling-helpers.md`, and `policies/named-agent-routing.md`. Keep this file as historical design context only. |
| `action-taxonomy.md` | Partially implemented | The future unified event model is still proposal-only. The currently implemented helper-backed auditability surface is documented at `docs/delivery/action-taxonomy.md`. |
| `schemas/` | Proposal only | These schemas describe the future structured event layer and are not enforced runtime contracts yet. |
| `framework-workflow-review.md` | Partially implemented | Several recommendations have landed, including explicit project activation gates, seven-agent topology including Triage, and cleaner active-versus-proposal doc boundaries. Remaining content is still review/recommendation material. |

## Current contents

- `triage-agent.md` — historical design brief for Triage. Triage itself is implemented; the active docs are `agents/triage.md` and `docs/agents/triage.md`.
- `action-taxonomy.md` — future structured event/auditability model. The currently implemented auditability surface is documented in `docs/delivery/action-taxonomy.md`.
- `schemas/` — proposal-layer schema artifacts for the future action taxonomy.
- `framework-workflow-review.md` — review and recommendation document, not canonical behavioral truth.

## Boundary

If a document describes current implemented behavior, keep it in the normal active docs tree.
If a document describes a future design, a recommendation set, or a historical design brief, keep it here.
