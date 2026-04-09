# Agent Reference Docs

This directory contains human-readable reference docs for agent roles and subordinate roles.

## Canonical vs reference

- `agents/` is the canonical runtime source for top-level named-agent definitions used by deployment, runtime bundles, and framework validation.
- `docs/agents/` is the explanatory reference layer for humans.

## Current contents

- top-level role reference docs such as `orchestrator.md`, `spec.md`, `security.md`, `release-manager.md`, `builder.md`, and `qa.md`
- subordinate-role reference docs such as `spec-architect.md`

## Important boundary

`spec-architect.md` documents a subordinate architecture sub-agent that supports Spec.
It is not a seventh top-level archetype and should not be treated as part of the six-agent runtime topology.

If a subordinate role needs a reusable spawnable prompt, that prompt should live under `agents/specialists/`.
