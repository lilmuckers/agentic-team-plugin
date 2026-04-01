# Session Rollover Policy

## Core rule
When managed named-agent workspace bootstrap files are changed, the updated behavior should be considered live only after a **new session** is started for that named agent.

## Why this exists
The runtime appears to load key workspace files at session/bootstrap time rather than hot-reloading arbitrary file changes into already-running named-agent sessions.

## Practical model
1. deploy reviewed framework updates into the managed named-agent workspaces
2. start a fresh session for the affected named agent
3. treat the new session as the activation boundary for the updated framework behavior

## Implication
Do not assume that editing `SOUL.md`, `AGENTS.md`, or related startup files in a named-agent workspace will immediately affect an already-running session.
