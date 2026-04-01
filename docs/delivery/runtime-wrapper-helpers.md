# Runtime Wrapper Helpers

## Purpose

Provide small runtime-oriented helpers that make active deployed framework bundles easier to consume consistently.

These helpers establish a standard wrapper layer around the active runtime contract. A direct archetype-session spawn helper layer can now prepare payloads for independent sessions from the deployed bundles.

## Included helpers

### `scripts/get-runtime-bundle-path.sh`
Resolve the active runtime bundle path for a given archetype.

Examples:
```bash
scripts/get-runtime-bundle-path.sh orchestrator
scripts/get-runtime-bundle-path.sh spec
```

### `scripts/preview-runtime-bundle.sh`
Preview the current active runtime bundle for inspection/debugging.

Examples:
```bash
scripts/preview-runtime-bundle.sh orchestrator
scripts/preview-runtime-bundle.sh builder 80
```

### `scripts/spawn-archetype-session.sh`
Produce a standard wrapper summary for how a live archetype ACP session should be started against the active runtime bundle and a task file.

Example:
```bash
scripts/spawn-archetype-session.sh orchestrator task.md
```

## Contract

When live archetype work is initiated, the runtime wrapper should point at:
- `.active/framework/.runtime/<archetype>.md`

not at the mutable development working copy.

## Why this layer matters

This gives us:
- a consistent runtime lookup path
- easier debugging of what bundle is active
- a clean handoff point for later direct OpenClaw/ACP integration

## Direct spawn layer

See also:
- `docs/delivery/direct-session-spawn-model.md`

This next layer prepares direct independent-session payloads from the deployed active bundles.
