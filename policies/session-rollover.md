# Session Rollover Policy

## Core rule
When managed named-agent workspace bootstrap files are changed, the updated behavior should be considered live only after a **new session** is started for that named agent.

## Why this exists
The runtime appears to load key workspace files at session/bootstrap time rather than hot-reloading arbitrary file changes into already-running named-agent sessions.

## Practical model
1. deploy reviewed framework updates into the managed named-agent workspaces
2. record the deployed SHA in `FRAMEWORK_NOTES.md`
3. run `scripts/check-framework-version.sh` at session start to detect stale sessions
4. start a fresh session for the affected named agent
5. treat the new session as the activation boundary for the updated framework behavior

## Implication
Do not assume that editing `SOUL.md`, `AGENTS.md`, or related startup files in a named-agent workspace will immediately affect an already-running session.

A stale session is defined by policy change, not by elapsed time alone: if files under `agents/`, `policies/`, or `skills/` changed since the SHA recorded at session load, the session should surface that mismatch before taking new work.
