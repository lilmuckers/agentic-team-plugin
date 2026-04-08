# Decision Record Schema

A decision record is required when a future agent would benefit from knowing why this option was chosen over a plausible alternative.

## Required Fields

- `id`
- `date`
- `decision`
- `rationale`
- `alternatives_rejected`
- `constraints_applied`
- `source_pointers`

## Field Rules

### `id`
A stable identifier, such as `DR-001` or `2026-04-08-ledger-format`.

### `date`
ISO calendar date in `YYYY-MM-DD` format.

### `decision`
One sentence stating the chosen outcome.

### `rationale`
Why this was chosen, including relevant tradeoffs and the reasoning that made the chosen path preferable.

### `alternatives_rejected`
A non-empty list of plausible alternatives that were considered and rejected, with a short reason for each.

### `constraints_applied`
A non-empty list of principles, constraints, or policy boundaries that shaped the decision.

### `source_pointers`
A non-empty list of links or path references to the issue, PR, wiki page, discussion, or other source material where the reasoning can be inspected.

## Required Markdown Sections

1. `# Decision Record: <id>`
2. `## Date`
3. `## Decision`
4. `## Rationale`
5. `## Alternatives Rejected`
6. `## Constraints Applied`
7. `## Source Pointers`
