# Framework Improvement Roadmap

This roadmap is the **current remaining work only**.

Completed roadmap items have been removed.
If something is partly implemented, it stays here with the caveat.
If something is still open, it stays open.

_Last audited: 2026-04-23._

---

## Completed since the original roadmap

The following original roadmap areas are now implemented enough that they no longer belong in the active roadmap:

- durable task ledger
- issue readiness validation
- callback schema and validation
- merge gate enforcement and PR line comments
- workflow YAML contracts and validation
- project onboarding script
- framework configuration and parameterisation
- Security named agent
- Release Manager named agent
- specialist subagent template library
- testing standards and executable quality gates
- adversarial QA and bug regression workflow scaffolding
- conversational Spec process and UX/design specialist support
- Triage archetype and project-scoped seven-agent topology

Some of those areas still have operational rough edges, but the core framework work exists and is no longer roadmap-shaped greenfield work.

---

## Partials and open work

### 1. Session health and deployment reliability

**Status:** Partially implemented

What exists now:
- `scripts/check-framework-version.sh`
- `policies/session-rollover.md`
- Orchestrator startup guidance to run the version check
- deployed SHA stamping in `FRAMEWORK_NOTES.md`

What is still not good enough:
- named-agent session priming still has known failure / hang behaviour in real deploys
- the safe operational fallback is still recovery via warning handling or `--no-prime`, which means deploy/onboarding reliability is not fully solved
- this area recently needed docs/tool contract cleanup, which is a sign it is implemented but still fragile

### Remaining work

1. Make named-agent priming reliably complete during deploy and onboarding without manual recovery.
2. Treat priming failure as a first-class, well-bounded state instead of a semi-manual recovery path.
3. Tighten deploy/onboard reporting so operators can tell immediately whether priming failed, was skipped, or completed cleanly.
4. Keep the session version check contract stable: workspace root as argument, optional notes path as second argument.

---

### 2. Deployment hardening

**Status:** Partially implemented

This was one of the least clearly finished areas in the original roadmap, and it still should not be treated as done without explicit verification.

### Remaining work

1. Audit `deploy/sync-framework.sh` for symlink and ownership safety checks around the OpenClaw workspace root.
2. Audit workspace bootstrap / deploy scripts for destructive overwrite behaviour and confirm whether prompts, force flags, or dry-run coverage are sufficient.
3. Verify `validate-framework.sh` cross-checks deploy manifests strongly enough to catch accidental sync of local-only files.
4. Document the final threat model and hardening boundary clearly so this does not drift back into hand-wavy “probably fine”.

---

### 3. Unified action-event telemetry

**Status:** Partially implemented

What exists now:
- real helper-backed action surfaces
- durable task / release / project state artifacts
- active current-state auditability docs in `docs/delivery/action-taxonomy.md`
- proposal-layer future event schema and type registry under `docs/proposal/`

What is still missing:
- no canonical typed event stream
- no framework-wide event envelope emitted by wrappers
- no durable correlation model across dispatch, callback, issue, PR, release, deploy, and priming actions

### Remaining work

1. Define the minimum production event envelope to emit from existing wrappers.
2. Instrument the highest-value existing helpers first:
   - `scripts/dispatch-named-agent.sh`
   - `scripts/send-agent-callback.sh`
   - `scripts/create-agent-issue.sh`
   - `scripts/create-agent-pr.sh`
   - `scripts/update-agent-pr-body.sh`
   - `scripts/post-agent-comment.sh`
   - `scripts/post-pr-line-comment.sh`
   - `scripts/update-agent-wiki-page.sh`
3. Add correlation identifiers and parent/child linkage so a single delivery flow can be reconstructed without transcript archaeology.
4. Keep proposal schemas under `docs/proposal/` until wrappers actually emit them.

---

### 4. Decision records in live project operation

**Status:** Partially implemented

What exists now:
- `schemas/decision-record.md`
- `templates/decision-record.md`
- `scripts/validate-decision-record.py`
- framework validation coverage

What is still weak:
- the framework capability exists, but decision records are not yet clearly embedded as a consistently used live operating habit across project work
- retrieval discipline for rationale is still mostly process-level, not strongly operationalised

### Remaining work

1. Tighten role docs so significant routing, scope, and acceptance decisions consistently produce decision records in project repos.
2. Add stronger examples and operator guidance for when a decision is important enough to require a record.
3. Confirm downstream project flows actually reference decision records in callbacks and review paths, rather than leaving them as a dormant framework feature.

---

### 5. Memory retrieval substrate pilot

**Status:** Open

The original mempalace-style pilot has not been completed as an adopted framework capability.

### Remaining work

1. Choose one pilot project corpus.
2. Populate it from real decision records rather than summaries.
3. Run rationale-retrieval tests against real “why did we decide this?” questions.
4. Record findings and either adopt, reject, or replace the retrieval substrate.
5. Keep decision records as the protocol layer regardless of retrieval backend choice.

---

### 6. Roadmap and status hygiene

**Status:** Open

This file itself became badly stale. The framework now has active docs, proposal docs, runtime docs, and historical review material, so status drift is a real maintenance problem.

### Remaining work

1. Keep `ROADMAP.md` as a current remaining-work document, not a history dump.
2. When a roadmap item lands, remove it here and move any future-state residue into `docs/proposal/` if needed.
3. When an area is only partly landed, record the specific caveat instead of leaving vague “done-ish” language.
4. Avoid reintroducing stale topology counts or outdated agent inventories.

---

## Notable caveats from the original roadmap audit

These were the main stale assumptions in the old file:

- the framework no longer has a six-agent project topology, it has seven including Triage
- Security and Release Manager are no longer future epics, they are implemented archetypes
- specialist templates are no longer a proposal, they exist in `agents/specialists/`
- workflow schemas and validators are no longer hypothetical
- config parameterisation is no longer future work, it is part of the current framework setup

---

## Summary

What remains is mostly **operational reliability, stronger auditability, and keeping the docs honest**.

The big framework-building epics are mostly done.
The main unfinished areas are:
- deploy/priming reliability
- deployment hardening verification
- unified action-event telemetry
- live operating discipline around decision records
- optional memory retrieval pilot
