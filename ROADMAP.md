# Framework Improvement Roadmap

This roadmap captures the next phase of development for the agentic-team-plugin framework. It is organized as a set of epics with implementation steps and decision points.

All decisions were resolved 2026-04-08. The Decision Points Index below is a resolved record — it is not a blocker list.

---

## Decision Points Index

Resolved decisions should be updated inline and dated. Unresolved decisions block the epic they belong to.

| # | Decision | Status | Blocks |
|---|---|---|---|
| D1 | Where does the task ledger live? | **Resolved 2026-04-08** — markdown file committed to project repo (`docs/delivery/task-ledger.md`) | Epic 1 |
| D2 | How does OpenClaw enforce persistent session continuity via `--session-id`? | **Resolved 2026-04-08** — `--session-id` provides routing identity only, not memory continuity; task ledger is the sole persistence mechanism | Epics 1, 4, OpenClaw config |
| D3 | Merge gate mechanism — labels + branch protection, or GitHub Actions? | **Resolved 2026-04-08** — labels (`qa-approved`, `spec-satisfied`, `orchestrator-approved`) + branch protection + GH Actions workflow in `repo-templates/` | Epic 5 |
| D4 | Callback format — structured markdown or JSON? | **Resolved 2026-04-08** — structured markdown with required section headers | Epic 3 |
| D5 | Does OpenClaw have a native heartbeat/cron mechanism? | **Resolved 2026-04-08** — yes; use native OpenClaw cron (not system cron or watchdog script) | Epic 7, OpenClaw config |
| D6 | Are named agent definitions declarative config or CLI-driven? | **Resolved 2026-04-08** — CLI-driven; scripts are source of truth (`deploy-named-agents.py` orchestrates `openclaw agent` calls) | OpenClaw config |
| D7 | Does OpenClaw auto-load all workspace files, or require an explicit manifest? | **Resolved 2026-04-08** — `AGENTS.md` acts as the explicit boot manifest; agent reads it first, then follows its instructions to load remaining workspace files | OpenClaw config |
| D8 | Workflow YAMLs — upgrade to real contracts or remove? | **Resolved 2026-04-08** — upgrade to full contracts with schema, preconditions, postconditions, and error paths | Epic 6 |
| D9 | Session staleness definition — SHA-based, time-based, or policy-change-based? | **Resolved 2026-04-08** — policy-change-based: warn when any file under `agents/`, `policies/`, or `skills/` has changed since the loaded SHA | Epic 4 |
| D10 | Project onboarding scope — minimum viable or full setup? | **Resolved 2026-04-08** — minimum viable by default; full setup opt-in via `--with-github-setup` flag | Epic 8 |
| D11 | Is mempalace a fit as the memory retrieval substrate? | **Resolved 2026-04-08** — good substrate, incomplete system; run a bounded pilot on one project corpus before any wider adoption; Epic 9 decision record format is the required protocol layer regardless of outcome | Epic 10 |

---

## Epic 1 — Durable Orchestrator Task Ledger

**Problem:** The Orchestrator's knowledge of in-flight tasks lives in session memory. A session rollover kills it silently. There is no audit trail of delegations, callbacks, or overdue tasks.

**Goal:** A structured task ledger stored as a durable artifact the Orchestrator reads and writes — tracking delegated tasks, expected callbacks, and current status.

### D1 — Where does the ledger live? ✅ Resolved 2026-04-08

**Decision:** Markdown file committed to the project repo at `docs/delivery/task-ledger.md`. The Orchestrator commits on every delegation and callback. Fits the visibility-first philosophy, survives session rollovers, and is readable by any human without touching OpenClaw.

### Steps

1. Define ledger schema as a markdown table in `docs/delivery/task-ledger.md` — fields: task ID, agent assigned, delegated timestamp, expected callback fields, outcome status, last updated
2. Write `scripts/update-task-ledger.py` — append or update a ledger row given task ID and status
3. Add ledger read/write to Orchestrator role doc as a mandatory operating rule
4. Add a session startup step to Orchestrator: read ledger on start, surface any overdue tasks immediately before taking new work
5. Write `scripts/validate-task-ledger.py` to validate ledger schema correctness and table structure

---

## Epic 2 — Mechanical Issue Readiness Validation

**Problem:** The definition of ready is defined in prose. Builder could start work on an unready issue and nothing catches it mechanically.

**Goal:** A script agents can invoke before acting that validates an issue meets all readiness criteria.

### D2a — What is the enforcement point? ✅ Resolved 2026-04-08

**Decision:** Hard gate at Orchestrator assignment time (must run `validate-issue-ready.py` before routing) plus a label check at Builder start (halt if `ready-for-build` label is absent). Two layers: neither alone is sufficient.

### Steps

1. Write `scripts/validate-issue-ready.py <issue-number>` — checks: issue-type label present, agent-archetype label present, body contains acceptance criteria section, assumption doc linked, no open blocking issues
2. Add invocation requirement to Orchestrator role doc: must run `validate-issue-ready.py` before routing any issue to Builder
3. Add Builder startup check: if issue lacks `ready-for-build` label, surface it and halt pending Orchestrator confirmation
4. Wire `validate-issue-ready.py` into `validate-agent-artifacts.py` for CI use

---

## Epic 3 — Callback Schema and Validation

**Problem:** The callback contract (task ID, outcome, artifacts, blockers, next action) is defined in prose in the Orchestrator role doc. Agents return unstructured text and the Orchestrator must interpret it without a schema to validate against.

**Goal:** A defined callback format with a validation script so agents can validate their own output before sending, and the Orchestrator can reject malformed callbacks explicitly.

### D4 — Callback format ✅ Resolved 2026-04-08

**Decision:** Structured markdown with required section headers. Human-readable, fits the GitHub-visible philosophy, and validatable by checking section presence. JSON is overkill for a system with human review gates.

### Steps

1. Define callback template in `templates/callback-report.md` with required sections: `## Task`, `## Agent`, `## Outcome` (must be one of: DONE / BLOCKED / FAILED / NEEDS_REVIEW), `## Changed`, `## Artifacts`, `## Tests`, `## Blockers`, `## Next Action`
2. Write `scripts/validate-callback.py` — parses a callback file or comment, verifies all required sections are present and Outcome is a valid value
3. Update Orchestrator role doc: callbacks must use the template; malformed or missing-section callbacks are treated as BLOCKED and the Orchestrator must surface this before proceeding
4. Add callback template reference to Builder and QA role docs as the required return format
5. Add the schema definition to `schemas/callback.md`

---

## Epic 4 — Session Health Check and Rollover Handling

**Problem:** Persistent Orchestrator and Spec sessions can drift from the deployed framework version silently. There is no detection mechanism and no defined rollover protocol.

**Goal:** A session startup check that compares the framework version loaded at bootstrap against the currently deployed SHA, surfacing any mismatch to the human before work begins.

### D2 — OpenClaw session continuity ✅ Resolved 2026-04-08

**Decision:** `--session-id` provides routing identity and namespace only — not memory continuity. Runtime testing confirmed arbitrary `agentDir` files are not automatically consumed. The task ledger (Epic 1) is therefore the sole persistence mechanism for Orchestrator state across session boundaries.

### D9 — What defines a session as stale? ✅ Resolved 2026-04-08

**Decision:** Policy-change-based — trigger a stale warning when any file under `agents/`, `policies/`, or `skills/` has changed since the SHA recorded in `FRAMEWORK_NOTES.md` at session load time.

### D2b — What happens on mismatch? ✅ Resolved 2026-04-08

**Decision:** Surface the SHA diff and list of changed material files as the Orchestrator's first message to the human, then continue. Automatic session kill is too aggressive for a persistent session — the human decides if the delta is material enough to force a rollover.

### Steps

1. Write `scripts/check-framework-version.sh` — reads `FRAMEWORK_NOTES.md` from the workspace bootstrap (loaded at session start) and compares the SHA against `.state/framework/deployed-sha.txt`
2. Add to `scripts/check-framework-version.sh`: diff which files under `agents/`, `policies/`, `skills/` have changed between the loaded SHA and current deployed SHA
3. Add to Orchestrator role doc: run version check at session start; if mismatch exists in material files, report to human before taking any new work
4. Confirm `FRAMEWORK_NOTES.md` is populated with the deployed SHA during workspace bootstrap (verify `deploy-agent-workspace-bootstrap.py` includes this)
5. Add session rollover guidance to `policies/session-rollover.md`: define what "stale enough to force rollover" means and who initiates it

---

## Epic 5 — Merge Gate Enforcement

**Problem:** The three-party merge gate (QA approval + Spec satisfaction + Orchestrator approval) exists in policy but nothing enforces it. A PR could be merged with only one party satisfied.

**Goal:** A mechanism that verifies all three gate conditions are met before the Orchestrator signals the human to merge.

### D3 — Where does the merge gate check live? ✅ Resolved 2026-04-08

**Decision:** Labels (`qa-approved`, `spec-satisfied`, `orchestrator-approved`) plus branch protection rules, enforced by a GitHub Actions workflow in `repo-templates/` that projects adopt. Each role owns applying its label; the Actions workflow fails the merge check if any label is absent.

### Steps

1. Add label definitions to `docs/delivery/github-labels.md`: `qa-approved`, `spec-satisfied`, `orchestrator-approved`
2. Add label-application responsibility to each role doc: QA applies `qa-approved`, Spec applies `spec-satisfied`, Orchestrator applies `orchestrator-approved` only after confirming the other two are present
3. Write `repo-templates/.github/workflows/merge-gate.yml` — GitHub Actions check that fails if any of the three labels are absent from the PR
4. Add merge gate check to Orchestrator role doc: Orchestrator must confirm `qa-approved` and `spec-satisfied` labels are present before applying `orchestrator-approved` and signalling the human
5. Add stale-approval handling to Orchestrator role doc: when a PR changes after approval, the Orchestrator removes approval labels before handing back to the appropriate agents for re-approval
6. Add merge gate label check to `scripts/validate-agent-artifacts.py`

### PR Line-Level Review Comments

**Policy (resolved):** When agents have line-specific feedback on a PR, they must post it as a review comment against the relevant line, not as a top-level PR comment. Top-level PR comments are reserved for summary-level observations (e.g. overall outcome, blockers, next action).

7. Write `scripts/post-pr-line-comment.sh <pr-number> <commit-sha> <file-path> <line> <body>` — wraps `gh api /repos/.../pulls/.../comments` to post a line-anchored review comment
8. Update QA role doc: line-specific feedback must use `post-pr-line-comment.sh`; top-level PR comments are for summary only
9. Update Builder role doc: when addressing QA feedback, expect line comments and resolve them via `gh pr review` dismiss or by pushing a fix commit
10. Add `post-pr-line-comment.sh` to `docs/delivery/agent-tooling-helpers.md`

---

## Epic 6 — Workflow YAML Contracts

**Problem:** The workflow YAML files (`implement-feature.yaml`, `fix-bug.yaml`, `prepare-release.yaml`) are stubs. They declare steps and agents but omit preconditions, postconditions, error paths, and feedback loops. They are less complete than the role docs and policies, creating a dual-fidelity problem.

**Goal:** Either upgrade the YAMLs to full contracts that match the sophistication of the role docs, or remove them and treat the role docs and policies as the sole canonical workflow definition.

### D8 — Invest in YAML or remove? ✅ Resolved 2026-04-08

**Decision:** Upgrade to full contracts. Even if OpenClaw does not currently interpret them, they become the definitive machine-readable spec and prevent further divergence from the role docs.

### Steps

1. Define workflow YAML schema in `schemas/workflow.json` — fields: `name`, `description`, `steps` (each with `id`, `agent`, `preconditions`, `postconditions`, `output`), `on_blocked`, `on_failure`, `loops`
2. Rewrite `implement-feature.yaml`, `fix-bug.yaml`, and `prepare-release.yaml` against the schema — include preconditions (e.g. issue is ready-for-build), postconditions (e.g. callback received), and loop definitions (e.g. QA requests changes → Builder updates → QA re-reviews)
3. Write `scripts/validate-workflows.py` — validate all workflow files against the schema
4. Add workflow validation to `validate-framework.sh`

---

## Epic 7 — Deployment Security Hardening

**Problem:** `sync-framework.sh` and `deploy-agent-workspace-bootstrap.py` write to `/data/.openclaw/` with no path validation, symlink detection, ownership checks, or confirmation on destructive overwrites.

**Goal:** Pragmatic hardening appropriate for a single-operator local system — sanity checks that prevent accidental misconfiguration rather than active-attack mitigations.

### D3a — Threat model ✅ Resolved 2026-04-08

**Decision:** Single-operator local system. The steps below are lightweight sanity checks against accidental misconfiguration, not active-attack mitigations. If the system ever becomes multi-tenant or remotely accessible, this scope must be revisited.

### Steps

1. Add to `sync-framework.sh`: verify `/data/.openclaw/` is not a symlink before writing (`[ -L path ] && exit 1`)
2. Add ownership check to `sync-framework.sh`: warn if `/data/.openclaw/` is not owned by the current user
3. Add `--dry-run` flag to `deploy-agent-workspace-bootstrap.py` — shows a diff of what would change without writing
4. Add confirmation prompt to `deploy-agent-workspace-bootstrap.py` before overwriting existing workspace files (bypass with `--force`)
5. Add manifest cross-check to `validate-framework.sh`: verify that files classified as `local:` in `deploy/manifest.yaml` are excluded from the sync operation

---

## Epic 8 — Project Onboarding Script

**Problem:** Setting up a new project requires running several scripts in the correct order with no single entry point or idempotency guarantees.

**Goal:** A single `scripts/onboard-project.sh <project-slug>` that runs the full onboarding sequence, with dry-run support and idempotency.

### D10 — What does "onboarded" mean? ✅ Resolved 2026-04-08

**Decision:** Minimum viable by default — named agents created + workspace bootstrap deployed + project repo templates copied. Full setup (GitHub labels, wiki skeleton, spec-approval issue, SPEC.md scaffold) is opt-in via `--with-github-setup` flag.

### Steps

1. Review `docs/templates/project-bootstrap-checklist.md` — confirm it reflects the current intended onboarding sequence
2. Write `scripts/onboard-project.sh <project-slug>` that: creates namespaced named agents, deploys workspace bootstrap, copies repo-templates to the target project repo
3. Add `--with-github-setup` flag: creates GitHub labels, opens spec-approval issue, scaffolds wiki skeleton
4. Add `--dry-run` flag: prints what would be done without executing
5. Add idempotency: each step checks whether it has already been completed before running (detect existing agents, existing labels, existing files)
6. Run `set-agent-git-identity.sh` for the project repo as part of onboarding

---

## OpenClaw Configuration Required

These are the configuration decisions and setup steps needed on top of a baseline OpenClaw installation to make the framework behave correctly.

### 1. Named Agent Definitions

Four named agents per project, using the project-scoped naming convention:

```
orchestrator-<project-slug>
spec-<project-slug>
builder-<project-slug>
qa-<project-slug>
```

Each agent must point to its workspace directory (`/data/.openclaw/workspace-<archetype>/`) as its context source. The `deploy-named-agents.py` script handles deployment.

**D6 resolved:** CLI-driven. Named agents are defined through `openclaw agent` CLI calls. Scripts (`deploy-named-agents.py`, `create-project-scoped-agents.sh`) are the source of truth. `onboard-project.sh` (Epic 8) orchestrates them.

### 2. Workspace Bootstrap Files

Each named agent requires these files present at session start (deployed by `deploy-agent-workspace-bootstrap.py`):

| File | Purpose |
|---|---|
| `AGENTS.md` | Startup guide — first thing the agent reads |
| `SOUL.md` | Agent identity and core operating principles |
| `IDENTITY.md` | Role definition (mirrors `agents/<archetype>.md`) |
| `FRAMEWORK_RUNTIME_BUNDLE.md` | Full deployed framework bundle |
| `FRAMEWORK_NOTES.md` | Deployment metadata — SHA, timestamp, active dir |
| `USER.md` | Operator identity |

**D7 resolved:** `AGENTS.md` is the explicit boot manifest. OpenClaw does not auto-load arbitrary workspace files — the agent reads `AGENTS.md` first, which instructs it to load the remaining workspace files. No additional `BOOT.md` is needed; `AGENTS.md` already plays this role.

### 3. Session Topology Configuration

OpenClaw must be configured to enforce the hybrid session topology:

| Agent | Session type | Session target |
|---|---|---|
| `orchestrator-<project>` | Persistent | `session:<project>-orchestrator` |
| `spec-<project>` | Persistent | `session:<project>-spec` |
| `builder-<project>` | Ephemeral | `isolated` |
| `qa-<project>` | Ephemeral | `isolated` |

This maps to the `sessionTarget` field in `scripts/prepare-archetype-spawn.py`. **D2 resolved:** `--session-id` provides routing identity only, not memory continuity. The task ledger (Epic 1) is the sole persistence mechanism for Orchestrator and Spec state across session boundaries.

### 4. ACP Routing Configuration

The framework relies on ACP for inter-agent coordination. OpenClaw must be configured so that:

- ACP messages addressed to `orchestrator-<project>` route to the correct persistent session
- Project-scoped named agents take routing precedence over any generic role-shaped agents
- The routing precedence rules in `policies/named-agent-routing.md` are reflected in OpenClaw's agent registry

**D6 resolved:** Named agents are registered via CLI calls in `deploy-named-agents.py`. Project-scoped names (`orchestrator-<project>`, etc.) must be registered before ACP routing works. `deploy-named-agents.py` is responsible for full registration — verify it completes registry writes, not just file writes.

### 5. Heartbeat and Watchdog

The Orchestrator's "treat missed callbacks as exceptions" rule requires a watchdog that checks the task ledger for overdue delegations and nudges the Orchestrator session.

**D5 resolved:** Use native OpenClaw cron. Configure a cron job within OpenClaw that reads the task ledger for overdue delegations and sends a nudge to the Orchestrator session. No `scripts/watchdog.sh` needed.

Suggested cadence: every 30 minutes during active delivery hours.

### 6. Git Identity Per Agent

`scripts/set-agent-git-identity.sh` must run in every project repo before agents start committing. This should be part of `scripts/onboard-project.sh` (Epic 8) and validated by a preflight check in each agent's startup sequence.

Commit identity format (already defined in policies):
```
<Name> (<Archetype>) <bot-<archetype-slug>@<operator-domain>>
```

---

## Epic 9 — Decision Record Schema

**Problem:** Agents preserve decisions but lose the reasoning. Later agents retrieve the conclusion without the rationale, the tradeoffs considered, or the philosophical constraints that shaped it — causing cargo-culting or forcing the human to restate context that was already worked through.

**Goal:** A mandatory three-layer decision record format that Orchestrator and Spec must write whenever a significant decision is made, so the full reasoning thread is durable and retrievable — not just the conclusion.

### Three-layer format

| Layer | Purpose | Must include |
|---|---|---|
| Decision | What was decided | One-sentence statement of the outcome |
| Rationale | Why, and what was rejected | Tradeoffs considered, alternatives rejected and why, constraints and principles that applied |
| Evidence trail | Where the reasoning lives | Links or pointers to the source discussion, issue, or session context |

Without layer 2, conclusions become brittle. Without layer 3, agents cannot reconstruct nuance when the decision is later retrieved.

### Steps

1. Define decision record schema in `schemas/decision-record.md` — required fields: `id`, `date`, `decision`, `rationale`, `alternatives_rejected` (list), `constraints_applied`, `source_pointers` (list)
2. Create `templates/decision-record.md` — fill-in-the-blank template for agents to use when writing a decision record
3. Write `scripts/validate-decision-record.py <file>` — validates a decision record file against the schema; checks all required fields are non-empty
4. Define storage location: decision records for a project live in `docs/decisions/` within the project repo, committed by the agent that made the decision
5. Update Orchestrator role doc: any routing, escalation, or architectural decision must be accompanied by a committed decision record before the relevant task is marked DONE
6. Update Spec role doc: any acceptance criteria, scope, or approval decision must be accompanied by a decision record
7. Add significance rule to the schema and role docs: if a future agent would benefit from knowing why this was chosen over a plausible alternative, it requires a decision record
8. Wire `validate-decision-record.py` into `validate-agent-artifacts.py` for CI use
9. Add decision record reference to the callback template (`templates/callback-report.md`): the `## Artifacts` section should list any decision records produced during the task

---

## Epic 10 — Memory Retrieval Substrate (Bounded Pilot)

**Problem:** The decision record schema (Epic 9) solves the write side — agents produce structured, rationale-rich records. But retrieval is still manual: agents must know to look, know where to look, and read the full doc. For a project with many decisions this does not scale.

**Goal:** Pilot mempalace as the retrieval substrate for decision records and accumulated project context on one live project corpus, establishing whether it delivers reliable rationale recall in practice before any wider adoption.

### D11 — Resolved 2026-04-08

**Verdict (from OpenClaw spike):** Good substrate, incomplete system. Worth piloting; not worth wholesale adoption yet.

What the spike confirmed:
- Verbatim-first retrieval is directionally correct — stores "why", not just "what"
- Real Python project with working MCP server (Python + ChromaDB stack)
- Project publicly corrected earlier overclaims — increases credibility
- Architecture is legible, not magical

What the spike flagged as risks:
- Repo is very new (created 2026-04-05); 174 open issues; CI coverage bar is only 30%
- ChromaDB dependency has known version instability
- Shell injection risk in hooks acknowledged but not yet fully resolved
- Benchmark claims are still self-presented; moat may be thin
- "The magic is mostly: don't throw data away" — which can partially be reproduced without MemPalace

**The missing piece mempalace does not solve on its own:** memory protocol — when agents retrieve, how they distinguish decision vs rationale vs unresolved debate, and how to prevent agents from re-summarising retrieved content and losing the nuance again. Epic 9's three-layer format is that protocol layer; it is required regardless of retrieval backend.

### Pilot success criteria

Run against one project corpus. A retrieval is successful if agents can answer these questions without the human restating context, and the answer must reflect the actual recorded rationale rather than a plausible reconstruction:

- "Why did we decide X?"
- "What tradeoffs led to Y?"
- "What alternatives were rejected, and why?"
- "What principle or constraint shaped this decision?"

### Scope

- Orchestrator and Spec named agents only — Builder and QA remain stateless
- Memory scoped per-agent per-project (e.g. `orchestrator/musical-statues`) to prevent cross-project bleed
- Decision records (Epic 9 format) are the primary write input — verbatim, not summaries
- Pilot runs against one project; production adoption requires explicit sign-off after pilot concludes

### Fallback

If the pilot fails the success criteria, or if ChromaDB/stability issues prove blocking: discard the mempalace layer, keep `docs/decisions/` from Epic 9 as canonical, and revisit the retrieval problem with a different candidate or a bespoke verbatim archive.

### Steps

1. Confirm Epic 9 is complete — decision record format must be finalised before pilot population begins
2. Install mempalace as MCP in OpenClaw environment for Orchestrator and Spec agents on one pilot project
3. Verify scope model works: memory is isolated per-agent per-project and does not bleed across projects
4. Populate pilot corpus: write existing `docs/decisions/` records from the pilot project into mempalace using the three-layer format
5. Run retrieval tests against the four success-criteria questions above; log results
6. Assess: does retrieved content surface rationale reliably, or do agents still compress it on read?
7. Based on results: either proceed to production rollout (add implementation steps) or document rejection and close the epic
8. Add `docs/decisions/EPIC-10-pilot-findings.md` — record the outcome, evidence, and next-step decision regardless of verdict

---

## Epic 11 — Specialist Subagent Template Library

**Problem:** The specialist subagent model is defined in policy (`docs/delivery/named-agent-specialist-model.md`) — Builder, QA, and Spec can all spawn ephemeral specialists — but there are no reusable templates. Every agent that needs a TypeScript specialist, a QA accessibility reviewer, or a GraphQL analyst must invent it from scratch. This produces inconsistent specialist quality and duplicates effort across projects.

**Goal:** A curated library of generic specialist subagent templates that agents select, then refine for their specific task context before spawning. The refinement step is explicit and required — templates are starting points, not ready-to-run prompts.

### How the refinement model works

A template defines the base identity and capability of a specialist:

> "You are a TypeScript engineer. Your role is to implement TypeScript with correctness and idiomatic style."

The spawning agent refines it for the specific task context before spawning:

> "You are a TypeScript engineer. Your role is to implement TypeScript with correctness and idiomatic style. This project uses React with a GraphQL backend via Apollo Client. Prefer functional components and typed query hooks."

The spawning agent remains accountable for the output — the specialist contributes focused work only. This aligns with the authority boundaries already defined in `docs/delivery/named-agent-specialist-model.md`.

### Template library structure

Templates live in `agents/specialists/`. Each template is a markdown file with two sections:

- `## Base Identity` — the generic, reusable prompt that defines the specialist's role and capability
- `## Refinement Prompts` — a set of example refinements showing how to extend the base identity for common contexts. Agents pick from these or write their own.

### Initial template set

**Builder specialists** (implementation and testing):
- `agents/specialists/typescript-engineer.md`
- `agents/specialists/python-engineer.md`
- `agents/specialists/frontend-ui.md`
- `agents/specialists/backend-integration.md`
- `agents/specialists/api-design.md`
- `agents/specialists/database-migration.md`
- `agents/specialists/ci-container.md`
- `agents/specialists/test-harness.md`
- `agents/specialists/test-suite-builder.md` — writes full test suites in the project's chosen language and framework; refinement must specify language, test framework, and coverage targets

**QA specialists** (review-focused):
- `agents/specialists/qa-regression.md`
- `agents/specialists/qa-edge-case.md`
- `agents/specialists/qa-accessibility.md`
- `agents/specialists/qa-security.md`
- `agents/specialists/qa-docs-verification.md`
- `agents/specialists/usability-reviewer.md` — evaluates delivered features against SPEC.md usability requirements; used by QA, not Spec

**Spec specialists** (research, analysis, and design):
- `agents/specialists/architecture-research.md`
- `agents/specialists/library-evaluation.md`
- `agents/specialists/technical-option-comparison.md`
- `agents/specialists/migration-scoping.md`
- `agents/specialists/ux-designer.md`
- `agents/specialists/visual-designer.md`

### Steps

1. Define specialist template schema in `schemas/specialist-template.md` — required sections: `## Base Identity`, `## Refinement Prompts`, `## Authority Boundaries` (what this specialist does not own), `## Expected Output`
2. Write the initial template set above in `agents/specialists/` against the schema
3. Write `scripts/prepare-specialist-spawn.py <template> <refinement-file>` — merges a base template with an agent-supplied refinement file to produce a ready-to-spawn prompt payload; outputs to stdout or a named file
4. Update Builder role doc: before spawning any specialist subagent, Builder must select a template from `agents/specialists/`, write a refinement file scoped to the current task, and run `prepare-specialist-spawn.py`; ad hoc specialist definitions without a template are not permitted
5. Update QA role doc: same requirement for QA specialists
6. Update Spec role doc: same requirement for Spec specialists
7. Update `docs/delivery/named-agent-specialist-model.md` to reference the template library and refinement process
8. Write `scripts/validate-specialist-template.py` — validates a template file against the schema
9. Wire `validate-specialist-template.py` into `validate-framework.sh`
10. Add guidance to `docs/delivery/agent-tooling-helpers.md`: how to select a template, write a refinement, and invoke `prepare-specialist-spawn.py`

---

## Epic 12 — Testing Standards and Executable Quality Gates

**Problem:** There is no enforced standard for test presence, test executability, or how the application should be built and verified. Builder produces code; QA reviews it; but neither is mechanically required to prove the application actually runs or that tests exist and pass.

**Goal:** Define and enforce: (1) a README-first contract for every project so any agent or human can build, run, and verify the application; (2) a requirement that all PRs include executable tests; (3) a Spec-owned test strategy that defines the tooling appropriate to the application type.

### README-first contract

The first substantive content of every project README must be actionable instructions covering three things, in order:
1. How to build the application
2. How to run it
3. How to verify it is running correctly (a smoke test or health check a human can execute in under two minutes)

This is not a documentation nicety — it is a quality gate. If QA cannot follow the README to a running application, the PR is blocked.

### Spec-defined test strategy

Spec is responsible for defining the test strategy as part of the specification for every feature or project. The strategy must specify:
- Test types required (unit, integration, end-to-end, contract, etc.)
- Test framework and tooling for each type (e.g. Jest for unit, Playwright for browser end-to-end, pytest for Python)
- Coverage expectations
- How tests are executed in CI

Builder and QA are bound by the Spec-defined strategy. Builder implements it; QA enforces it.

### Steps

1. Add README-first contract to `policies/repo-management.md` — first section of README must be build/run/verify instructions; define the required headings
2. Add to Builder role doc: on every PR, confirm README build/run/verify section exists and is accurate; if the feature changes how the application is built or run, update the README as part of the PR
3. Add to QA role doc: on every PR, verify README instructions still produce a running application; if they do not, block the PR regardless of code review outcome
4. Add to Spec role doc: every feature specification must include a `## Test Strategy` section defining test types, tooling, and coverage expectations; this is part of the definition of ready
5. Add `test-strategy` as a required field in `scripts/validate-issue-ready.py` — issue body must reference or contain a test strategy before it is considered ready for build
6. Add to QA role doc: a PR without executable tests is blocked; QA must verify tests run and pass before applying `qa-approved`
7. Write `scripts/validate-readme-contract.sh <repo-path>` — checks that README contains the required build/run/verify headings; exits non-zero if absent
8. Wire `validate-readme-contract.sh` into `validate-agent-artifacts.py`

---

## Epic 13 — Adversarial QA and Bug Regression Workflow

**Problem:** QA currently reviews code and verifies functionality, but there is no policy requiring adversarial exploration — actively trying to break the application. Bugs found by QA have no defined lifecycle: no standard for reporting repro steps, no requirement to write a regression test, and no clear ownership handoff back to Builder.

**Goal:** Define adversarial QA as a first-class QA responsibility, a structured bug lifecycle from discovery through regression test, and a Spec-owned triage gate for deciding which bugs are in-scope.

### Adversarial QA mandate

QA must actively attempt to break the application — not just verify the happy path. Required adversarial passes:
- Invalid or unexpected inputs at every boundary
- State transitions in unexpected order
- Missing dependencies, partial config, empty states
- Concurrent or rapid repeated actions where applicable
- Edge cases derived from the acceptance criteria (e.g. empty list, max values, missing optional fields)

QA reports every breakage found, not just the ones it judges to be important. Scope triage is Spec's responsibility, not QA's.

### Bug scope triage

When QA surfaces a bug, Spec decides:
- **In-scope and must fix** — bug is within the application's defined behaviour; Builder is assigned to fix and write a regression test
- **Expected / by design** — the behaviour is intentional; Spec documents why and closes the bug
- **Out of scope** — bug is in a layer the application does not own (e.g. a rendering quirk in a headless environment for a CLI application); Spec documents the boundary and closes the bug

This prevents QA from self-censoring ("this probably doesn't matter") and prevents Builder from arbitrarily deciding a bug is acceptable.

### Bug reproduction and regression workflow

When QA discovers a bug:
1. QA posts a structured bug report — repro steps, observed vs expected behaviour, environment; QA does not pre-filter by scope
   - If discovered during PR review: as a line comment on the relevant code (using `scripts/post-pr-line-comment.sh`) plus a PR-level summary comment
   - If discovered post-merge: as a new GitHub issue with `type:bug` label
2. Spec triages: in-scope / expected / out-of-scope; records the decision as a decision record (Epic 9 format)
3. If in-scope: Orchestrator assigns Builder to write a **failing test** that reproduces the bug — the test must fail in the presence of the bug and pass only when it is fixed
4. Builder writes the regression test, confirms it fails before the fix, then applies the fix and confirms the test passes
5. The regression test is committed alongside the fix; QA re-verifies both

### Steps

1. Add adversarial QA mandate to QA role doc — list the required adversarial passes; QA must document which passes it ran in the `## Tests` section of its callback report
2. Define bug report template in `templates/bug-report.md` — required fields: `## Summary`, `## Steps to Reproduce`, `## Observed Behaviour`, `## Expected Behaviour`, `## Environment`, `## Affected Code` (file/line reference)
3. Update QA role doc: all discovered breakages must be reported using `templates/bug-report.md`; QA does not triage scope — all findings are reported and Spec decides
4. Update Spec role doc: when QA surfaces bugs, Spec must triage each as in-scope/expected/out-of-scope and record the decision as a decision record (Epic 9 format)
5. Update Orchestrator role doc: when Spec marks a bug as in-scope, Orchestrator assigns Builder to write the regression test before assigning the fix; regression test and fix are a single deliverable
6. Update Builder role doc: regression test must be written first and confirmed failing; fix is then applied and test confirmed passing; both must be present in the PR
7. Add `scripts/post-bug-report.sh <issue-number|pr-number> <bug-report-file>` — posts a formatted bug report as a GitHub issue or PR comment using the template
8. Wire bug report requirement into `validate-agent-artifacts.py`: if a PR is tagged `type:bug-fix`, verify a linked regression test file exists

---

## Epic 14 — Conversational Spec and UX/Design Specialists

**Problem:** The Spec agent currently builds specifications through document-first, asynchronous work. There is no model for the human and Spec to work through requirements conversationally. Additionally, UX and design decisions are either absent from specifications or handled ad hoc — there are no specialist subagents for Spec to delegate design and usability work to.

**Goal:** Establish a conversational spec-building mode as the primary model for how specifications are produced, and add UX and Design specialist subagents to Spec's toolkit so usability and visual design are first-class outputs of the specification process.

### Conversational spec mode

The specification for a feature is built through direct conversation between the human and the Spec agent — not through the Spec agent drafting a document in isolation and submitting it for review. The conversation is the primary input; the SPEC.md document is the structured output of that conversation.

Spec must:
- Ask clarifying questions before writing
- Propose options and tradeoffs rather than asserting a single solution
- Confirm scope, acceptance criteria, and test strategy with the human before committing anything to SPEC.md
- Surface design and usability questions explicitly rather than making silent assumptions

The human approves the spec in conversation; SPEC.md is then the durable record of what was agreed.

### UX and Design specialists

Spec spawns UX and Design specialists during the specification conversation when the feature has user-facing elements. These specialists contribute to the spec, not to implementation.

**UX Designer specialist** (`agents/specialists/ux-designer.md`):
- Defines user flows, interaction patterns, and task completion paths
- Identifies usability requirements (what must be easy, what must be discoverable)
- Surfaces accessibility considerations
- Output: user flow diagrams (in text/Mermaid), usability requirements section of SPEC.md

**Visual Designer specialist** (`agents/specialists/visual-designer.md`):
- Defines visual language, layout principles, and component hierarchy
- Specifies how the UI should look and feel where relevant
- Output: design direction section of SPEC.md; not implementation assets

### Spec output requirements

Every SPEC.md produced through the conversational process must include:
- `## User Flows` — if the feature has user-facing elements (from UX Designer)
- `## Usability Requirements` — what must be easy, discoverable, or accessible (from UX Designer)
- `## Design Direction` — visual and layout guidance (from Visual Designer, if applicable)
- `## Test Strategy` — tooling and coverage expectations (Epic 12)
- `## Acceptance Criteria` — functional correctness gates

### Steps

1. Update Spec role doc: conversational spec mode is the required process for all new features; document the expected conversation structure (questions → options → agreement → SPEC.md commit)
2. Write `policies/spec-process.md`: define conversational spec as policy — conversation structure, human approval gate, and SPEC.md as the committed record of what was agreed
3. Add `## User Flows`, `## Usability Requirements`, `## Design Direction` as required SPEC.md sections when the feature has user-facing elements; add to `scripts/validate-issue-ready.py`
4. Write `agents/specialists/ux-designer.md` template — base identity, refinement prompts, expected output format (see Epic 11 for template schema)
5. Write `agents/specialists/visual-designer.md` template — base identity, refinement prompts, expected output format
6. Update Spec role doc: when a feature has user-facing elements, Spec must spawn UX Designer and (if applicable) Visual Designer specialists and incorporate their output before finalising SPEC.md
7. Update QA role doc: for features with user-facing elements, QA must spawn the `usability-reviewer` specialist (defined in Epic 11) and include usability findings in the `## Tests` section of its callback report
8. Add usability review outcome as an input to Spec's `spec-satisfied` merge gate decision — Spec must confirm usability requirements were met before applying the label

---

## Program of Works — Sequencing

All decision points were resolved on 2026-04-08. Work can begin on all epics immediately. Epic 10 implementation remains pending until Epic 9 is complete and the bounded pilot is run, and production adoption requires that pilot to pass its success criteria.

| Order | Epic | Notes |
|---|---|---|
| 1 | Epic 3 — Callback schema | Unblocked; foundational — all other epics depend on structured callbacks |
| 2 | Epic 2 — Issue readiness validation | Unblocked; quick win; gates Builder work immediately |
| 3 | Epic 1 — Task ledger | Unblocked; critical for Orchestrator persistence |
| 4 | Epic 9 — Decision record schema | Unblocked; solves rationale-loss problem independently |
| 4 | OpenClaw config — watchdog cron | Configure as soon as Epic 1 ledger schema is finalised; no other dependency |
| 5 | Epic 11 — Specialist subagent template library | Depends on Epic 3 (specialists must return structured callbacks); must complete before Epic 14 |
| 6 | Epic 14 — Conversational spec + UX/Design specialists | Depends on Epic 11 (UX/Design specialist templates must exist); process change can begin immediately, but template authoring blocks full completion |
| 7 | Epic 12 — Testing standards and quality gates | Depends on Epic 14 (Spec-defined test strategy is part of the spec process); README contract and test-presence gate are unblocked and can start in parallel |
| 8 | Epic 4 — Session health check | Depends on Epic 1 |
| 9 | Epic 5 — Merge gate + PR line comments | Depends on Epic 3; usability gate from Epic 14 feeds into `spec-satisfied` label logic |
| 10 | Epic 13 — Adversarial QA + bug regression workflow | Depends on Epic 3 (callbacks), Epic 12 (test standards), and Epic 5 (PR line comments for bug reports) |
| 11 | Epic 7 — Deployment security hardening | Mostly independent; can run in parallel with 8–10 |
| 12 | Epic 6 — Workflow YAML contracts | Depends on Epics 1–5, 12, 13, 14 being stable — YAMLs encode the finalised workflow shape |
| 13 | Epic 8 — Onboarding script | Depends on Epics 1–5 stable; wraps all setup into a single entry point |
| 14 | Epic 10 — Memory substrate pilot | Pilot begins after Epic 9; implementation (if adopted) sequences after pilot concludes |
