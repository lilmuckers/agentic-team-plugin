# Runtime Consumption Model

## Purpose

Define how the live delivery archetype sessions consume the deployed framework.

## Source hierarchy

### Development working copy
Use for editing, branching, and pull requests.
Do not treat it as the live source of agent behavior.

### Active framework copy
The active framework copy lives under:
- `.active/framework/`

This is the reviewed deployed snapshot.
It should be the source for runtime consumption.

### Runtime bundles
Generated runtime bundles live under:
- `.active/framework/.runtime/`

These bundle the current archetype definition together with key shared policies and operating-model references.

## Runtime bundle files

Expected bundle files:
- `.active/framework/.runtime/orchestrator.md`
- `.active/framework/.runtime/spec.md`
- `.active/framework/.runtime/builder.md`
- `.active/framework/.runtime/qa.md`

## Consumption rule

When an archetype session is spawned or steered for live delivery work, it should consume the active runtime bundle for that archetype rather than reading directly from the mutable development working copy.

Examples:
- Orchestrator session -> `.active/framework/.runtime/orchestrator.md`
- Spec session -> `.active/framework/.runtime/spec.md`
- Builder session -> `.active/framework/.runtime/builder.md`
- QA session -> `.active/framework/.runtime/qa.md`

## Why this matters

This ensures:
- live behavior follows reviewed deployed framework state
- development-branch changes do not silently become runtime truth
- rollback and provenance stay possible through deployed SHAs

## Deployment metadata

Deployment metadata is recorded in:
- `.state/framework/deployed-sha.txt`
- `.state/framework/deploy-meta.txt`

This should be used to inspect what framework version is currently active.

## Next evolution

A later step may build direct runtime wrappers that automatically load the correct bundle for each archetype session.
For now, this document defines the contract: active runtime bundles are the live source of archetype guidance.
