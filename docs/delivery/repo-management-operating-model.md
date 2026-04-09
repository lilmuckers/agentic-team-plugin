# Repository Management Operating Model

## Purpose

Translate the delivery-framework repo-management rules into one explicit operating model that project repos can follow.

## Durable context locations

### GitHub wiki
Use the wiki for:
- product definition
- solution design
- architecture
- project-level assumptions and rationale
- decision records
- project goals and non-goals

Write wiki content as GitHub-flavored markdown that renders cleanly in the GitHub interface.

### GitHub issues
Use issues for:
- tasks to be done
- target agent archetype labels
- high-level issue-type labels such as `feature`, `bug`, `change`, `chore`, or `spike`
- acceptance criteria
- discrete scope boundaries
- visible clarification threads

Write issue content and comments as GitHub-flavored markdown that renders cleanly in the GitHub interface.

### Pull requests
Use PRs for:
- implementation progress
- assumption logs
- validation status
- QA feedback
- visible discussion about delivery decisions
- agent-attributed posts and updates with explicit archetype headers

Write PR bodies, comments, and updates as GitHub-flavored markdown that renders cleanly in the GitHub interface.

### ACP
Use ACP for:
- triggering another agent to inspect visible external context
- running internal multi-agent delivery work
- coordinating sub-agent execution

Do not use ACP as the only durable home of project-level decisions when an issue, PR, or wiki page should hold them.

## Branch and PR lifecycle

### Normal delivery work
1. Builder starts a feature branch.
2. Builder pushes the branch as soon as there is a meaningful commit.
3. Builder opens a draft PR immediately.
4. Builder continues implementation and updates the PR with assumptions, validation, and follow-ups.
5. Builder requests review from QA and, where needed, from Spec or Orchestrator.
6. QA reviews the PR.
7. If there is disagreement, Orchestrator decides.
8. QA approval allows mergeability review, but Spec and Orchestrator decide whether the PR is ready to merge in project context.

### Spike work
1. Spec creates a `spike` issue with a bounded question.
2. Spec defines explicit success and failure criteria.
3. Builder uses a spike branch rather than a normal feature branch.
4. Builder performs the bounded experiment and reports results visibly.
5. Spec and Orchestrator decide the next step based on the spike outcome.
6. Spike output should not be treated as merge-ready feature delivery by default.

## Assumption model

### Spec assumptions
Spec makes assumptions that affect:
- project behavior
- architecture
- scope boundaries
- cross-cutting quality thresholds

These must be documented in the wiki and referenced from issues or PRs as appropriate.

### Builder assumptions
Builder may make narrow assumptions limited to the issue being implemented.

If those assumptions affect broader project truth, Builder should escalate through an issue or PR comment and trigger Spec or Orchestrator review via ACP.

## Documentation responsibilities

### Spec
- keep wiki documentation aligned with merged behavior and project goals
- ensure assumptions and rationale remain discoverable
- keep project docs current as the project evolves

### Project README
The root `README.md` must always provide enough setup and run guidance for a new operator or contributor to get moving quickly.

### Project SPEC.md
The root `SPEC.md` should be maintained by Spec as the concise in-repo entrypoint for project intent and definition.

It should:
- summarize the project purpose and scope
- point to the authoritative wiki pages for deeper definition and architecture
- stay aligned with current project direction and merged code

## Commit baseline

Use semantic commits with concise high-level subjects.
Keep richer explanation, assumptions, and reviewer detail in the pull request.

When agents commit, use a per-agent Git identity in this format:
`<Name> (<Archetype>) <bot-<archetype-slug>@<operator-email-domain>>`

## Security and release gates

- security-scope issues need visible security requirements and a threat model before Builder handoff
- security-scope PRs need Security review and `security-approved`
- release coordination should live in a release tracking issue plus `docs/delivery/release-state.md`

## Docker-first local development baseline

Application repos should normally include:
- `docker-compose.yml`
- `.devcontainer/devcontainer.json`
- README build/verify/run instructions that use the containerized local-dev path

## Comment and post attribution baseline

When agents post substantive updates on issues or pull requests, begin with:
`> _posted by **<Archetype>**_`

This keeps authorship visible to human reviewers even when multiple agents operate through shared automation.

## Quality baseline

Expected baseline:
- high unit test coverage
- high code quality using standard tooling
- integration tests as part of the model
- regression automation for bugs, edge cases, and race conditions where practical
- GitHub Actions workflows to run sensible checks
- backend build/test execution in Docker where practical for parity across environments
