# Managed Named-Agent Workspace Files

## Purpose

Define the first practical set of named-agent workspace files that should be managed from the reviewed framework deployment.

## Managed files

For each named-agent workspace, deployment writes:
- `AGENTS.md`
- `SOUL.md`
- `USER.md`
- `IDENTITY.md`
- `FRAMEWORK_RUNTIME_BUNDLE.md`
- `FRAMEWORK_NOTES.md`
- `FRAMEWORK_DEPLOYMENT.json`

## Why these files

These files create a startup/bootstrap path that points the named agent at the reviewed active framework bundle and explicitly documents that a fresh session is required to pick up updates.

## Important note

This is a practical first pass, not a final proof that every one of these files is consumed equally by the runtime.
The goal is to ensure that the files most plausibly involved in startup/bootstrap are aligned and that the workspace clearly points at the active framework bundle.

## Reload model

After these files are updated, start a fresh named-agent session to pick up the new behavior.
