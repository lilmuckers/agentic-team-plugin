# Framework Improvement Roadmap

This roadmap captures the next phase of development for the agentic-team-plugin framework. It is organized as a set of epics with implementation steps and decision points that must be resolved before or during each epic.

Decision points are marked **DECIDE:** — these require a judgement call before the relevant work can proceed.

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

1. Define ledger schema — fields: task ID, agent assigned, delegated timestamp, expected callback fields, outcome status, last updated
2. Write `scripts/update-task-ledger.py` — append or update a ledger entry given task ID and status
3. Add ledger read/write to Orchestrator role doc as a mandatory operating rule
4. Add a session startup step to Orchestrator: read ledger on start, surface any overdue tasks immediately before taking new work
5. Write `scripts/validate-task-ledger.py` to validate ledger schema correctness

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
5. Add merge gate label check to `scripts/validate-agent-artifacts.py`

### PR Line-Level Review Comments

**Policy (resolved):** When agents have line-specific feedback on a PR, they must post it as a review comment against the relevant line, not as a top-level PR comment. Top-level PR comments are reserved for summary-level observations (e.g. overall outcome, blockers, next action).

6. Write `scripts/post-pr-line-comment.sh <pr-number> <commit-sha> <file-path> <line> <body>` — wraps `gh api /repos/.../pulls/.../comments` to post a line-anchored review comment
7. Update QA role doc: line-specific feedback must use `post-pr-line-comment.sh`; top-level PR comments are for summary only
8. Update Builder role doc: when addressing QA feedback, expect line comments and resolve them via `gh pr review` dismiss or by pushing a fix commit
9. Add `post-pr-line-comment.sh` to `docs/delivery/agent-tooling-helpers.md`

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
7. Wire `validate-decision-record.py` into `validate-agent-artifacts.py` for CI use
8. Add decision record reference to the callback template (`templates/callback-report.md`): the `## Artifacts` section should list any decision records produced during the task

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

Run against one project corpus. A retrieval is successful if agents can answer these questions without the human restating context:

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

## Program of Works — Sequencing

All decisions resolved 2026-04-08 except D11 (mempalace spike, pending OpenClaw evaluation). Work can begin on all other epics immediately.

| Order | Epic | Notes |
|---|---|---|
| 1 | Epic 3 — Callback schema | Unblocked; foundational — other epics depend on agents returning structured callbacks |
| 2 | Epic 2 — Issue readiness validation | Unblocked; quick win; gates Builder work immediately |
| 3 | Epic 1 — Task ledger | Unblocked; critical for Orchestrator persistence |
| 4 | Epic 9 — Decision record schema | Unblocked; independent of all other epics; solves the rationale-loss problem immediately |
| 5 | Epic 4 — Session health check | Depends on Epic 1 |
| 6 | Epic 5 — Merge gate + PR line comments | Depends on Epic 3 |
| 7 | Epic 7 — Deployment security hardening | Mostly independent; can run in parallel with Epics 4–6 |
| 8 | Epic 6 — Workflow YAML contracts | Depends on Epics 1–5 being stable |
| 9 | OpenClaw config — watchdog cron | Configure after task ledger (Epic 1) schema is finalised |
| 10 | Epic 8 — Onboarding script | Depends on Epics 1–5 stable |
| 11 | Epic 10 — Memory substrate spike | OpenClaw spike runs in parallel; implementation (if adopted) sequences after Epic 9 |
