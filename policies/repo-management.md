# Repository Management Policy

## Core operating rules

1. Product definition, solution design, architecture, and other project-level design material belong in the GitHub wiki.
2. Tasks are created as GitHub issues and tagged with the appropriate target agent archetype.
3. Agents ask visible project questions through issue comments or PR comments, then use ACP to trigger the relevant agent to inspect and respond there.
4. ACP is the delivery coordination channel between agents and sub-agents, but durable project decisions should live in issues, PRs, and the wiki unless the request explicitly falls outside that space.
5. All implementation work is done on feature branches. Push branches as soon as meaningful commits exist. Raise draft PRs as soon as the branch exists remotely, then convert to ready for review once the scoped work is complete.
6. Spec owns project-level assumptions. Builder may make only narrow task-local assumptions. All meaningful assumptions must be listed in the PR and documented in the wiki when they affect project understanding or architecture.
7. If agents disagree, Orchestrator decides and all agents respect that decision.
8. QA approval does not automatically mean mergeable. Spec and Orchestrator decide whether the PR is mergeable in project context.
9. Spec keeps wiki documentation aligned with project goals and the merged codebase.
10. The project root `README.md` must always contain setup and run documentation that lets someone get productive quickly.
11. Test coverage and code quality should be high. Integration tests should be part of the baseline. Bugs, edge cases, and race cases found during delivery should gain regression automation where practical.
12. GitHub Actions workflows should run sensible test harnesses at the appropriate points.
13. Backend test/build execution should use appropriate Docker containers where practical so local and CI environments align.
14. Spec should create and maintain a project-root `SPEC.md` that captures the main project intent and definition while linking to authoritative wiki pages.
15. All commits should use semantic commit style with concise, informative high-level messages; fuller implementation detail belongs in the PR.

## Role implications

### Orchestrator
- route work using issues and PR state
- make final conflict-resolution decisions
- decide mergeability with Spec after QA review

### Spec
- own wiki truth for project-level definition
- own assumptions that affect the project as a whole
- keep docs aligned as PRs merge
- define quality expectations with QA

### Builder
- implement scoped issue work only
- surface ambiguity through visible issue/PR comments
- raise draft PRs early and keep assumption logs current

### QA
- review through the PR
- define and enforce quality expectations with Spec
- approve or request changes, but do not alone determine mergeability
