# Framework workflow review

## Purpose of this review

This review maps the framework from the human trigger points downward and identifies where the workflows are clear, where guidance is muddy, and where role boundaries still overlap enough to create uncertainty.

The main areas reviewed were:

1. defining a new project from scratch
2. how releases are triggered
3. how changes are brought in
4. how bugs are highlighted
5. adjacent relevant processes that affect delivery clarity

## Executive summary

The framework now has a substantially clearer intended operating model than it did earlier.

The core model is:

- Human provides direction, approvals, and final judgment at defined gates
- Orchestrator owns delivery flow and routing
- Spec owns product meaning, readiness, scope, and wiki product truth
- Builder owns implementation
- QA owns verification
- Security owns security review where needed
- Release Manager owns release coordination and release knowledge

That part is mostly coherent.

The weaker areas are now less about raw ownership confusion and more about activation and trigger ambiguity:

- new-project startup is still too operator-script-centric
- release initiation has too many possible authorities and not one canonical trigger rule
- change intake is split across several overlapping paths
- bug handling exists, but is spread across multiple layers of framework definition
- there are still too many partially-canonical documents defining workflow behavior

In short: the framework is getting good at routing work once a flow is underway, but it is still weaker at defining the exact trigger conditions, activation boundaries, and canonical control surface for each major workflow.

---

## 1. Defining a new project from scratch

### Intended flow

The intended bootstrap path appears to be:

1. human creates or identifies a project repository
2. operator runs `scripts/onboard-project.sh <project-slug> <path-to-project-repo>`
3. onboarding creates six project-scoped named agents, deploys workspace bootstrap, clones the repo into each workspace, installs templates, optionally bootstraps GitHub setup, and installs the watchdog
4. smoke tests confirm the agents are wired correctly
5. Spec begins the first project-definition conversation with the human
6. Spec creates or refines `SPEC.md`, wiki material, and an initial backlog
7. human reviews the spec, architecture direction, and backlog
8. Orchestrator activates the first truly ready issue
9. Builder begins normal implementation only after a genuine ready-for-build handoff

### Strengths

The framework is right to insist that:

- implementation should not start from chat-only understanding
- specification should come before build work
- named project agents should exist before delivery starts
- the human should review the initial project definition before the backlog goes active

Those are good guardrails.

### Weaknesses

#### 1.1 Bootstrap and project-definition are distinct, but the boundary is still soft

The framework distinguishes between:

- technical bootstrap, where the repo and agent infrastructure are prepared
- project definition, where the actual product, scope, backlog, and assumptions are defined

That distinction is sensible, but the exact handoff between them is not yet encoded tightly enough.

There is still a fuzzy gap between:

- “the repo and agents exist”
- “the project is actually defined”
- “the project is approved to begin delivery”

That should probably become one explicit activation contract.

#### 1.2 First activation is still more ritual than hard workflow

The framework describes a sensible sequence for first activation, but it is still mostly prose-driven.

There is not yet one hard definition of:

- what artifact set makes a project “active”
- who records that it is active
- what exact conditions must be true before the first Builder task is legitimate

Right now, the process is understandable, but still partly depends on operator good sense and memory.

#### 1.3 Initial backlog ownership is not sharp enough

The intended split seems to be:

- Spec owns initial project definition and issue shaping
- Orchestrator owns sequencing and activation

That is the right model.

But the framework still leaves some ambiguity around:

- who creates the first issues
- who decides they are decomposed well enough
- whether backlog decomposition is fundamentally Spec-owned or jointly shaped by Orchestrator

That distinction should be stated more crisply.

#### 1.4 Project creation is still shell-script-native, not workflow-native

From a practical point of view, “starting a new project” is still mostly a shell-script process with agent work layered on top.

That is not inherently wrong, but it means the framework’s first major workflow is not yet truly first-class in the same way as the implementation path.

If the framework wants project commissioning to be part of the delivery model itself, it should eventually define project activation as a proper workflow with clear completion criteria.

---

## 2. How releases are triggered

### Intended flow

The framework currently indicates that a release may be signalled by:

- the human
- Spec
- Orchestrator
- completing the final implementation slice

Once signalled, Release Manager is meant to:

1. open or update a release tracking issue
2. update `docs/delivery/release-state.md`
3. cut beta iterations
4. request QA and Security release testing
5. surface findings for triage with Spec and Orchestrator
6. route accepted fixes back through Orchestrator
7. repeat beta and RC loops until clean
8. cut final release
9. publish the GitHub release
10. write the final release summary to the wiki

### Strengths

The role boundary is much clearer than before:

- Release Manager owns release coordination
- Orchestrator must not silently absorb release duties
- Spec and Orchestrator still own triage and release-shape decisions
- implementation remains routed through the standard Orchestrator flow

That is good.

### Weaknesses

#### 2.1 Release trigger authority is plural where it should be singular

This is the biggest release-design weakness.

The framework allows multiple actors to signal that a release is due, but it does not define one canonical rule for when release coordination should begin.

Open questions remain muddy:

- is release start primarily human-driven?
- can Orchestrator trigger release automatically when the backlog reaches a certain state?
- can Spec trigger release because product scope appears complete?
- is “final slice complete” enough to create a release automatically, or should it only recommend one?

Those are materially different behaviors, and the current framework does not fully collapse them into a single control rule.

#### 2.2 Version-scale authority is still somewhat split

The release model says:

- Spec and Orchestrator determine version scale
- Release Manager applies the scale mechanically

That is workable, but still slightly muddy.

Spec owns meaning. Orchestrator owns flow. Both influence release sizing. That can work, but the framework would be stronger if it defined a clearer tie-break rule when their instincts differ.

#### 2.3 The YAML release contract is thinner than the role docs

`workflows/prepare-release.yaml` describes the release flow at a high level, but it is still much less complete than the role docs and supporting delivery docs.

That means there is still a dual-fidelity problem:

- one layer describes the rich intended workflow
- another layer describes a thinner schematic version

That risks drift and inconsistent interpretation.

#### 2.4 Human release approval needs an even sharper stop line

The human-approval policy correctly requires explicit human approval before releasing to production or an equivalent live environment.

That is good.

But the framework would benefit from making the release stop line more explicit, for example:

- Release Manager may prepare beta and RC iterations autonomously within policy
- final release publication requires explicit human go-ahead

That appears implied, but it should be stated more cleanly.

---

## 3. How changes are brought in

### Intended flow

The standard change path appears to be:

1. human raises a request, clarification, or architectural change
2. Orchestrator classifies the request
3. if not implementation-ready, Orchestrator routes to Spec
4. Spec shapes the issue, acceptance criteria, assumptions, and durable project context
5. Orchestrator validates ready-for-build
6. Builder implements the issue on a branch and opens a PR
7. QA reviews the PR
8. Spec and Orchestrator determine mergeability in project context
9. human approves merge where required
10. the PR is merged and durable docs are updated where necessary

### Strengths

This is the strongest and clearest workflow in the framework.

The important underlying model is now coherent:

- Spec-first in substance
- Orchestrator-first in control flow

That is the right shape.

### Weaknesses

#### 3.1 The `change` issue type is underspecified

The label taxonomy includes:

- feature
- bug
- change
- chore
- docs
- investigation
- spike

But `change` is not defined sharply enough.

It risks becoming a catch-all bucket for work that should probably be classified more precisely.

At the moment, it is unclear whether `change` means:

- modification to an existing behavior
- non-bug behavioral tweak
- scope change to an existing feature
- small enhancement
- some other middle category between feature and chore

That ambiguity is likely to create inconsistent issue shaping.

#### 3.2 Human direct-to-Spec interaction is valid, but still delicate operationally

The framework now correctly says that direct user interaction with Spec does not give Spec permission to implement.

That is the right rule.

But in practice it still creates an awkward control hop:

- human talks to Spec
- Spec updates spec-owned artifacts
- Spec must callback to Orchestrator
- Orchestrator then dispatches Builder

That is conceptually correct, but it is a place where shortcutting will remain tempting unless strongly reinforced.

#### 3.3 Architectural change can enter through too many doors

Architecture-level changes can arise from:

- the human
- Spec
- Builder discovering ambiguity
- QA surfacing contract mismatch
- Security surfacing trust-boundary concerns
- release findings

That is realistic, but the framework does not yet reduce these into one especially crisp ownership rule for architecture change handling.

The likely correct model is:

- Spec owns architecture definition
- Orchestrator owns routing and escalation
- Builder must not convert architecture uncertainty into implementation improvisation
- Security owns security architecture and trust-boundary concerns where relevant

The framework broadly implies that, but it should be stated more directly and in one place.

#### 3.4 Post-merge durable updates are still distributed across too many surfaces

The framework has become better at defining pre-merge flow than post-merge durable maintenance.

After merge, the necessary updates may include:

- wiki
- `SPEC.md`
- README
- decision records
- release-state

Those obligations exist, but they are distributed across multiple documents rather than expressed as one coherent post-merge truth-maintenance contract.

---

## 4. How bugs are highlighted

### Intended flow

The intended bug path appears to be:

1. a bug is discovered by the human, QA, Builder, Security, or release testing
2. a bug report or defect issue is created
3. Spec clarifies intended behavior, acceptance criteria, and regression expectations
4. Security reviews if the bug is security-scope
5. Orchestrator validates readiness and routes Builder
6. Builder fixes the bug and adds regression automation unless genuinely impossible
7. QA verifies the fix
8. Orchestrator routes merge or rework
9. if the bug reveals durable knowledge, wiki or decision-record updates follow

### Strengths

This is significantly improved relative to earlier iterations.

The strongest parts are:

- QA reports defects but does not own product truth
- Spec owns bug-contract meaning and exception approval
- regression coverage is the default expectation
- missing regression coverage can legitimately block approval
- durable lessons are now explicitly supposed to be promoted into longer-lived knowledge

### Weaknesses

#### 4.1 Bug handling is spread across too many framework layers

The bug lifecycle currently has to be reconstructed from:

- `workflows/fix-bug.yaml`
- QA rules
- Spec rules
- label guidance
- supporting docs
- roadmap decisions

The overall shape is inferable, but it is not yet centralized into one clean canonical bug lifecycle.

#### 4.2 The framework does not sharply separate review defects, independent bugs, and release defects

At least three distinct bug contexts exist:

- a defect found during PR review
- a bug found independently outside an active PR
- a defect found during release testing

The framework seems aware of these, but it does not yet give one crisp routing table that distinguishes them cleanly.

That matters because the correct visible artifact path may differ between them.

#### 4.3 Triage authority is correct in principle but crowded in practice

The intended model seems to be:

- QA discovers or reports
- Spec classifies meaning and scope
- Orchestrator routes the fix path
- Release Manager coordinates if the issue sits inside a release loop
- human resolves contested cases

That is workable, but it is crowded enough that agents may still hesitate about who should act next.

A simpler explicit rule would help.

#### 4.4 Durable bug lessons still depend on judgment calls

The new wiki policy is a good governance improvement, but “this bug revealed a durable lesson” is still a judgment-based trigger.

That means some important bug knowledge may still remain buried in issues or PRs instead of becoming durable project memory.

---

## 5. Other relevant processes and cross-cutting weaknesses

### 5.1 Security involvement is still a soft gate

Security participation is conditional, which is reasonable.

But that means the whole framework still depends on someone classifying work correctly as `security-scope` early enough.

If that classification is missed, Security may never be involved.

That is an unavoidable soft-gate risk unless the framework introduces stronger heuristics or validation.

### 5.2 Wiki ownership is much stronger, but still mostly policy-driven

The new wiki policy is good.

It clarifies:

- what belongs in the wiki
- who owns which knowledge domain
- what triggers mandatory updates
- that completion is blocked when certain wiki duties are missing

That is the right design move.

But it is still prompt and policy enforcement, not strong runtime or smoke-test enforcement. So it reduces ambiguity, but does not yet guarantee compliance.

### 5.3 Mergeability is sensible but gate-heavy

The framework’s merge path now expects some combination of:

- QA approval
- Spec satisfaction
- Orchestrator approval
- Security approval where needed
- human approval for actual merge

That is conceptually sound.

But it also means the system is sensitive to even small routing or callback failures. If communication machinery is flaky, the merge path can stall easily.

### 5.4 Runtime freshness remains an operational weakness

The framework explicitly acknowledges that role/policy changes become truly live on fresh session boundaries.

That means:

- deployed truth on disk
- currently running named-agent behavior

can temporarily diverge.

That is a real operational weakness because it creates uncertainty about whether the current workflow is the one actually being followed by a long-lived agent session.

---

## Biggest structural weaknesses overall

### 1. Too many partially-canonical sources of truth

Workflow behavior is defined across:

- role docs
- workflow YAMLs
- policies
- README
- delivery docs
- roadmap decisions

These mostly align, but there are still too many layers capable of shaping interpretation.

That is a maintenance risk and a clarity risk.

### 2. Trigger authority is sometimes plural where it should be singular

This is especially visible in:

- release initiation
- version scale decisions
- bug triage escalation
- first-project activation

Whenever multiple actors are all allowed to trigger the same major workflow, uncertainty tends to creep in.

### 3. Too much important behavior is described normatively rather than enforced operationally

Many critical rules exist as “must” and “must not” statements, but are not always backed by one hard validator, one required artifact, or one enforced script gate.

That is where process drift tends to emerge.

### 4. Human interaction types are not classified sharply enough

The framework clearly expects the human to be involved at several points:

- project-definition approval
- architecture judgment calls
- merge approval
- release approval
- blocker overrides

That is good.

But it would be stronger if it explicitly classified human-facing interactions into:

- approval required
- judgment requested
- status only

That would make the operational surface cleaner.

---

## Recommended improvements

### 1. Define one canonical release trigger contract

Recommended direction:

- the human can always trigger release
- Orchestrator may trigger release only when an agreed release condition is met
- Spec may recommend release but not unilaterally start it
- “final slice complete” should create a release recommendation, not automatically start release coordination

### 2. Define one explicit project activation contract

Recommended direction:

A project should become “active” only when all of the following are true:

- onboarding completed successfully
- smoke tests passed
- initial `SPEC.md` exists
- initial backlog exists
- human reviewed and approved spec/backlog direction
- at least one issue is validated ready-for-build
- Orchestrator records the project as active

That would turn first activation into a real workflow state rather than a mostly implied one.

### 3. Tighten issue taxonomy, especially `change`

Recommended direction:

- either define `change` very explicitly
- or remove it and force clearer categorization into feature, bug, chore, docs, spike, or investigation

Right now `change` is too mushy.

### 4. Create one canonical bug lifecycle document

Recommended direction:

Document in one place:

- how bugs enter the system
- when they stay in PR review versus become standalone issues
- who classifies scope and meaning
- who routes fixes
- when regression automation is mandatory
- when durable bug lessons must be captured

That would reduce the current spread across multiple framework layers.

### 5. Promote one behavioral layer as canonical

Recommended direction:

- role docs plus policies should be canonical behavioral truth
- workflow YAMLs should be concise machine-readable summaries only
- README and delivery docs should explain, not redefine

That would reduce drift risk.

### 6. Sharpen the human decision surface

Recommended direction:

Explicitly classify human-facing workflow moments as:

- approval required
- judgment requested
- status only

That would make the framework’s interaction model clearer and easier to operate reliably.

---

## Final judgment

The framework is now materially stronger on role boundaries than it was before.

The main remaining weaknesses are not primarily “who owns implementation?” anymore. They are now mostly about:

- when exactly major workflows begin
- who is recommending versus deciding
- which document is canonical when multiple documents describe the same process
- what exact conditions count as startup, release readiness, or durable completion

That means the framework’s next maturity step should probably be less about adding more roles or more policy and more about tightening trigger contracts, activation boundaries, and canonical workflow definitions.
