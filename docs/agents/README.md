# Agent Reference Docs

This directory contains human-readable reference docs for active agent roles and subordinate roles.

## Canonical vs reference

- `agents/` is the canonical runtime source for top-level named-agent definitions used by deployment, runtime bundles, and framework validation.
- `docs/agents/` is the explanatory reference layer for humans.
- `docs/proposal/` is where design briefs, reviews, and not-yet-enforced proposals now live.

## Current contents

- top-level role reference docs such as `orchestrator.md`, `spec.md`, `security.md`, `release-manager.md`, `builder.md`, `qa.md`, and `triage.md`
- subordinate-role reference docs such as `spec-architect.md`

## Important boundary

Files in this directory should describe active framework behavior or subordinate reference material.
Proposal or future-state documents should live under `docs/proposal/` instead.

`spec-architect.md` documents a subordinate architecture sub-agent that supports Spec.
It is not a top-level archetype and should not be treated as part of the seven-agent runtime topology.

If a subordinate role needs a reusable spawnable prompt, that prompt should live under `agents/specialists/`.
