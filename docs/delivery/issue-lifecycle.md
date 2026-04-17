# Issue Lifecycle Model

This document is the canonical reference for how work enters, progresses, and exits the delivery system. It governs routing decisions for Orchestrator, Spec, Builder, QA, and Security.

---

## Issue types

| Type | Meaning | Spec elaboration required? | Security mandatory? |
|------|---------|---------------------------|-------------------|
| `feature` | New capability that does not exist yet | Always | When feature touches security-sensitive scope |
| `change` | Scoped modification to existing defined behavior | Usually (see below) | When change touches security-sensitive scope |
| `bug` | Defect — behavior diverges from documented or agreed intent | Always | When bug is in security-sensitive scope |
| `chore` | Technical work with no user-visible behavior change | Rarely (see below) | Rarely |
| `spike` | Bounded investigation; output is a report, not a PR | Different path — see below | When spike investigates security-sensitive area |

### `change` vs `feature`

`feature` requires product design: Spec must define what the capability does, what it does not do, and what acceptance looks like before any build work starts.

`change` is a modification where the "what" is already decided and documented — only the "how" needs implementation. Examples: updating a timeout value, renaming a visible label, changing an API response field that is already in the spec. If the "what" is not already decided, it is a `feature`, not a `change`.

Practical test: can Spec write the acceptance criteria without first deciding the product direction? If yes, it is a `change`. If no, it is a `feature`.

### `chore`

Chores have no user-visible behavior change: dependency updates, code cleanup, CI refactors, test infrastructure. They do not require a spec artifact link, but they still require non-empty acceptance criteria and a test strategy (even if that strategy is "CI passes and no regressions in existing tests").

### `spike`

Spikes are not delivery work. They are bounded investigations with a stated question and explicit success/failure criteria. See the spike lifecycle below — it diverges from the normal path after Spec shapes it.

---

## State model

### Primary workflow states

Exactly one primary state label must be set at a time. These are mutually exclusive.

| Label | Meaning |
|-------|---------|
| `spec-needed` | Awaiting Spec elaboration |
| `ready-for-build` | Spec complete; awaiting Builder dispatch |
| `in-build` | Builder actively working |
| `in-review` | PR raised; awaiting QA and review |
| `done` | Merged and closed |

```
[created]
    │
    ▼
spec-needed ──────────────────────────────────────┐
    │                                              │
    │  Spec shapes, defines ACs, test strategy    │
    ▼                                              │
ready-for-build                                    │
    │                                              │
    │  Orchestrator validates + dispatches Builder │
    ▼                                              │
in-build                                           │
    │                                              │
    │  Builder implements, raises PR               │
    ▼                                              │
in-review ──────── changes-requested ─────────────┘
    │
    │  QA approves, Spec satisfied, Orchestrator approves
    ▼
done (issue closed)
```

### Modifier labels

Modifiers may be applied alongside any non-`done` primary state. They suspend or annotate without replacing the primary state.

| Label | Meaning |
|-------|---------|
| `architecture-needed` | Design exploration required before ACs can be written; typically paired with `spec-needed` |
| `needs-clarification` | Waiting for an answer before work can resume; suspends forward progress |
| `blocked` | Blocked on an external dependency; suspends forward progress |

### Valid and invalid combinations

Valid:
- `spec-needed` alone
- `spec-needed` + `architecture-needed`
- `ready-for-build` + `blocked`
- `in-build` + `needs-clarification`

Invalid (rejected by `validate-issue-ready.py`):
- Two primary states together (`ready-for-build` + `in-build`, `in-build` + `in-review`, etc.)
- Zero primary states
- `done` + any modifier (terminal state; modifiers have no meaning once closed)

---

## Lifecycle by type

### feature

1. **Intake** — issue created (human, agent, or release-driven) with `feature` + `spec-needed`
2. **Spec elaboration** — Spec defines: scope, out-of-scope, acceptance criteria, test strategy, assumptions, spec artifact link; adds `security-scope` if applicable
3. **Security design** — if `security-scope`: Security reviews before build handoff; adds security requirements and threat model to issue
4. **Ready gate** — Orchestrator runs `validate-issue-ready.py`; if fails, routes back to Spec
5. **Build** — Orchestrator dispatches Builder; issue gains `in-build`
6. **Review** — Builder raises PR; issue gains `in-review`
7. **QA** — QA reviews PR
8. **Merge** — three-label gate (`qa-approved`, `spec-satisfied`, `orchestrator-approved`) plus `security-approved` if security-scope
9. **Close** — issue gains `done` and is closed

Back-routes:
- Build → Spec: Builder finds project-level ambiguity
- QA → Build: rework needed
- QA → Spec: scope ambiguity found during review

### change

Same as `feature` except:
- Spec elaboration is lighter — the "what" is already defined; Spec confirms it and writes ACs
- If acceptance criteria and spec artifact link already exist and Spec confirms the definition is complete, issue may move to `ready-for-build` faster
- Scope must be narrow; if scope expands during spec elaboration, reclassify as `feature`

### bug

1. **Intake** — issue created with `bug` + `spec-needed`; must include reported behavior, expected behavior, and reproduction steps
2. **Spec triage** — Spec confirms: is this a real bug against the current spec? Is it in scope for a fix now?
   - If the behavior is intentional: close as `wontfix` or reclassify
   - If it is out of current release scope: defer with a note
   - If it is an accepted in-scope bug: Spec adds acceptance criteria, test strategy, regression coverage expectation; adds `security-scope` if applicable
3. **Security review** — if `security-scope`: Security reviews before build handoff
4. **Ready gate** — Orchestrator runs `validate-issue-ready.py`; requires reported/expected/reproduction sections filled
5. **Build** — Builder fixes the bug; **must** add automated regression coverage or produce a documented impossibility exception accepted by Spec
6. **QA** — QA must confirm regression coverage exists or exception is accepted; missing coverage without an accepted exception is a blocker
7. **Merge** — same gate as feature

Release-driven bugs:
- Come from release testing (Release Manager surfaces them via Orchestrator)
- Triage owned by Spec and Orchestrator together
- Accepted bugs re-enter the normal bug lifecycle from step 2
- Deferred bugs are logged and release proceeds

### chore

1. **Intake** — issue created with `chore` + `spec-needed` (or `ready-for-build` if clearly self-contained)
2. **Spec review** — Spec confirms scope is truly chore-class (no user-visible change); writes acceptance criteria; no spec artifact required but must cite what the chore achieves
3. **Ready gate** — `validate-issue-ready.py` with chore-mode rules (no spec artifact required; test strategy required)
4. **Build** — same as feature
5. **QA** — same as feature; focus is on regression risk
6. **Merge** — same three-label gate

### spike

1. **Intake** — issue created with `spike` + `spec-needed`; must state the question being investigated
2. **Spec shapes spike** — Spec defines: bounded question, success criteria, failure criteria, expected output shape, what decision follows from each outcome; adds `architecture-needed` if design exploration is involved
3. **Spike dispatch** — Orchestrator dispatches Builder on a spike branch (not a feature branch); no `ready-for-build` label used for spikes
4. **Spike output** — Builder produces a report (not a mergeable PR); spike branch is not merged unless explicitly converted to a feature/change issue
5. **Spec + Orchestrator evaluate** — decide next step: create follow-up feature/change issue, defer, or close
6. **Close spike issue** — spike issue is closed; any follow-on work becomes a new issue

Spikes do not go through QA or the normal merge gate. They produce information, not shipped code.

---

## Mandatory Security involvement

Security must be engaged **before build handoff** when an issue:
- touches authentication, authorisation, or session management
- handles sensitive data (PII, credentials, tokens, secrets)
- exposes or modifies external interfaces or APIs
- changes deployment, infrastructure, or access-control configuration
- is explicitly labeled `security-scope`

Security involvement during spec is not optional for these cases. An issue carrying `security-scope` that does not have completed security requirements and a threat model cannot pass `validate-issue-ready.py`.

---

## Who can do what

| Action | Owner | Others |
|--------|-------|--------|
| Create issue | Anyone | — |
| Apply issue type label | Spec or Orchestrator | Human |
| Write acceptance criteria | Spec | — |
| Write test strategy | Spec | Builder may propose |
| Apply `ready-for-build` | Spec (with Orchestrator confirmation via validate-issue-ready.py) | — |
| Dispatch Builder | Orchestrator | — |
| Apply `in-build` | Orchestrator at dispatch | — |
| Apply `in-review` | Orchestrator when PR is raised | — |
| Apply `needs-clarification` | Any agent | — |
| Apply `security-scope` | Spec or Security | — |
| Apply `done` and close | Orchestrator after merge | — |
| Reclassify issue type | Spec | Orchestrator |

---

## Definition of ready

An issue is ready for build when all of the following are true. `validate-issue-ready.py` enforces these programmatically.

**All types:**
- Issue is open
- Has exactly one issue-type label
- Has `ready-for-build` label (except spikes, which use a different dispatch path)
- Has non-empty `## Acceptance Criteria`
- Has non-empty `## Test Strategy`
- Has no open blocking issues referenced
- Has no unresolved `needs-clarification` or `blocked` labels

**feature and change additionally:**
- References a spec artifact (SPEC.md, wiki page, or architecture decision)
- Has non-empty `## Assumptions` or non-empty `## Links`

**bug additionally:**
- Has non-empty `## Reported Behavior`
- Has non-empty `## Expected Behavior`
- Has non-empty `## Reproduction` (at least two steps)
- Spec has triaged and confirmed this is an accepted in-scope bug

**chore:**
- Spec artifact reference is not required
- Test strategy may be "CI passes; no regressions in existing tests"

**security-scope (any type):**
- Has non-empty `## Security Requirements`
- Has non-empty `## Threat Model`

---

## What `change` is not

`change` is not a catch-all for "things that don't fit". If unsure, default to `feature`. Reclassification from `change` to `feature` at any point is always correct and preferred over letting a poorly-scoped `change` drift through build unchallenged.

`change` does not skip spec. It shortens spec. The spec elaboration for a change is confirmation and AC-writing, not product design.
