# Project Activation Policy

A project passes through three explicit states. These are not descriptions — they are gates.
Skipping a gate is not permitted. Each gate has a concrete artifact that makes the state visible and verifiable.

---

## State 1: BOOTSTRAPPED

**Meaning:** The technical infrastructure exists. Agents and repo are wired up. No delivery work has started.

**Conditions (all required):**
- [ ] `scripts/onboard-project.sh` completed without error
- [ ] All seven project-scoped named agents exist and responded to the swarm identity smoke test
- [ ] Repo templates installed: `SPEC.md`, `docs/delivery/release-state.md`, `docs/delivery/task-ledger.md`, `.github/workflows/merge-gate.yml`, PR template, issue templates
- [ ] Each agent workspace has a `repo/` subdirectory clone of the project repo
- [ ] `docs/delivery/project-state.md` exists and records state `BOOTSTRAPPED`

**Who records it:** Orchestrator writes the initial `project-state.md` entry.

**What is not yet true:** No product definition exists. No backlog exists. No build work is legitimate yet.

---

## State 2: DEFINED

**Meaning:** The project has a real product definition, human-reviewed direction, and a shaped initial backlog. It is operationally ready for a human review gate.

**Conditions (all required):**
- [ ] `SPEC.md` is non-placeholder and contains a genuine product description, scope, non-goals, and acceptance-criteria direction
- [ ] At least one GitHub wiki page exists with durable project context (overview, architecture direction, or feature semantics)
- [ ] An initial backlog of issues exists, decomposed and labelled
- [ ] At least one issue passes `scripts/validate-issue-ready.py <issue-number>` (definition of ready)
- [ ] Human has reviewed and approved the spec/backlog direction — visible as a closed `spec-approval` issue or explicit written confirmation
- [ ] `docs/delivery/project-state.md` records state `DEFINED` with the approval reference

**Who records it:** Spec completes definition and shapes the backlog. Orchestrator verifies conditions and records the state transition. Human approval is the gate to exit DEFINED.

**What is not yet true:** Builder has not received any implementation dispatch. Orchestrator has not routed any normal build work.

---

## State 3: ACTIVE

**Meaning:** The project is operationally ready for implementation. Orchestrator may now dispatch Builder to ready issues.

**Conditions (all required):**
- [ ] All DEFINED conditions are met
- [ ] Human approval is confirmed (spec-approval issue closed by the human operator)
- [ ] `docs/delivery/project-state.md` records state `ACTIVE` with timestamp and Orchestrator identity

**Who records it:** Orchestrator records the ACTIVE transition immediately after human approval is confirmed.

**What becomes true:** Orchestrator may dispatch Builder to ready issues. Normal delivery flow begins.

---

## Hard rules

### Builder must not start before ACTIVE
Builder must check `docs/delivery/project-state.md` before beginning any normal implementation task. If the project state is not `ACTIVE`, Builder must halt and report the state to Orchestrator. This applies even if Orchestrator dispatched the task — Orchestrator should not dispatch if state is not ACTIVE, but Builder is the last-line check.

Spike work is the only exception: explicitly-scoped spikes may be dispatched during DEFINED state when the human has explicitly approved a specific spike as part of spec exploration. Spikes must use spike branches and must not produce merge-ready delivery.

### Orchestrator must not dispatch normal build work before ACTIVE
Orchestrator must verify `docs/delivery/project-state.md` reads `ACTIVE` before dispatching any Builder task for normal implementation. If the state is BOOTSTRAPPED or DEFINED, Orchestrator must route back to Spec to complete the missing conditions rather than trying to shortcut activation.

### The spec-approval gate is the human's call, not the agent's
Orchestrator cannot self-approve. Spec cannot self-approve. The DEFINED → ACTIVE transition requires a human to close the `spec-approval` issue. An agent confirming that specs look good does not substitute for this.

### Validation
Run at any point to check current activation state:

```bash
scripts/validate-project-activation.sh <project-slug> <repo-path>
```

This checks:
- `docs/delivery/project-state.md` exists
- state field is one of: `BOOTSTRAPPED`, `DEFINED`, `ACTIVE`
- for ACTIVE: spec-approval issue is closed, at least one ready issue exists

---

## project-state.md format

`docs/delivery/project-state.md` in the project repo must contain a JSON block with this shape:

```json
{
  "project": "<slug>",
  "state": "BOOTSTRAPPED",
  "bootstrapped_at": null,
  "defined_at": null,
  "activated_at": null,
  "spec_approval_ref": null,
  "activated_by": null,
  "notes": []
}
```

Orchestrator updates the relevant fields at each transition. The `notes` array may contain free-text strings explaining anything non-standard about the transition.

---

## Summary: who owns what

| Responsibility | Owner |
|----------------|-------|
| Bootstrap infra, smoke test, record BOOTSTRAPPED | Orchestrator |
| Initial SPEC.md, wiki, issue shaping, backlog | Spec |
| Verify DEFINED conditions, record DEFINED | Orchestrator |
| Human review and approval (spec-approval issue) | Human |
| Record ACTIVE, begin dispatch | Orchestrator |
| Check ACTIVE before starting work | Builder (and QA for any review work) |
