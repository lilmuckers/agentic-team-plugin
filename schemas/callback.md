# Callback Report Schema

Required sections, in order:

1. `## Task`
2. `## Agent`
3. `## Outcome`
4. `## Routing`
5. `## Changed`
6. `## Artifacts`
7. `## Tests`
8. `## Blockers`
9. `## Next Action`

## Outcome

Must be exactly one of:

- `DONE`
- `BLOCKED`
- `FAILED`
- `NEEDS_REVIEW`

## Routing

Must name the agent this callback is being sent to. Always `orchestrator-<project>` unless the callback is an internal sub-agent report to a named parent agent.

Example:
```
To: orchestrator-musical-statues
Via: ACP
```

## Rules

- Every required section must appear exactly once.
- Section headings must use level-2 markdown headings.
- `## Outcome` must contain a single valid outcome value.
- `## Routing` must name the receiving agent explicitly — a callback with no named recipient is not a callback.
- `## Changed`, `## Artifacts`, `## Tests`, `## Blockers`, and `## Next Action` must not be empty.
- `## Blockers` may contain `- None` when there are no blockers.
- The callback must be sent via ACP immediately on task completion or blockage — do not wait for a heartbeat or cron prompt.
