# Action Taxonomy and Auditability Model

## Purpose

This document defines a canonical action taxonomy for the agent framework so swarm behavior can be:
- audited by discrete action type
- graphed over time
- compared across projects and agents
- analyzed for inefficiencies, loops, retries, and dead-end flows
- evolved away from prompt-only behavior toward structured, typed operations

The framework already has some concrete helper scripts and validators, but many behaviors still exist primarily as prompt instructions and role-doc obligations.
This document separates:
- what the swarm conceptually does
- what concrete side effects happen
- how strongly each action is currently implemented as a discrete, auditable operation
- what changes are needed to make each action first-class and observable

## Why this matters

Prompt instructions are poor telemetry.

If a prompt says:
- "review the PR"
- "route this to Spec"
- "investigate the bug"

that is useful for behavior shaping, but weak for audit/UI purposes.

For an operations UI, we want strongly typed events such as:
- `orchestrator.route`
- `triage.report.publish`
- `spec.issue.shape`
- `builder.pr.open`
- `security.review.prebuild`
- `qa.review.pr`
- `release.beta.cut`
- `callback.send`

Those typed actions let the UI show:
- timelines
- action counts
- rate of retries or loops
- average latency by action type
- bottlenecks by project or agent
- unproductive routing churn
- mismatch between high-level intent and actual side effects

## Design principles

1. **Separate domain actions from transport details**
   `spec.issue.shape` is the domain action.
   `github.issue.comment` is the concrete side effect.

2. **Prefer a small number of meaningful verbs**
   Too many tiny actions create noise. Too few actions hide real behavior.

3. **Every action should have a typed outcome**
   Success/failure alone is not enough. We also want outcomes like `blocked`, `needs-human`, `duplicate`, `retry`, or `handoff`.

4. **Agent reasoning may stay flexible, but side effects should be typed**
   Agents can reason in free text. But once they act on the project state, that action should ideally be auditable.

5. **Auditability is incremental**
   Not everything needs to become a dedicated tool overnight. Wrapper scripts and structured event emission are enough to get started.

## Implementation strength levels

Each action below is scored using this scale:

### Level 0 — Prompt-only
The behavior is described in prose only. No dedicated script, validator, or structured wrapper exists.

### Level 1 — Convention-backed
The behavior is strongly encouraged by role docs or workflows, but there is no dedicated action wrapper or typed event surface.

### Level 2 — Helper-backed
There is a concrete helper script or validator that performs part of the action, but it does not yet emit a canonical structured audit event or enforce typed inputs/outputs fully.

### Level 3 — Discrete runtime action
A dedicated helper or tool exists with a stable contract, typed inputs, clear side effects, and strong audit potential. Structured logging may still be missing.

### Level 4 — Fully auditable action
The action has:
- a canonical action type
- typed input/output schema
- stable helper/tool boundary
- structured event emission
- durable identifiers for correlation
- clear success/failure/handoff semantics

The current framework has many Level 1–3 actions and very few true Level 4 actions.

## Canonical event envelope

Before defining specific actions, define the event shape that every auditable action should eventually emit.

```json
{
  "eventId": "evt_...",
  "timestamp": "2026-04-22T10:00:00Z",
  "project": "decky-secrets",
  "agentRole": "orchestrator",
  "agentId": "orchestrator-decky-secrets",
  "sessionKey": "agent:orchestrator-decky-secrets:main",
  "actionType": "orchestrator.route",
  "status": "succeeded",
  "outcome": "dispatched",
  "target": {
    "kind": "named-agent",
    "id": "triage-decky-secrets"
  },
  "artifacts": {
    "issueNumber": 42,
    "prNumber": null,
    "branch": null,
    "urls": []
  },
  "metadata": {
    "fromState": "intake",
    "toState": "triage",
    "reasonCode": "unclear-repro"
  },
  "durationMs": 381,
  "correlationId": "task_...",
  "parentEventId": null
}
```

### Minimum recommended fields
Every action should eventually emit:
- `eventId`
- `timestamp`
- `project`
- `agentRole`
- `agentId`
- `actionType`
- `status`
- `outcome`
- `target`
- `metadata`
- `durationMs`
- `correlationId`

## Action families

The taxonomy is grouped into:
1. Orchestrator actions
2. Triage actions
3. Spec actions
4. Builder actions
5. QA actions
6. Security actions
7. Release Manager actions
8. Shared GitHub/documentation actions
9. System/runtime actions

---

# 1. Orchestrator actions

## 1.1 `orchestrator.intake`
**Purpose:** Record that a new user/system request has been accepted into the delivery flow.

**Typical triggers:**
- direct human request
- callback from another agent
- watchdog surfacing overdue work
- new issue/backlog item requiring coordination

**Associated metadata:**
- source kind (`human`, `callback`, `watchdog`, `github-artifact`)
- source artifact ref
- request summary
- project state at intake
- initial classification confidence

**Current implementation strength:** Level 1

**Current state:**
- strongly implied by Orchestrator role docs
- not represented by a dedicated helper or structured log

**Needed for full auditability:**
- explicit intake wrapper or event emitter at the beginning of each new work packet
- stable intake reason codes
- correlation id assigned at intake time

## 1.2 `orchestrator.classify`
**Purpose:** Decide whether incoming work belongs in Spec, Triage, Builder, QA, Security, Release Manager, or human escalation.

**Typical triggers:**
- after intake
- after callback
- after project-state or issue-readiness check

**Associated metadata:**
- candidate route set
- chosen route
- reason code (`needs-spec`, `unclear-repro`, `ready-for-build`, `needs-release`, etc.)
- readiness inputs considered
- issue type / workflow labels

**Current implementation strength:** Level 1

**Current state:**
- heavily prompt-driven
- partly grounded by readiness validators and routing rules

**Needed for full auditability:**
- explicit route classification record
- standardized reason codes
- structured capture of evidence used in the decision

## 1.3 `orchestrator.route`
**Purpose:** Route a work item to the next responsible named agent or to the human.

**Typical triggers:**
- classification completed
- callback received from another agent
- issue transitions state

**Associated metadata:**
- routed-to role / agent id
- routed-from role / state
- work item reference
- route reason code
- expected callback deadline

**Current implementation strength:** Level 2

**Current state:**
- behavior strongly defined in `agents/orchestrator.md`
- concrete dispatch helper exists: `scripts/dispatch-named-agent.sh`
- still lacks a framework-wide structured route event model

**Needed for full auditability:**
- canonical route event emitted by dispatch wrapper
- route outcome types: `dispatched`, `blocked`, `unreachable`, `escalated`
- target and deadline fields captured uniformly

## 1.4 `orchestrator.block`
**Purpose:** Mark work as blocked and surface why.

**Typical triggers:**
- named agent unreachable
- validation failure
- missing readiness
- unresolved ambiguity
- repeated stall

**Associated metadata:**
- blocker category
- blocker summary
- blocking artifact ref
- affected work item
- whether human escalation is required

**Current implementation strength:** Level 1

**Needed for full auditability:**
- typed blocker categories
- structured update event when ledger state changes to blocked
- durable blocker id or reason code

## 1.5 `orchestrator.accept-callback`
**Purpose:** Receive and process a worker callback.

**Typical triggers:**
- `scripts/send-agent-callback.sh`
- named agent completion/failure/blockage

**Associated metadata:**
- sender role / agent id
- callback status
- linked task id / issue / PR
- next-step recommendation
- callback validation result

**Current implementation strength:** Level 2

**Current state:**
- callback schema and validator exist
- callback delivery script exists
- Orchestrator-side consumption remains largely prompt-governed

**Needed for full auditability:**
- callback ingest event with normalized statuses
- correlation between callback and original dispatch event
- explicit callback acceptance vs rejection states

## 1.6 `orchestrator.escalate-human`
**Purpose:** Escalate to the human operator when policy, risk, or ambiguity requires it.

**Typical triggers:**
- approval boundary crossed
- high-risk architectural disagreement
- unresolved block after retries
- spec ambiguity requiring business decision

**Associated metadata:**
- escalation reason code
- blocked action type
- artifacts requiring review
- urgency/severity

**Current implementation strength:** Level 1

**Needed for full auditability:**
- standard escalation reasons
- operator-facing queue or event stream entry
- outcome model: `waiting-human`, `resolved-human`, `ignored`, `cancelled`

---

# 2. Triage actions

## 2.1 `triage.start`
**Purpose:** Open an investigation into an unclear failure.

**Typical triggers:**
- Orchestrator routes vague bug / flaky issue / unclear failure to Triage
- QA requests diagnostic follow-up
- Security surfaces uncertain attribution

**Associated metadata:**
- source report type
- source issue / PR / log ref
- suspected area
- investigation goal

**Current implementation strength:** Level 1

**Current state:**
- role now exists in `agents/triage.md`
- no dedicated triage-start wrapper yet

**Needed for full auditability:**
- explicit triage case id
- status transitions for an investigation
- open/close event stream for each triage packet

## 2.2 `triage.reproduce`
**Purpose:** Attempt to reproduce a problem and record repro reliability.

**Typical triggers:**
- after triage start
- after new evidence arrives

**Associated metadata:**
- repro steps attempted
- environment
- result (`reliable`, `intermittent`, `not-reproduced`)
- commands run
- duration

**Current implementation strength:** Level 0

**Current state:**
- described in role docs only

**Needed for full auditability:**
- reproduction log schema
- event capture for attempt/result
- optional command trace or artifact attachment model

## 2.3 `triage.collect-evidence`
**Purpose:** Gather logs, screenshots, stack traces, issue comments, and related refs.

**Typical triggers:**
- after triage start
- when reproduction is partial or unclear

**Associated metadata:**
- evidence type
- source artifact
- commit/branch
- environment snapshot
- timestamps

**Current implementation strength:** Level 0

**Needed for full auditability:**
- normalized evidence record model
- artifact attachment refs
- evidence source taxonomy

## 2.4 `triage.classify`
**Purpose:** Classify the issue as `bug`, `environment-tooling`, `spec-gap`, `security-concern`, `spike-needed`, `needs-human-decision`, `not-a-bug`, or `duplicate`.

**Typical triggers:**
- enough evidence gathered
- repro outcome known

**Associated metadata:**
- classification type
- confidence
- builder-ready flag
- why this classification was chosen

**Current implementation strength:** Level 1

**Current state:**
- canonical classifications exist in the role doc
- no dedicated classification event path

**Needed for full auditability:**
- typed classification output schema
- immutable classification event with confidence and supporting refs

## 2.5 `triage.report.publish`
**Purpose:** Publish a structured triage report as a durable artifact.

**Typical triggers:**
- investigation complete enough for handoff
- human/system requests a formal output

**Associated metadata:**
- publication target (`issue-comment`, `pr-comment`, `file`, `wiki`, etc.)
- report classification
- source refs
- builder-readiness

**Current implementation strength:** Level 1

**Current state:**
- report template exists in prose
- report publication uses generic comment tooling, not a dedicated triage report action

**Needed for full auditability:**
- specific triage-report wrapper or template validator
- artifact kind recorded explicitly
- report id/correlation id

## 2.6 `triage.recommend-route`
**Purpose:** Recommend the next owner after investigation.

**Typical triggers:**
- triage report completion

**Associated metadata:**
- recommended target role
- reason code
- builder-ready yes/no
- required preconditions before handoff

**Current implementation strength:** Level 1

**Needed for full auditability:**
- explicit route recommendation schema
- structured callback mapping from triage to orchestrator/spec

---

# 3. Spec actions

## 3.1 `spec.issue.shape`
**Purpose:** Turn an ambiguous request or triage report into a canonical buildable issue.

**Typical triggers:**
- human request lacking structure
- Triage report completed
- QA clarification loop
- Security required requirements changes

**Associated metadata:**
- source artifact refs
- resulting issue number
- issue type
- acceptance criteria count
- assumptions added

**Current implementation strength:** Level 1

**Current state:**
- core Spec responsibility
- helper scripts exist for issue creation/commenting, but issue shaping itself remains mostly prompt-defined

**Needed for full auditability:**
- typed spec-shaping event with before/after refs
- explicit readiness outcome
- separate event for creating vs refining an issue

## 3.2 `spec.issue.create`
**Purpose:** Create a new GitHub issue.

**Typical triggers:**
- new backlog item
- triage report becomes canonical work
- release follow-up item

**Associated metadata:**
- repo
- issue title
- issue type
- labels
- linked source refs

**Current implementation strength:** Level 3

**Current state:**
- concrete helper exists: `scripts/create-agent-issue.sh`
- reasonably discrete side effect
- still missing canonical structured audit emission

**Needed for full auditability:**
- wrapper emits structured event payload including issue number and labels
- standard reason code for why the issue was created

## 3.3 `spec.issue.comment`
**Purpose:** Add clarification or shaping comments to an issue.

**Typical triggers:**
- refine acceptance criteria
- respond to builder/QA/security questions
- note assumptions or updates

**Associated metadata:**
- issue number
- comment purpose (`clarification`, `assumption`, `handoff`, `status`)
- linked files/docs

**Current implementation strength:** Level 3

**Current state:**
- generic helper exists: `scripts/post-agent-comment.sh`
- audit semantics remain generic rather than spec-specific

**Needed for full auditability:**
- comment-purpose metadata
- event typing above generic GitHub comment transport

## 3.4 `spec.assumption.record`
**Purpose:** Record project-level assumptions durably.

**Typical triggers:**
- ambiguity resolved
- design clarification needed
- builder/QA/security escalation

**Associated metadata:**
- assumption category
- affected issue(s)
- durable storage location (`SPEC.md`, wiki, decision record)

**Current implementation strength:** Level 1

**Needed for full auditability:**
- dedicated assumption log artifact or schema
- typed event per assumption addition/update

## 3.5 `spec.spike.define`
**Purpose:** Define a spike/investigation issue rather than a normal build task.

**Typical triggers:**
- uncertainty is the work item
- Triage reports `spike-needed`
- design feasibility unresolved

**Associated metadata:**
- bounded question
- success/failure criteria
- expected output
- time box

**Current implementation strength:** Level 1

**Needed for full auditability:**
- distinct action type from normal issue shaping
- explicit spike artifact validation and event logging

## 3.6 `spec.doc.update`
**Purpose:** Update `SPEC.md`, wiki, or other project-truth documentation.

**Typical triggers:**
- issue shaping
- architecture clarification
- assumption recording
- clarification loop from QA/Builder

**Associated metadata:**
- target doc path/url
- section updated
- reason code
- linked work items

**Current implementation strength:** Level 2

**Current state:**
- helper exists for wiki updates: `scripts/update-agent-wiki-page.sh`
- spec/doc updates in repo files are less uniformly wrapped

**Needed for full auditability:**
- document-update wrapper taxonomy by doc kind
- structured diff summary in emitted event

---

# 4. Builder actions

## 4.1 `builder.task.start`
**Purpose:** Begin implementation for a scoped issue.

**Typical triggers:**
- Orchestrator dispatches ready-for-build work

**Associated metadata:**
- issue number
- branch name
- starting commit SHA
- linked PR if pre-existing

**Current implementation strength:** Level 1

**Needed for full auditability:**
- explicit task-start event
- branch association captured immediately
- start time and expected callback deadline

## 4.2 `builder.branch.create`
**Purpose:** Create the implementation branch.

**Typical triggers:**
- Builder begins work on a new issue

**Associated metadata:**
- branch name
- base branch
- issue number
- repo SHA baseline

**Current implementation strength:** Level 1

**Needed for full auditability:**
- wrapper or recorded branch creation event
- one-branch-per-task correlation

## 4.3 `builder.code.write`
**Purpose:** Make code or config changes.

**Typical triggers:**
- implementation work
- follow-up after QA/Security review

**Associated metadata:**
- changed files
- change category (`app-code`, `test`, `infra`, `docs`, etc.)
- issue number
- whether the change is scope-expanding

**Current implementation strength:** Level 0

**Current state:**
- pure prompt/runtime behavior
- no discrete framework action wrapper

**Needed for full auditability:**
- this probably should not become a tiny event for every file edit in the framework layer
- better approach: emit summarized `builder.work-unit` or `builder.commit` events rather than per-edit micro-actions

## 4.4 `builder.commit`
**Purpose:** Record a coherent implementation change in git.

**Typical triggers:**
- Builder reaches a meaningful checkpoint
- PR preparation or update

**Associated metadata:**
- commit SHA
- semantic subject
- files changed count
- issue number

**Current implementation strength:** Level 1

**Needed for full auditability:**
- structured commit event emitted by helper or wrapper
- commit-to-task correlation id

## 4.5 `builder.pr.open`
**Purpose:** Open a pull request.

**Typical triggers:**
- initial implementation ready for review

**Associated metadata:**
- repo
- issue number(s)
- branch
- PR number
- base branch
- checks status at creation time

**Current implementation strength:** Level 3

**Current state:**
- helper exists: `scripts/create-agent-pr.sh`

**Needed for full auditability:**
- structured event emission from helper
- normalized mapping from issue to PR

## 4.6 `builder.pr.update`
**Purpose:** Update PR body or notes.

**Typical triggers:**
- implementation details changed
- assumptions or deviations need recording
- review follow-up

**Associated metadata:**
- PR number
- update purpose
- linked issue refs

**Current implementation strength:** Level 3

**Current state:**
- helper exists: `scripts/update-agent-pr-body.sh`

**Needed for full auditability:**
- explicit purpose field and standardized categories

## 4.7 `builder.request-clarification`
**Purpose:** Signal that implementation cannot safely continue without Spec/Orchestrator input.

**Typical triggers:**
- ambiguous requirements
- missing assumptions
- scope conflict

**Associated metadata:**
- issue number
- clarification category
- blocking question
- current branch/PR state

**Current implementation strength:** Level 1

**Needed for full auditability:**
- dedicated clarification request event/callback status
- explicit pause state for implementation

## 4.8 `builder.spawn-specialist`
**Purpose:** Launch a disposable specialist worker.

**Typical triggers:**
- domain-specific subproblem
- parallel exploration justified

**Associated metadata:**
- specialist type
- parent issue/PR
- why specialist is needed
- expected output type

**Current implementation strength:** Level 2

**Current state:**
- helper preparation exists, but taxonomy around spawn reasons and outcomes is still loose

**Needed for full auditability:**
- specialist spawn event with subtype and justification code
- explicit join/result event from specialist

---

# 5. QA actions

## 5.1 `qa.review.pr`
**Purpose:** Review a PR against issue/spec/quality expectations.

**Typical triggers:**
- Builder reports `NEEDS_REVIEW`
- Release cycle verification

**Associated metadata:**
- PR number
- linked issue(s)
- changed files set
- review scope
- review mode (`normal`, `release`, `regression`)

**Current implementation strength:** Level 1

**Current state:**
- role strongly defined
- helper scripts exist for comments
- actual review action remains prompt-defined

**Needed for full auditability:**
- explicit review-start/review-complete events
- normalized review mode and verdict

## 5.2 `qa.comment.summary`
**Purpose:** Post a top-level PR review summary comment.

**Typical triggers:**
- QA completes review
- non-line-specific findings exist

**Associated metadata:**
- PR number
- verdict
- blocking yes/no
- findings count

**Current implementation strength:** Level 3

**Current state:**
- `scripts/post-agent-comment.sh`
- summary comments are concrete but generic

**Needed for full auditability:**
- summary comment purpose and verdict emitted as structured metadata

## 5.3 `qa.comment.line`
**Purpose:** Post a line-specific PR review comment.

**Typical triggers:**
- line-specific defect or concern found

**Associated metadata:**
- PR number
- commit SHA
- file path
- line number
- severity

**Current implementation strength:** Level 3

**Current state:**
- `scripts/post-pr-line-comment.sh`
- now better structured after the header/body fix

**Needed for full auditability:**
- severity/category fields added at the wrapper level
- line comment event emitted structurally, not just through GitHub transport

## 5.4 `qa.verdict`
**Purpose:** Produce the official QA outcome.

**Typical triggers:**
- review complete

**Associated metadata:**
- verdict (`approved`, `needs-review`, `blocked`, `failed`)
- blockers count
- regression concern yes/no

**Current implementation strength:** Level 1

**Needed for full auditability:**
- canonical verdict event
- callback status normalization
- explicit distinction between GitHub comment and QA verdict state

## 5.5 `qa.report-bug`
**Purpose:** File or report a defect found during review/testing.

**Typical triggers:**
- QA determines a new issue should be created rather than just PR feedback

**Associated metadata:**
- source PR/release
- severity
- reproducibility
- whether it blocks merge/release

**Current implementation strength:** Level 2

**Current state:**
- `scripts/post-bug-report.sh` exists
- issue creation/report boundary still somewhat fuzzy

**Needed for full auditability:**
- split bug-report publication from canonical issue creation
- event model for defect discovery vs defect backlog creation

---

# 6. Security actions

## 6.1 `security.review.prebuild`
**Purpose:** Review security-scope issues before build begins.

**Typical triggers:**
- issue labeled `security-scope` or `security-review-required`
- Spec needs Security sign-off before build

**Associated metadata:**
- issue number
- security-scope labels
- threat model present yes/no
- requirements present yes/no
- outcome

**Current implementation strength:** Level 1

**Current state:**
- role defined strongly in docs
- no distinct helper representing the review itself

**Needed for full auditability:**
- dedicated review event and outcome schema
- explicit record of whether `security-reviewed-for-build` was applied

## 6.2 `security.review.pr`
**Purpose:** Review a security-scope PR before QA.

**Typical triggers:**
- PR linked to security-scope work
- Orchestrator routes to Security

**Associated metadata:**
- PR number
- issue refs
- review outcome
- material findings count
- labels applied/withheld

**Current implementation strength:** Level 1

**Needed for full auditability:**
- explicit security PR review event
- distinction between line findings, summary findings, and approval/block outcome

## 6.3 `security.comment.summary`
**Purpose:** Post summary review comments from Security.

**Typical triggers:**
- security review complete
- overall blocker/approval reasoning needs visibility

**Associated metadata:**
- PR/issue target
- review mode
- outcome
- findings count

**Current implementation strength:** Level 3

**Current state:**
- generic comment helper exists

**Needed for full auditability:**
- action typing above generic GitHub comment transport

## 6.4 `security.comment.line`
**Purpose:** Post line-specific security review findings.

**Typical triggers:**
- code-specific risk found during PR review

**Associated metadata:**
- file path
- line number
- severity
- category (`auth`, `secret-handling`, `input-validation`, etc.)

**Current implementation strength:** Level 3

**Current state:**
- line comment helper exists
- metadata not standardized

**Needed for full auditability:**
- severity/category fields standardized
- event emission with exact review classification

## 6.5 `security.approval`
**Purpose:** Apply or withhold security approval.

**Typical triggers:**
- prebuild review complete
- PR review complete
- release testing complete

**Associated metadata:**
- approval type (`security-reviewed-for-build`, `security-approved`)
- target artifact
- applied yes/no
- rationale summary

**Current implementation strength:** Level 1

**Needed for full auditability:**
- explicit approval state transition event
- separate transport action for label application if used

## 6.6 `security.release-test`
**Purpose:** Perform release-wide security testing.

**Typical triggers:**
- Release Manager requests beta/RC/final testing

**Associated metadata:**
- release version/tag
- test mode
- findings count
- blocker status

**Current implementation strength:** Level 1

**Needed for full auditability:**
- release test event and outcome schema
- linked release tracking artifact refs

---

# 7. Release Manager actions

## 7.1 `release.tracking.open`
**Purpose:** Open or initialize a release tracking issue/state.

**Typical triggers:**
- release process starts

**Associated metadata:**
- version target
- release type
- tracking issue number
- source trigger

**Current implementation strength:** Level 2

**Needed for full auditability:**
- explicit release-state transition event
- correlation between issue and release cycle id

## 7.2 `release.state.update`
**Purpose:** Update release-state artifact.

**Typical triggers:**
- beta cut
- RC cut
- blocker discovered/resolved
- publication completed

**Associated metadata:**
- old phase
- new phase
- blockers summary
- artifact refs

**Current implementation strength:** Level 3

**Current state:**
- helper exists: `scripts/update-release-state.py`

**Needed for full auditability:**
- structured event emitted from helper with phase transition details

## 7.3 `release.beta.cut`
**Purpose:** Cut a beta release tag.

**Typical triggers:**
- Release Manager determines beta candidate is ready

**Associated metadata:**
- tag name
- commit SHA
- release issue ref
- previous release phase

**Current implementation strength:** Level 3

**Current state:**
- tag-cut helper exists

**Needed for full auditability:**
- explicit release phase action typing and emitted tag metadata

## 7.4 `release.rc.cut`
**Purpose:** Cut an RC tag.

**Typical triggers:**
- beta blockers resolved
- release candidate ready

**Associated metadata:**
- tag name
- commit SHA
- release issue ref

**Current implementation strength:** Level 3

**Needed for full auditability:**
- same as beta cut, but with explicit phase label

## 7.5 `release.publish`
**Purpose:** Publish the final GitHub release.

**Typical triggers:**
- QA and Security final sign-off
- release criteria satisfied

**Associated metadata:**
- version/tag
- release notes source
- publication URL
- final blocker state

**Current implementation strength:** Level 2

**Needed for full auditability:**
- publication result event with URL and release id
- explicit distinction between tag creation and release publication

## 7.6 `release.notes.generate`
**Purpose:** Generate release notes.

**Typical triggers:**
- preparing beta/RC/final release publication

**Associated metadata:**
- release version
- issues/PRs included
- generation source refs

**Current implementation strength:** Level 3

**Current state:**
- helper exists: `scripts/generate-release-notes.sh`

**Needed for full auditability:**
- event showing note generation source range and output target

---

# 8. Shared GitHub and documentation actions

These actions are often used by multiple roles.

## 8.1 `github.issue.create`
**Current implementation strength:** Level 3

**Backed by:** `scripts/create-agent-issue.sh`

**Needed for Level 4:** event emission from wrapper, purpose metadata, correlation id

## 8.2 `github.issue.comment`
**Current implementation strength:** Level 3

**Backed by:** `scripts/post-agent-comment.sh`

**Needed for Level 4:** typed `commentPurpose`, actor role, source action type

## 8.3 `github.pr.open`
**Current implementation strength:** Level 3

**Backed by:** `scripts/create-agent-pr.sh`

**Needed for Level 4:** explicit PR purpose, linked issue refs, emitted event

## 8.4 `github.pr.body.update`
**Current implementation strength:** Level 3

**Backed by:** `scripts/update-agent-pr-body.sh`

**Needed for Level 4:** update-purpose metadata and emitted event

## 8.5 `github.pr.comment`
**Current implementation strength:** Level 3

**Backed by:** `scripts/post-agent-comment.sh`

**Needed for Level 4:** typed purpose, role-specific verdict linkage

## 8.6 `github.pr.line-comment`
**Current implementation strength:** Level 3

**Backed by:** `scripts/post-pr-line-comment.sh`

**Needed for Level 4:** severity/category metadata, source review correlation, event emission

## 8.7 `github.wiki.update`
**Current implementation strength:** Level 3

**Backed by:** `scripts/update-agent-wiki-page.sh`

**Needed for Level 4:** doc purpose classification, structured diff/section metadata, event emission

## 8.8 `github.label.apply`
**Purpose:** Apply workflow or approval labels.

**Current implementation strength:** Level 1

**Current state:**
- labels matter greatly, but label application is not elevated as a first-class auditable action in the framework model

**Needed for Level 4:**
- explicit label apply/remove wrapper
- role/authority checks captured in action logs
- reason code for label mutation

## 8.9 `docs.decision-record.write`
**Purpose:** Create or update a decision record.

**Current implementation strength:** Level 2

**Current state:**
- schema and validator exist
- writing/updating is not a strongly typed framework action

**Needed for Level 4:**
- explicit decision-record create/update action wrapper
- reason category and linked issue/pr metadata

---

# 9. System/runtime actions

## 9.1 `agent.dispatch.named`
**Purpose:** Deliver a task to a project-scoped named agent.

**Current implementation strength:** Level 3

**Backed by:** `scripts/dispatch-named-agent.sh`

**Needed for Level 4:**
- event emission for delivery outcome
- dispatch id/correlation id
- timeout/deadline metadata

## 9.2 `agent.dispatch.ephemeral`
**Purpose:** Spawn a disposable specialist worker.

**Current implementation strength:** Level 2

**Needed for Level 4:**
- canonical subtype metadata
- result join event
- parent-child task correlation

## 9.3 `callback.send`
**Purpose:** Send a structured callback from one agent to another.

**Current implementation strength:** Level 3

**Backed by:** `scripts/send-agent-callback.sh`, `scripts/validate-callback.py`

**Needed for Level 4:**
- canonical callback event ids
- normalized callback status taxonomy
- callback accept/reject tracking on receiver side

## 9.4 `validate.issue-ready`
**Purpose:** Check whether an issue is ready for build.

**Current implementation strength:** Level 3

**Backed by:** `scripts/validate-issue-ready.py`

**Needed for Level 4:**
- machine-readable result payload emitted to audit stream
- failure category codes

## 9.5 `validate.callback`
**Purpose:** Validate callback structure before sending.

**Current implementation strength:** Level 3

**Backed by:** `scripts/validate-callback.py`

**Needed for Level 4:**
- standardized validation error categories emitted as events

## 9.6 `validate.release-request`
**Purpose:** Validate release request preconditions.

**Current implementation strength:** Level 3

**Backed by:** `scripts/validate-release-request.py`

**Needed for Level 4:**
- structured result and failure reason codes

## 9.7 `watchdog.check-overdue`
**Purpose:** Detect overdue work or missing callbacks.

**Current implementation strength:** Level 2

**Current state:**
- concrete scripts and docs exist
- auditability of the check result is not yet normalized

**Needed for Level 4:**
- check result event including overdue count, task ids, and follow-up action taken

## 9.8 `framework.deploy`
**Purpose:** Deploy the active framework into runtime/workspaces.

**Current implementation strength:** Level 2

**Current state:**
- very concrete script path exists
- failure/recovery semantics still partly operational rather than modeled

**Needed for Level 4:**
- structured deploy event stream
- project redeploy vs global redeploy distinction
- explicit subevents for runtime generation, workspace deploy, agent creation, priming, recovery path

## 9.9 `framework.prime-agent-session`
**Purpose:** Establish a named agent main session.

**Current implementation strength:** Level 2

**Current state:**
- concrete priming script exists
- but priming still has known hang behavior and lacks robust auditable subevents

**Needed for Level 4:**
- single-agent prime wrapper
- start/finish/fail timeout events
- session key created as explicit output metadata

---

# Cross-cutting metadata recommendations

Some metadata should be standardized across nearly all actions.

## Common metadata fields
- `project`
- `issueNumber`
- `prNumber`
- `branch`
- `commitSha`
- `releaseVersion`
- `sourceUrl`
- `reasonCode`
- `severity`
- `confidence`
- `builderReady`
- `reviewMode`
- `classification`
- `targetRole`
- `targetAgentId`
- `expectedCallbackAt`
- `retryCount`
- `resultCount`

## Reason code examples
- `needs-spec`
- `ready-for-build`
- `unclear-repro`
- `security-scope`
- `qa-found-defect`
- `release-signal`
- `named-agent-unreachable`
- `validation-failed`
- `human-approval-required`
- `stalled-no-callback`

## Outcome examples
- `created`
- `updated`
- `commented`
- `dispatched`
- `approved`
- `blocked`
- `failed`
- `needs-review`
- `needs-human`
- `duplicate`
- `closed`
- `published`
- `timed-out`

---

# Current framework maturity summary

## Already relatively discrete and auditable
These are the strongest current candidates for UI graphing with minimal extra work:
- `github.issue.create`
- `github.issue.comment`
- `github.pr.open`
- `github.pr.body.update`
- `github.pr.comment`
- `github.pr.line-comment`
- `github.wiki.update`
- `agent.dispatch.named`
- `callback.send`
- validation actions
- release-state update / tag cut actions

## Still too prompt-shaped
These remain weakly discrete today:
- `orchestrator.intake`
- `orchestrator.classify`
- `orchestrator.block`
- `triage.reproduce`
- `triage.collect-evidence`
- `triage.report.publish`
- `spec.issue.shape`
- `spec.assumption.record`
- `builder.task.start`
- `builder.request-clarification`
- `qa.review.pr`
- `qa.verdict`
- `security.review.prebuild`
- `security.review.pr`
- `security.approval`
- `release.publish`

These are the places where loops and inefficiencies are likely happening invisibly.

---

# Recommended implementation roadmap

## Phase 1: establish taxonomy and reason codes
Add this taxonomy as the canonical audit vocabulary.

Deliverables:
- action type registry
- reason code registry
- common metadata field definitions
- outcome registry

## Phase 2: make existing wrappers emit structured events
Do not rewrite the framework yet. Instead, augment existing helpers to emit JSON lines or event records.

Highest-value wrappers to instrument first:
- `dispatch-named-agent.sh`
- `send-agent-callback.sh`
- `create-agent-issue.sh`
- `create-agent-pr.sh`
- `update-agent-pr-body.sh`
- `post-agent-comment.sh`
- `post-pr-line-comment.sh`
- `update-agent-wiki-page.sh`
- `update-release-state.py`
- `cut-release-tag.sh`

## Phase 3: add typed wrapper surfaces for fuzzy actions
Introduce lightweight wrappers for currently prompt-shaped but high-value actions:
- `triage.start`
- `triage.report.publish`
- `spec.issue.shape`
- `qa.verdict`
- `security.review.prebuild`
- `security.review.pr`
- `orchestrator.route`
- `orchestrator.escalate-human`

These wrappers do not need to contain the whole agent brain. They only need to capture the action as a discrete event boundary.

## Phase 4: UI and analytics layer
Once Phase 2 and a small part of Phase 3 exist, the UI can graph:
- action counts by type
- state transition timelines
- average latency by action family
- callback timeout rates
- loops such as `orchestrator.route -> spec.issue.shape -> orchestrator.route -> triage.start -> orchestrator.route`
- dead-end patterns such as repeated comments without issue/PR creation

## Phase 5: enforce action typing where it matters most
Only after the taxonomy is proven useful should the framework start requiring some actions to pass through discrete wrappers.

Candidates for mandatory typed boundaries:
- routing
- callback ingestion
- issue creation
- PR creation
- review verdicts
- release transitions

---

# Recommended UI views enabled by this taxonomy

With this taxonomy implemented, the swarm UI should be able to show:

## 1. Action timeline
Per project or per issue:
- when each action occurred
- which agent performed it
- duration and outcome

## 2. Action family graph
Counts and durations for:
- routing
- triage
- spec shaping
- implementation
- review
- release

## 3. Loop detector
Examples:
- repeated `orchestrator.route`
- repeated `spec.issue.comment` without issue readiness progress
- repeated `qa.review.pr` without Builder updates
- repeated `triage.start` on the same class of incident

## 4. Bottleneck analysis
Examples:
- average time from `orchestrator.route` to `callback.send`
- average time from `builder.pr.open` to `qa.verdict`
- average time from `triage.start` to `triage.report.publish`

## 5. Invisible-work detector
Highlight projects where many comments/dispatches happen without meaningful state transitions like:
- issue created
- PR opened
- approval label applied
- release state updated

---

# Blunt assessment

The current framework is already better than pure prompt soup because many important side effects are wrapped in helper scripts.

But from an audit/UI perspective, it is still mostly:
- **prompted operating model + helper scripts**

rather than:
- **typed action protocol + structured event stream**

That is good enough to operate the swarm, but not yet good enough to observe it cleanly.

If the goal is a serious UI and action audit layer, the highest-leverage next move is not to invent dozens of new tools immediately. It is to:
1. define the taxonomy
2. instrument existing wrappers
3. add typed wrappers only where prompt-shaped behavior is currently invisible but operationally important

That will make inefficiencies and loops visible without turning the framework into bureaucratic glue code.
