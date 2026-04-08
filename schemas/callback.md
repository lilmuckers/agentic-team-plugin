# Callback Report Schema

Required sections, in order:

1. `## Task`
2. `## Agent`
3. `## Outcome`
4. `## Changed`
5. `## Artifacts`
6. `## Tests`
7. `## Blockers`
8. `## Next Action`

## Outcome

Must be exactly one of:

- `DONE`
- `BLOCKED`
- `FAILED`
- `NEEDS_REVIEW`

## Rules

- Every required section must appear exactly once.
- Section headings must use level-2 markdown headings.
- `## Outcome` must contain a single valid outcome value.
- `## Changed`, `## Artifacts`, `## Tests`, `## Blockers`, and `## Next Action` must not be empty.
- `## Blockers` may contain `- None` when there are no blockers.
