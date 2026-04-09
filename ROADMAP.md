# Framework Improvement Roadmap

This roadmap captures the next phase of development for the agentic-team-plugin framework. It is organized as a set of epics with implementation steps and decision points.

All decisions were resolved 2026-04-08. The Decision Points Index below is a resolved record — it is not a blocker list.

---

## Decision Points Index

Resolved decisions are recorded here and inline in each epic for traceability.

| # | Decision | Status | Blocks |
|---|---|---|---|
| D1 | Where does the task ledger live? | **Resolved 2026-04-08** — markdown file committed to project repo (`docs/delivery/task-ledger.md`) | Epic 1 |
| D2 | How does OpenClaw enforce persistent session continuity via `--session-id`? | **Resolved 2026-04-08** — `--session-id` provides routing identity only, not memory continuity; task ledger is the sole persistence mechanism | Epics 1, 4, OpenClaw config |
| D3 | Merge gate mechanism — labels + branch protection, or GitHub Actions? | **Resolved 2026-04-08** — labels (`qa-approved`, `spec-satisfied`, `orchestrator-approved`) + branch protection + GH Actions workflow in `repo-templates/` | Epic 5 |
| D4 | Callback format — structured markdown or JSON? | **Resolved 2026-04-08** — structured markdown with required section headers | Epic 3 |
| D5 | Does OpenClaw have a native heartbeat/cron mechanism? | **Resolved 2026-04-08** — yes; use native OpenClaw cron (not system cron or watchdog script) | OpenClaw config |
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

### Ledger format

The ledger uses markdown sections with human-readable headings, but the structured payload inside each entry is JSON. Each entry should expose readable section names while keeping machine-updatable detail in JSON fields.

Required JSON fields per entry:
- `task`
- `state`
- `current_action`
- `next_action`
- `history` (array of timestamped actions)

### Steps

1. Define ledger schema in `docs/delivery/task-ledger.md` as markdown sections with embedded JSON payloads for task details and state
2. Write `scripts/update-task-ledger.py` — append or update a ledger entry's JSON payload given task ID and status
3. Add ledger read/write to Orchestrator role doc as a mandatory operating rule
4. Add a session startup step to Orchestrator: read ledger on start, surface any overdue tasks immediately before taking new work
5. Write `scripts/validate-task-ledger.py` to validate ledger schema correctness, required section headings, and JSON structure

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
11. Add commit-then-push rule to `policies/git-safety.md`: every commit must be immediately followed by `git push` if a remote is configured; push failures must be surfaced to the Orchestrator, never resolved silently; force-push is never permitted
12. Add commit-then-push requirement to Builder, Orchestrator, and Spec role docs

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

Six named agents per project, using the project-scoped naming convention:

```
orchestrator-<project-slug>
spec-<project-slug>
security-<project-slug>
release-manager-<project-slug>
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
| `security-<project>` | Persistent | `session:<project>-security` |
| `release-manager-<project>` | Persistent | `session:<project>-release-manager` |
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

### 7. Commit-then-Push Policy

**Policy:** Every commit an agent makes must be immediately followed by a push to the remote, if a remote is configured for the repo. Agents must not leave commits in a local-only state.

Rationale: local-only commits are invisible to other agents, the human, and CI. The task ledger and merge gate both rely on GitHub as the source of truth — a commit that has not been pushed has not happened as far as the rest of the system is concerned.

Rules:
- After every `git commit`, run `git push` before doing any further work
- If no remote is configured, the commit is acceptable as-is; the agent must note the absence of a remote in its callback report
- Force-push is never permitted; if a push is rejected, the agent must halt and surface the conflict to the Orchestrator rather than resolving it silently
- This applies to all agents that make commits: Builder (feature branches), Orchestrator (task ledger updates), Spec (SPEC.md, decision records)

Add this rule to `policies/git-safety.md` and reference it in each role doc that makes commits.

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

**Builder specialists** (infrastructure and environment):
- `agents/specialists/docker-environment.md` — authors Dockerfiles, Compose files, and devcontainer configuration; implements the Docker-first local development environment policy (see note below); refinement must specify base image, service topology, and any project-specific environment requirements
- `agents/specialists/aws-infrastructure.md` — implements AWS infrastructure using Terraform with AWS-idiomatic provider patterns, state backend conventions, and IAM; refinement must specify target services, region, and environment (dev/staging/prod)
- `agents/specialists/gcp-infrastructure.md` — implements GCP infrastructure using Terraform with GCP-idiomatic provider patterns and project/IAM model; refinement must specify target services, project, and environment
- `agents/specialists/azure-infrastructure.md` — implements Azure infrastructure using Terraform with Azure-idiomatic provider patterns, resource group model, and RBAC; refinement must specify target services, subscription, and environment
- `agents/specialists/terraform-core.md` — provider-agnostic Terraform patterns: module structure, state management, variable conventions, output contracts; used as a base refinement layer for the cloud-specific implementers above

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

**Spec specialists** (infrastructure and platform architecture):
- `agents/specialists/cicd-architect.md` — designs CI/CD pipeline architecture; output: pipeline design section of SPEC.md covering stages, gates, environment promotion model, rollback strategy, and tooling selection; must account for Docker-first environment policy
- `agents/specialists/aws-architect.md` — designs AWS infrastructure architecture; output: cloud architecture section of SPEC.md covering service selection, network topology, IAM model, data residency, and scaling strategy; counterpart to `aws-infrastructure.md` Builder specialist
- `agents/specialists/gcp-architect.md` — designs GCP infrastructure architecture; counterpart to `gcp-infrastructure.md`
- `agents/specialists/azure-architect.md` — designs Azure infrastructure architecture; counterpart to `azure-infrastructure.md`

### Docker-first local development policy

**Policy (applies to all projects):** Local development environments must run inside Docker containers. The host node must not require project-specific runtime dependencies (language runtimes, databases, package managers) to be installed directly.

Rationale:
- Keeps the host node clean and reusable across projects
- Enables rapid deployment across a swarm of nodes without per-node provisioning
- Ensures consistency between agent-run and human-run local environments
- Aligns local dev with the container model used in CI and production

Implementation requirements:
- Every project must have a `docker-compose.yml` (or equivalent) at the repo root that brings up the full local development environment
- `devcontainer.json` must be present for IDE/agent workspace integration
- The README's `## Run` section (Epic 12) must describe starting the environment via Docker, not via direct local installation
- The `docker-environment.md` Builder specialist is the default implementation path for all local dev environment work; refinement specifies the project's service topology

The `cicd-architect.md` Spec specialist must account for this policy when designing pipelines — container-based CI is the assumed baseline.

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
11. Write `agents/specialists/docker-environment.md` — Docker-first local dev specialist; base identity covers Dockerfile authoring, Compose file design, and devcontainer configuration; authority boundary: does not own CI pipeline design (that is `cicd-architect.md`) or production infrastructure (that is the cloud specialists)
12. Write `agents/specialists/aws-infrastructure.md`, `agents/specialists/gcp-infrastructure.md`, `agents/specialists/azure-infrastructure.md` — cloud infrastructure implementers; each covers provider-idiomatic Terraform patterns for the respective cloud; all use `terraform-core.md` conventions as a baseline
13. Write `agents/specialists/terraform-core.md` — provider-agnostic Terraform conventions; intended as a shared reference layer for cloud implementers, not used directly
14. Write `agents/specialists/cicd-architect.md` — CI/CD pipeline design for Spec; expected output is a pipeline architecture section of SPEC.md; must treat container-based CI as the assumed baseline per the Docker-first policy
15. Write `agents/specialists/aws-architect.md`, `agents/specialists/gcp-architect.md`, `agents/specialists/azure-architect.md` — cloud architecture designers for Spec; expected output is a cloud architecture section of SPEC.md; each is the design-time counterpart to its corresponding Builder implementer
16. Add Docker-first local dev policy to `policies/repo-management.md` — every project must have `docker-compose.yml` and `devcontainer.json`; `## Run` section of README must describe Docker-based startup
17. Add `docker-compose.yml` and `devcontainer.json` presence checks to `scripts/validate-readme-contract.sh`
18. Commit Docker-first decision as a framework-level decision record in `docs/decisions/` — decision, rationale (host cleanliness, swarm deployment, human/agent consistency), alternatives rejected (native installs), constraints applied

---

## Epic 12 — Testing Standards and Executable Quality Gates

**Problem:** There is no enforced standard for test presence, test executability, or how the application should be built and verified. Builder produces code; QA reviews it; but neither is mechanically required to prove the application actually runs or that tests exist and pass.

**Goal:** Define and enforce: (1) a README-first contract for every project so any agent or human can build, run, and verify the application; (2) a requirement that all PRs include executable tests; (3) a Spec-owned test strategy that defines the tooling appropriate to the application type.

### README-first contract

The first substantive content of every project README must be actionable instructions covering three things, in order:
1. How to build the application
2. How to run it
3. How to verify it is running correctly (a smoke test or health check a human can execute in under two minutes)

If "run" is not a meaningful concept for the repo type (for example, a library, framework, template, or policy repo), the README must instead define the equivalent executable verification path.

This is not a documentation nicety — it is a quality gate. If QA cannot follow the README to a running application, or to the equivalent executable verification path where "run" is not applicable, the PR is blocked.

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
5. If the bug cannot be expressed as an automated regression test, Builder must document why, and Spec must explicitly accept that exception before the fix can proceed without one
6. The regression test is committed alongside the fix; QA re-verifies both

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

Spec spawns UX and Design specialists during the specification conversation when the feature has user-facing elements and usability or visual decisions materially affect the outcome. These specialists contribute to the spec, not to implementation. They are not required for every tiny UI tweak.

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
4. Confirm `agents/specialists/ux-designer.md` and `agents/specialists/visual-designer.md` are complete (authored in Epic 11) — Epic 14 depends on both
5. Update Spec role doc: when a feature has user-facing elements, Spec must spawn UX Designer and (if applicable) Visual Designer specialists using `prepare-specialist-spawn.py`, and incorporate their output before finalising SPEC.md
6. Update QA role doc: for features with user-facing elements, QA must spawn the `usability-reviewer` specialist (defined in Epic 11) and include usability findings in the `## Tests` section of its callback report
7. Add usability review outcome as an input to Spec's `spec-satisfied` merge gate decision — Spec must confirm usability requirements were met before applying the label

---

## Epic 15 — Security Agent

**Problem:** Security concerns are currently addressed only by the `qa-security.md` specialist, which runs as a stateless pass during PR review. This covers routine code-level checks but misses three critical points: threat modelling during specification, security-aware review of implementation choices during build, and a formal security sign-off as a merge gate condition. Security knowledge is also project-specific and accumulates — a stateless specialist loses that context on every invocation.

**Goal:** Add Security as a fifth named persistent agent archetype, operating at three points in the delivery lifecycle — spec, build review, and merge gate — with a `security-approved` label owned exclusively by the Security agent.

### Why a named persistent agent, not a specialist

The `qa-security.md` specialist remains appropriate for routine PR review on changes that don't touch sensitive areas. The Security agent is warranted when:
- The feature touches authentication, authorisation, session management, or identity
- The feature handles personally identifiable or sensitive data
- The feature exposes or consumes external interfaces (APIs, webhooks, file uploads, etc.)
- The feature modifies infrastructure, deployment configuration, or access controls

The Security agent must be persistent (like Orchestrator and Spec) because it accumulates project-specific knowledge: the threat model, data flows, trust boundaries, prior security decisions, and known risk areas. A fresh stateless session cannot reason about whether a new change undermines a previously-established security property.

### Session topology

| Agent | Session type | Session target |
|---|---|---|
| `security-<project>` | Persistent | `session:<project>-security` |

### Touch point 1 — Specification

When Spec identifies that a feature touches a sensitive area (see routing criteria above), it must engage the Security agent during the specification conversation before SPEC.md is finalised.

Security's contribution to the spec:
- **Threat model** — what could go wrong, who are the adversaries, what are the attack surfaces
- **Trust boundaries** — what is trusted, what is not, where validation must occur
- **Security requirements** — specific constraints the implementation must satisfy (e.g. "session tokens must not be logged", "all file uploads must be validated server-side before processing")
- **Rejected approaches** — implementation patterns that must not be used, and why

These are recorded as a `## Security Requirements` section in SPEC.md and as a decision record in `docs/decisions/`.

### Touch point 2 — Build review

When a PR involves a sensitive area, the Orchestrator routes it to the Security agent for review before QA begins. Security reviews:
- Whether the implementation satisfies the security requirements from SPEC.md
- Whether new attack surfaces have been introduced
- Whether trust boundary violations exist (e.g. unsanitised input crossing a boundary, secrets handled incorrectly)
- Whether the implementation matches the approved approach from the spec

Security posts findings as line comments using `scripts/post-pr-line-comment.sh`. If findings are material, Security returns a BLOCKED callback — the Orchestrator routes back to Builder, not to QA.

### Touch point 3 — Merge gate

Security owns the `security-approved` label. For sensitive-area PRs, all three existing labels plus `security-approved` must be present before merge. The merge gate workflow must be updated to check for `security-approved` when the PR is tagged with a security-scope label.

Routing rule: the Orchestrator determines whether a PR is in-scope for the Security agent based on the PR's labels and the feature's SPEC.md security requirements section. If `## Security Requirements` is present in SPEC.md, the security gate is required.

### Specialist templates owned by Security

The existing `qa-security.md` specialist is reclassified as a Security-owned template, used by the Security agent for focused sub-tasks (e.g. dependency audit, OWASP checklist pass, regex analysis). QA continues to use it for routine review on non-sensitive PRs. Security uses it internally for narrow analysis tasks.

Add two new specialists to `agents/specialists/`:
- `agents/specialists/threat-modeller.md` — structured threat modelling (STRIDE or equivalent); output: threat model section of SPEC.md
- `agents/specialists/dependency-auditor.md` — reviews third-party dependencies for known vulnerabilities and licence risk; output: dependency audit report

### Steps

1. Write `agents/security.md` — Security agent role doc; define operating principles, session model, touch point responsibilities, authority boundaries
2. Add `security-<project-slug>` to the named agent definitions — four agents per project becomes five; update `scripts/create-project-scoped-agents.sh` and `scripts/deploy-named-agents.py`
3. Add `security-<project>` to the session topology table in `docs/delivery/hybrid-session-topology.md` and `OpenClaw Configuration Required` section
4. Add `security-approved` label to `docs/delivery/github-labels.md`
5. Update `repo-templates/.github/workflows/merge-gate.yml` — add conditional check: if PR has security-scope label, require `security-approved` in addition to the three existing labels
6. Add `security-scope` label to `docs/delivery/github-labels.md` — applied by Orchestrator when routing criteria are met
7. Add routing logic to Orchestrator role doc: evaluate each feature against security routing criteria; apply `security-scope` label if met; route to Security at spec time and again at PR review time before QA
8. Update Spec role doc: when a feature meets security routing criteria, engage Security agent during the specification conversation; do not finalise SPEC.md on sensitive features without a `## Security Requirements` section
9. Add `## Security Requirements` as a conditional required section in `scripts/validate-issue-ready.py` — if `security-scope` label is present, issue must reference security requirements before it is ready for build
10. Update merge gate check in Orchestrator role doc: for `security-scope` PRs, confirm `security-approved` is present before applying `orchestrator-approved`
11. Write `agents/specialists/threat-modeller.md` — base identity, refinement prompts, STRIDE output format
12. Write `agents/specialists/dependency-auditor.md` — base identity, refinement prompts, expected output format
13. Reclassify `qa-security.md` as shared between Security and QA in `docs/delivery/named-agent-specialist-model.md` — Security owns it; QA may use it for routine non-sensitive PRs
14. Update `scripts/onboard-project.sh` to create `security-<project-slug>` named agent and deploy its workspace bootstrap
15. Deploy workspace bootstrap for Security agent: same file set as other persistent agents (`AGENTS.md`, `SOUL.md`, `IDENTITY.md`, `FRAMEWORK_RUNTIME_BUNDLE.md`, `FRAMEWORK_NOTES.md`, `USER.md`)
16. Add Security agent to `docs/delivery/named-agent-specialist-model.md` authority model — Security does not own routing or delivery decisions; it owns security sign-off only
17. Update workflow YAMLs (`implement-feature.yaml`, `fix-bug.yaml`) to include the Security agent touch points as conditional steps gated on `security-scope`

---

## Epic 16 — Release Manager Agent

**Problem:** There is no defined agent responsible for release orchestration. Releases are ad hoc — no standardised versioning, no structured pre-release testing loop, no formal issue triage before a release is cut, and no consistent release notes. The existing `prepare-release.yaml` workflow stub is insufficient and will be replaced by this epic.

**Goal:** Add Release Manager as a sixth named persistent agent archetype that owns the full release lifecycle: from receiving the release signal through pre-release testing, issue triage and fix iteration, release candidate validation, and final release publication on GitHub.

### Why a named persistent agent

The release lifecycle is multi-session and stateful. A Release Manager session must track which beta iteration it is on, which issues were accepted/deferred/rejected, which have been fixed and merged, and when to promote to the next stage. Ephemeral sessions cannot hold this state. Release Manager is persistent, like Orchestrator and Spec.

### Session topology

| Agent | Session type | Session target |
|---|---|---|
| `release-manager-<project>` | Persistent | `session:<project>-release-manager` |

### Release workflows

Release Manager supports multiple release workflows. The default workflow is defined below. Additional workflows (e.g. continuous delivery, scheduled releases, hotfix releases) may be defined in future. The active workflow for a project is agreed with Spec during onboarding or when a release cadence is first established, and recorded as a decision record.

---

### Default release workflow

#### Prerequisites and conventions

- **Main branch is unstable.** Releasable state is defined by the release process, not branch state.
- **SemVer versioning.** Starting version is agreed with Spec or the human at project onboarding and recorded as a decision record.
- **Version scale (major/minor/patch)** is determined by Spec and Orchestrator based on the scope of changes since the last release. Release Manager applies the scale mechanically — it does not determine it.
- **Pre-release issue tagging.** All issues found during release testing are labelled with the release version they were discovered against (e.g. `release:v1.2.0`). If a finding already exists as an open issue, it is skipped — not re-raised.
- **Issue triage authority.** Spec and Orchestrator jointly triage release issues using three verdicts:
  - **Reject** — not a real issue; close it
  - **Accept** — must be fixed before this release can progress
  - **Defer** — add to backlog as a separate issue/refinement; does not block the release

---

#### Step 1 — Release signal

Spec or Orchestrator determines that a release is due — based on milestone completion, feature set, scheduled cadence, or human instruction. They notify Release Manager with:
- The release scope (what is included)
- The version scale (major / minor / patch)
- The agreed starting version if this is the first release

Release Manager opens a release tracking issue on GitHub to record the release state throughout the process.

---

#### Step 2 — Pre-release tag: beta 1

Release Manager:
1. Calculates the next SemVer from the last release tag and the supplied scale
2. Creates a pre-release Git tag: `vX.Y.Z-beta1`
3. Creates a GitHub pre-release from that tag with the label **Beta 1**
4. Generates release notes (see Release Notes format below)
5. Updates the release tracking issue with current state

---

#### Step 3 — Release testing

Release Manager instructs QA and Security agents to run full release testing against the tagged beta. This is distinct from PR review — it is adversarial, broad, and not limited to changed code:

**QA** runs:
- Full adversarial pass across the entire application (not just changed areas)
- Regression suite against all acceptance criteria since the last release
- README build/run/verify contract verification
- Any test types defined in the project's test strategy

**Security** runs:
- Full threat model review against current codebase
- Dependency audit
- Attack surface review across all external interfaces
- Anything surfaced by the `threat-modeller` and `dependency-auditor` specialists

Both agents report findings as new GitHub issues, each labelled `release:vX.Y.Z`. Before creating an issue, they must check whether it already exists as an open issue — if it does, it is skipped.

---

#### Step 4 — Issue triage

Release Manager presents all newly created issues to Spec and Orchestrator for triage. Each issue receives one of:
- **Reject** — Release Manager closes the issue with a documented reason
- **Accept** — issue must be fixed before this release progresses
- **Defer** — issue remains open, is assigned to the backlog, and does not block the release

Triage decisions are recorded as decision records by Spec (Epic 9 format).

---

#### Step 5 — Fix iteration

For each accepted issue, Release Manager delegates to Orchestrator to assign Builder through the standard delivery workflow (issue readiness validation → build → QA review → merge gate). Release Manager monitors the task ledger for completion of each accepted issue.

When all accepted issues are merged, Release Manager returns to Step 2 and cuts the next beta (`vX.Y.Z-beta2`, `beta3`, etc.), repeating the test→triage→fix loop until QA and Security return no accepted issues.

---

#### Step 6 — Release candidate

Once a beta iteration completes with no accepted issues, Release Manager promotes to a release candidate:
1. Creates tag `vX.Y.Z-rc1`
2. Creates a GitHub pre-release with the label **Release Candidate 1**
3. Generates release notes (see format below)
4. Instructs QA and Security to run the full release testing suite again against the RC

Any issues found against the RC go through the same triage→fix→beta loop, then a new RC is cut (`rc2`, `rc3`, etc.) until the RC iteration also completes clean.

---

#### Step 7 — Final release

Once an RC iteration completes with no accepted issues:
1. Release Manager creates the final Git tag: `vX.Y.Z`
2. Creates a GitHub release (not pre-release) with the full release notes
3. Closes the release tracking issue
4. Notifies Orchestrator and Spec that the release is complete

---

### Release notes format

#### Full release (`vX.Y.Z`)

- **Changes since `vX.Y.(Z-1)`** — all merged PRs and resolved issues since the last full release, grouped by type (features, fixes, security, infrastructure)
- Generated from Git log and closed issues labelled with the release version or merged since the last release tag

#### Pre-release (`vX.Y.Z-betaN` or `vX.Y.Z-rcN`)

Two sections, in order:
1. **Changes since `vX.Y.Z-beta(N-1)` (or since the previous pre-release in this cadence)** — what changed in this iteration specifically
2. **Changes since `vX.Y.(Z-1)` (the last full release)** — the full scope of what this release contains

This gives reviewers both a delta view (what's new in this iteration) and a cumulative view (what the full release contains).

---

### Release state tracking

Release Manager maintains a release state file committed to the project repo at `docs/delivery/release-state.md`. This is distinct from the task ledger — it records the release-specific state: current version, current stage (beta/rc/released), iteration number, issue triage decisions, and the history of tags cut.

Format mirrors the task ledger (markdown sections with embedded JSON payloads).

---

### Steps

1. Write `agents/release-manager.md` — Release Manager role doc; define operating principles, session model, release workflow, authority boundaries (Release Manager does not own issue routing — it delegates to Orchestrator; it does not triage issues — that is Spec/Orchestrator)
2. Add `release-manager-<project-slug>` to named agent definitions; update `scripts/create-project-scoped-agents.sh` and `scripts/deploy-named-agents.py`
3. Add `release-manager-<project>` to session topology table in `docs/delivery/hybrid-session-topology.md` and OpenClaw Configuration Required section
4. Define release state file schema in `docs/delivery/release-state.md` — fields: `project`, `current_version`, `stage` (beta/rc/released), `iteration`, `last_full_release`, `issues_accepted`, `issues_deferred`, `issues_rejected`, `tags_cut` (array), `history` (array of timestamped state transitions)
5. Write `scripts/update-release-state.py` — append or update release state entries; analogous to `update-task-ledger.py`
6. Write `scripts/validate-release-state.py` — validates release state file schema
7. Write `scripts/cut-release-tag.sh <tag> <pre-release|release>` — creates a Git tag and pushes it; creates a GitHub release or pre-release via `gh release create`; enforces the SemVer format and pre-release naming conventions (`-betaN`, `-rcN`)
8. Write `scripts/generate-release-notes.sh <from-tag> <to-tag> [since-full-release-tag]` — generates release notes from Git log and closed issues; outputs two-section format for pre-releases, single-section for full releases
9. Write `scripts/check-release-issues.sh <release-label>` — queries GitHub for open issues labelled with the current release version; outputs a list for triage; used by Release Manager to detect new findings from QA/Security
10. Add `release:vX.Y.Z` label creation to `scripts/cut-release-tag.sh` — ensure the label exists on GitHub before QA/Security begin testing against that tag
11. Replace `workflows/prepare-release.yaml` with a full release workflow contract against the `schemas/workflow.json` schema — encode the beta→triage→fix→rc→release state machine with `loops`, `on_blocked`, and `on_failure` paths
12. Update QA role doc: when instructed by Release Manager, run full release testing (not just changed-code review); check for existing open issues before creating new ones; label all new issues with the release version
13. Update Security role doc: same — full release security testing mode distinct from PR review mode; skip existing open issues
14. Update Orchestrator role doc: when Release Manager delegates accepted issues, route them through the standard delivery workflow and report completion back to Release Manager via the task ledger
15. Update `scripts/onboard-project.sh` to create `release-manager-<project-slug>` named agent and deploy its workspace bootstrap; agree and record starting version as part of `--with-github-setup` flag
16. Deploy workspace bootstrap for Release Manager: same file set as other persistent agents
17. Add Release Manager to `docs/delivery/named-agent-specialist-model.md` authority model — Release Manager does not own code review, security sign-off, or issue triage; it owns release state and release publication
18. Update OpenClaw config section to reflect six named agents per project

---

## Epic 17 — Framework Configuration and Parameterisation

**Problem:** The framework is not reusable in its current form. Operator identity (name, email domain, timezone), agent persona names, and the OpenClaw workspace root path are hardcoded across scripts, docs, and skills files. A new operator cannot adopt the framework without manually finding and replacing values spread across the codebase.

**Goal:** Extract all operator-specific and environment-specific values into a single framework config file that scripts source at runtime. The framework codebase itself becomes fully generic — no operator identity or environment paths appear in committed files.

### What is hardcoded and where

**Operator identity** (appears in 8+ files):
- `patrick-mckinley.com` — email domain for agent git identities; hardcoded in `scripts/set-agent-git-identity.sh`, `scripts/validate-agent-artifacts.py`, `docs/delivery/agent-tooling-helpers.md`, `docs/delivery/repo-management-operating-model.md`, `policies/repo-management.md`, `skills/agent-identities/SKILL.md`, `skills/semantic-commits/SKILL.md`
- `Patrick` / `Europe/London` — operator name and timezone hardcoded in `scripts/deploy-agent-workspace-bootstrap.py` and `scripts/deploy-project-agent-workspaces.py` (USER.md template)

**Agent persona names** (appears in 3+ files):
- `Cohen`, `Rowan` — specific persona names hardcoded in `scripts/set-agent-git-identity.sh` (usage examples) and `scripts/onboard-project.sh` (Rowan set as default identity)

**OpenClaw workspace root** (appears in 5+ scripts):
- `/data/.openclaw/` — hardcoded in `deploy/sync-framework.sh`, `scripts/deploy-agent-workspace-bootstrap.py`, `scripts/deploy-named-agents.py`, `scripts/create-project-scoped-agents.sh`, `scripts/onboard-project.sh`, `scripts/bootstrap-project-repo.sh`
- Note: `scripts/deploy-project-agent-workspaces.py` already accepts `--workspace-root`; others do not

### Config file

A single config file at `config/framework.yaml` is the source of truth for all operator-specific and environment-specific values. It is committed to the repo as a template with placeholder values; operators fill it in before first use.

```yaml
operator:
  name: ""               # Human operator's name (used in USER.md)
  callname: ""           # What agents should call the operator
  email_domain: ""       # Domain for agent git email addresses: bot-<archetype>@<email_domain>
  timezone: ""           # IANA timezone string, e.g. Europe/London

openclaw:
  workspace_root: ""     # Absolute path to OpenClaw workspace root, e.g. /data/.openclaw

# Agent persona names are optional. If omitted, the archetype name is used as the persona name.
# These are the names agents use to identify themselves in git commits and communications.
agent_personas:
  orchestrator: ""
  spec: ""
  builder: ""
  qa: ""
  security: ""
  release_manager: ""
```

A filled example is provided at `config/framework.yaml.example` but never committed as the live config.

`config/framework.yaml` is added to `.gitignore` — operator identity must not be committed to the framework repo. The `.yaml.example` file is committed as the template.

### How scripts consume the config

- Python scripts: use a shared `scripts/lib/config.py` loader that reads `config/framework.yaml` and exposes typed values; all scripts import it
- Shell scripts: use a shared `scripts/lib/config.sh` sourcing helper that reads `config/framework.yaml` via `yq` or a minimal parser and exports values as environment variables
- Scripts that currently hardcode values are updated to read from the config loader instead
- If `config/framework.yaml` is absent or a required field is empty, scripts exit with a clear error message identifying which field is missing

### Steps

1. Write `config/framework.yaml.example` — template with all fields, placeholder values, and inline comments explaining each field
2. Add `config/framework.yaml` to `.gitignore`
3. Write `scripts/lib/config.py` — Python config loader; reads `config/framework.yaml`, validates required fields are non-empty, exposes typed accessors; raises `ConfigError` with the missing field name if validation fails
4. Write `scripts/lib/config.sh` — shell config loader; sources `config/framework.yaml` using `yq` and exports `FRAMEWORK_OPERATOR_NAME`, `FRAMEWORK_OPERATOR_CALLNAME`, `FRAMEWORK_OPERATOR_EMAIL_DOMAIN`, `FRAMEWORK_OPERATOR_TIMEZONE`, `FRAMEWORK_OPENCLAW_WORKSPACE_ROOT`, and `FRAMEWORK_AGENT_PERSONA_<ARCHETYPE>` variables
5. Update `scripts/set-agent-git-identity.sh` — replace hardcoded `patrick-mckinley.com` with `$FRAMEWORK_OPERATOR_EMAIL_DOMAIN`; replace hardcoded persona name examples with `$FRAMEWORK_AGENT_PERSONA_<ARCHETYPE>`
6. Update `scripts/deploy-agent-workspace-bootstrap.py` — replace hardcoded `Patrick`, `Europe/London`, and `/data/.openclaw/` paths with config values
7. Update `scripts/deploy-project-agent-workspaces.py` — replace hardcoded `Europe/London` and operator name with config values; `--workspace-root` default reads from config
8. Update `scripts/validate-agent-artifacts.py` — replace hardcoded `patrick-mckinley\.com` regex with the operator email domain from config
9. Update `scripts/deploy-named-agents.py` — replace hardcoded `/data/.openclaw/` with config workspace root
10. Update `scripts/create-project-scoped-agents.sh` — replace hardcoded `/data/.openclaw/` with config workspace root
11. Update `scripts/onboard-project.sh` — replace hardcoded `Rowan` persona name and `/data/.openclaw/` paths with config values
12. Update `scripts/bootstrap-project-repo.sh` — replace hardcoded workspace root
13. Update `deploy/sync-framework.sh` — replace hardcoded `/data/.openclaw/` with config workspace root
14. Replace hardcoded email domain in `docs/delivery/agent-tooling-helpers.md`, `docs/delivery/repo-management-operating-model.md`, `policies/repo-management.md`, `skills/agent-identities/SKILL.md`, `skills/semantic-commits/SKILL.md` with `<operator-email-domain>` placeholder and a note that the value is set in `config/framework.yaml`
15. Write `scripts/validate-config.sh` — validates `config/framework.yaml` exists and all required fields are non-empty; exits non-zero with a descriptive message for each missing field; wire into `validate-framework.sh` as the first check
16. Add config validation to `scripts/onboard-project.sh` as a preflight step — onboarding fails immediately if config is invalid, before any agent or workspace is created
17. Update `README.md` with a **Getting Started** section: copy `config/framework.yaml.example` to `config/framework.yaml`, fill in operator values, then run `validate-config.sh` before any other script

---

## Program of Works — Sequencing

All decision points were resolved on 2026-04-08. Work can begin on all epics immediately. Epic 10 implementation remains pending until Epic 9 is complete and the bounded pilot is run, and production adoption requires that pilot to pass its success criteria.

| Order | Epic | Notes |
|---|---|---|
| 1 | Epic 17 — Framework config and parameterisation | Unblocked and foundational — all scripts that touch operator identity or workspace paths depend on this; do first |
| 2 | Epic 3 — Callback schema | Unblocked; all other epics depend on structured callbacks |
| 3 | Epic 2 — Issue readiness validation | Unblocked; quick win; gates Builder work immediately |
| 4 | Epic 1 — Task ledger | Unblocked; critical for Orchestrator persistence |
| 5 | Epic 9 — Decision record schema | Unblocked; solves rationale-loss problem independently |
| 5 | OpenClaw config — watchdog cron | Configure as soon as Epic 1 ledger schema is finalised; no other dependency |
| 6 | Epic 11 — Specialist subagent template library | Depends on Epic 3; must complete before Epic 14 |
| 7 | Epic 14 — Conversational spec + UX/Design specialists | Depends on Epic 11; process change can begin immediately, but template authoring blocks full completion |
| 8 | Epic 12 — Testing standards and quality gates | Depends on Epic 14; README contract and test-presence gate are unblocked and can start in parallel |
| 9 | Epic 4 — Session health check | Depends on Epic 1 |
| 10 | Epic 5 — Merge gate + PR line comments | Depends on Epic 3; usability gate from Epic 14 feeds into `spec-satisfied` label logic |
| 11 | Epic 13 — Adversarial QA + bug regression workflow | Depends on Epics 3, 12, and 5 |
| 12 | Epic 7 — Deployment security hardening | Mostly independent; can run in parallel with 9–11 |
| 13 | Epic 15 — Security agent | Depends on Epic 5 (merge gate); role doc and bootstrap authoring can begin immediately |
| 14 | Epic 16 — Release Manager agent | Depends on Epics 1, 13, and 15; role doc can begin immediately |
| 15 | Epic 6 — Workflow YAML contracts | Depends on Epics 1–5, 12, 13, 14, 15, 16 being stable |
| 16 | Epic 8 — Onboarding script | Depends on Epics 15, 16, and 17 (six named agents; config-driven paths) |
| 17 | Epic 10 — Memory substrate pilot | Pilot begins after Epic 9; implementation (if adopted) sequences after pilot concludes |
