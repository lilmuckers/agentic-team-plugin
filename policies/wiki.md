# Wiki Policy

The GitHub wiki is the project's durable knowledge store. It is not a transcript, not a junk drawer, and not optional.

Delivery artifacts (issues, PRs, release trackers) capture what happened. The wiki captures what is permanently true. These are distinct surfaces with distinct update obligations.

If the wiki is not being updated, the project is losing memory.

## What belongs in the wiki

### Product knowledge (Spec owns)
- product behavior and user-facing semantics
- feature scope summaries and non-goals
- acceptance-criteria decisions that future work depends on
- stable issue-decomposition rationale

### Delivery / process knowledge (Orchestrator owns)
- routing rules and role-boundary decisions
- workflow conventions and operational notes
- task/dependency model explanations
- recurring lessons from delivery failures or edge cases

### Release knowledge (Release Manager owns)
- what each release contained and what was verified live
- release state progression (beta → RC → final)
- live deployment behavior and known caveats
- release expectations and assumptions for future releases

### Architecture / design knowledge (Spec owns, with Security and Orchestrator contributing)
- architecture decisions and the alternatives that were rejected
- trust boundary decisions
- design constraints that are stable enough to affect future issues

## What does not belong in the wiki

- per-PR implementation notes (those belong in the PR)
- transient issue chatter (that belongs in the issue thread)
- ephemeral agent reasoning (that does not belong anywhere durable)
- blocker status that is actively changing (that belongs in the release tracker or issue)
- anything that is not expected to be true two weeks from now

## Mandatory wiki update triggers

A wiki update is mandatory — not optional — when any of the following occur:

| Trigger | Responsible agent | Example page |
|---------|------------------|-------------|
| Material change to product scope or acceptance criteria | Spec | `Product-Scope.md`, `Feature-<name>.md` |
| Stable issue decomposition established for a major feature | Spec | `<Feature>-Decomposition.md` |
| Durable architecture or design decision | Spec | `Architecture-Decisions.md` |
| Role boundary clarified or re-established | Orchestrator | `Delivery-Process.md` |
| Workflow or routing rule changed materially | Orchestrator | `Delivery-Process.md` |
| Bug reveals a durable lesson for future implementation or review | Orchestrator or Spec | `Known-Issues-and-Lessons.md` |
| Release moves to final | Release Manager | `Release-History.md` |
| Live deployment behavior confirmed or caveated | Release Manager | `Release-<version>.md` |
| Security threat model or trust boundary established | Security | `Security-Model.md` |

## Wiki update is part of completion

The following are not complete until the wiki is updated:

- A major spec restructure is not complete until the relevant product or architecture wiki page is updated.
- A release is not complete until Release Manager has written a release summary to the wiki.
- A routing or role-boundary decision is not complete until Orchestrator has captured the decision and rationale in the wiki or a linked decision record.
- A bug that reveals a durable lesson is not closed until the lesson is written somewhere durable (wiki or `docs/` decision record).

## What counts as a wiki update

A wiki update must be a new or materially revised GitHub wiki page — not a comment on an issue, not a PR description, not an internal note.

The bar for "material" is: would a future agent or operator need to know this to work correctly on the project a month from now? If yes, it belongs in the wiki.

## What does not count

- Writing a PR summary that happens to explain the architecture
- Leaving a comment on a closed issue
- Updating `docs/delivery/task-ledger.md` or `docs/delivery/release-state.md` — these are delivery trackers, not the wiki

## Ownership is not sharing

Each domain has one primary owner. That owner is responsible for ensuring updates happen, not for waiting for someone else.

- **Spec** does not wait for Orchestrator to write product knowledge.
- **Orchestrator** does not wait for Spec to write delivery process notes.
- **Release Manager** does not wait for anyone to write the release summary.

If a wiki update is in your domain and it has not happened, that is your gap to close before considering the work done.
