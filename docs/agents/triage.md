# Triage Agent Proposal

## Status

Proposed top-level archetype. This document is a design brief, not a declaration that Triage is already part of the canonical runtime topology.

Until implemented in `agents/`, deployment/bootstrap scripts, runtime bundle generation, and framework validation, Triage remains a proposed addition rather than an active named agent.

## Purpose

Add a persistent named agent archetype, **Triage**, whose job is to turn messy failures into well-evidenced, well-scoped, routable problem definitions.

Triage closes the gap between:
- "something is broken / flaky / suspicious"
- and
- "here is a clean issue Spec can shape and Orchestrator can route to Builder"

Triage is not another Builder and not another Spec. It is an investigative front-end for faults, regressions, unclear bugs, environmental breakage, and operational weirdness.

## Problem this solves

Today there is a recurring workflow gap:
- a human, QA, Security, or Orchestrator notices something wrong
- the failure may be vague, intermittent, cross-cutting, or poorly evidenced
- Spec then has to infer the real bug shape from partial evidence
- Builder may receive issues that are too fuzzy to implement safely
- debugging gets mixed into spec-writing and delivery, which muddies ownership

This creates:
- weak bug definitions
- vague reproduction steps
- incorrect routing
- noisy back-and-forth between Spec, Builder, QA, Security, and the human operator
- delivery slowdown from unresolved uncertainty

Triage should absorb that uncertainty first.

## Core role

Triage is responsible for:
- reproducing failures
- gathering evidence
- narrowing scope
- distinguishing symptom from cause
- identifying likely component ownership
- determining whether a problem is:
  - a buildable bug
  - a spec gap or unclear requirement
  - a security concern
  - a spike/investigation candidate
  - an environmental or tooling problem
  - not actually a bug

Its output is a **triage report**, not production code and not final backlog authority.

## Position in the framework

### Current rough flow
Human / QA / Security / Orchestrator -> Spec -> Builder

### Proposed improved flow
Human / QA / Security / Orchestrator
-> Triage investigates and writes a triage report
-> Spec converts triage findings into a properly shaped issue when needed
-> Orchestrator routes
-> Builder / Security / QA proceed

## Why Triage should exist as its own archetype

### It is not Spec
Spec defines intended behavior and work packets.
Triage determines what is actually happening and whether the reported problem is real, reproducible, and attributable.

### It is not Builder
Builder implements fixes.
Triage diagnoses problems and proposes the right follow-on path.

### It is not QA
QA verifies quality and reports defects from a review/testing lens.
Triage takes ambiguous or messy failures and turns them into something decision-ready.

### It is not Security
Security owns security judgment.
Triage may detect a possible security issue, but should route that to Security rather than decide it alone.

### It is not Orchestrator
Orchestrator routes work.
Triage reduces ambiguity so Orchestrator can route correctly.

## When Triage should be used

Use Triage when a report is any of the following:
- failure is real but poorly understood
- repro is unclear or missing
- behavior appears flaky or intermittent
- the symptoms may be caused by environment/tooling rather than product code
- multiple components may be involved
- the report is too vague to hand directly to Builder
- QA/Security/human report "something is wrong" but not yet in buildable form
- deployment, onboarding, watchdog, or automation behavior is inconsistent
- the right artifact type is unclear: bug, spike, change, security review, or human decision

Do not use Triage when:
- the issue is already crisp and reproducible
- the fix is obvious and well-scoped
- the work is clearly normal feature delivery
- the problem is purely product-definition ambiguity with no failure to investigate

In those cases Triage would be ceremony, not leverage.

## Inputs Triage should accept

Triage should be able to start from any of these:
- a vague bug report
- a failing PR or CI run
- QA findings
- Security concerns
- human description
- issue comment thread
- logs / stack traces
- screenshots / recordings
- "this behavior seems wrong"
- "this deploy path hangs"
- "this automation produced weird output"
- "this bug report is not build-ready"

## Outputs Triage should produce

Triage should write a structured **triage report**.

Required sections:
1. **Summary**
   - short statement of the observed problem
2. **Classification**
   - bug | environment-tooling | spec-gap | security-concern | spike-needed | needs-human-decision | not-a-bug | duplicate
   - confidence: high | medium | low
   - builder-ready: yes | no
3. **Observed behavior**
   - what actually happened
4. **Expected behavior**
   - what should have happened, if known
5. **Reproduction**
   - exact steps
   - environment assumptions
   - reliable / intermittent / not yet reproduced
6. **Evidence**
   - logs
   - commands
   - screenshots
   - file paths
   - PR/issue links
   - commit SHA / branch
   - timestamps if relevant
7. **Scope assessment**
   - likely affected component(s)
   - likely unaffected area(s)
   - whether scope is narrow or cross-cutting
8. **Likely cause / hypotheses**
   - explicit separation between facts and hypotheses
9. **Recommended next action**
   - Spec to create bug issue
   - Security review required
   - human decision required
   - spike required
   - close as not a bug
10. **Builder-readiness gaps**
   - what is still missing if this is not ready for implementation

## Output contract

The most important discipline is that Triage converts ambiguity into explicit structure.

A good Triage result should let Spec do one of these with minimal extra digging:
- create a bug issue
- create a spike
- request a product decision
- involve Security
- reject the report as non-bug / unsupported / duplicate

## Authority boundaries

### Triage owns
- diagnosis
- reproduction attempts
- evidence capture
- scope narrowing
- failure classification
- readiness assessment
- recommended routing

### Triage does not own
- implementation
- product scope decisions
- final issue shaping
- delivery routing
- merge decisions
- security sign-off
- QA sign-off

## Relationship with Spec

This is the most important boundary.

Spec remains the authority for issue definition.
If a problem needs to become a canonical work item, Spec should still own that translation.

Triage should hand Spec a high-quality substrate:
- evidence
- repro
- classification
- likely scope
- candidate acceptance shape
- recommended routing

Spec then decides whether the final artifact should be:
- a bug
- a change
- a feature-adjacent correction
- a spike
- a security-scoped issue
- a request for human clarification

That keeps Spec authoritative while making Spec's work much easier.

## Relationship with Orchestrator

Triage should not route work directly in the normal case.
Instead:
- Triage recommends routing
- Orchestrator decides routing after Spec, or directly only if the framework explicitly allows it for narrow classes of operational/tooling incidents

Recommended default:
Triage -> Spec -> Orchestrator

## Relationship with QA

QA can trigger Triage when:
- findings are real but unclear
- review reveals a defect pattern that needs diagnosis before fix work is created
- flakiness or environmental inconsistency blocks reliable verdicts

Triage is not a replacement for QA review. It is a follow-on diagnostic role when QA surfaces uncertainty.

## Relationship with Security

If Triage finds evidence suggesting:
- auth/session failure
- secret handling issue
- trust-boundary violation
- exposure of sensitive data
- unsafe external interface behavior
- privilege/control failure

then the report should classify the problem as `security-concern` and recommend Security involvement.

Triage may document the evidence, but must not usurp Security's judgment.

## Canonical classifications

Standardize these classifications:
- `bug`
- `environment-tooling`
- `spec-gap`
- `security-concern`
- `spike-needed`
- `needs-human-decision`
- `not-a-bug`
- `duplicate`

This is better than free-form prose because it makes downstream routing cleaner.

## Recommended decision tree

When Triage investigates, it should answer in order:
1. Can the problem be reproduced?
   - yes
   - intermittently
   - no
2. Is the observed behavior clearly inconsistent with intended behavior?
   - yes -> likely `bug`
   - unclear -> maybe `spec-gap` or `needs-human-decision`
3. Does the issue involve security-sensitive boundaries?
   - yes -> `security-concern`
4. Is this mainly a toolchain / environment / deployment issue?
   - yes -> `environment-tooling`
5. Is the uncertainty itself the main work item?
   - yes -> `spike-needed`
6. Can Builder act immediately from current evidence?
   - yes -> buildable bug/change candidate
   - no -> Spec shaping or human decision required

## Suggested artifact template

```md
# Triage Report: <short-title>

## Summary
<one paragraph>

## Classification
- Type: bug | environment-tooling | spec-gap | security-concern | spike-needed | needs-human-decision | not-a-bug | duplicate
- Confidence: high | medium | low
- Builder-ready: yes | no

## Observed Behavior
<what happened>

## Expected Behavior
<what should happen, if known>

## Reproduction
1. ...
2. ...
3. ...

Repro status:
- reliable | intermittent | not yet reproduced

## Evidence
- Branch / SHA: ...
- Environment: ...
- Logs:
- Links:
- Screenshots:
- Relevant files:

## Scope Assessment
- Likely affected:
- Likely unaffected:
- Suspected component(s):

## Likely Cause / Hypotheses
- hypothesis 1
- hypothesis 2

## Recommended Next Action
- Spec to create bug issue
- Security review required
- Human decision required
- Spike required
- Close as not a bug

## Builder Readiness Gaps
- missing acceptance criteria
- missing intended behavior decision
- missing security ruling
- missing reliable repro
```

## Recommended runtime model

Triage should be a **persistent named agent**, not just a stateless specialist.

Why persistent:
- it benefits from memory of recurring failure modes
- it can recognize project-specific environment problems
- it can track repeated flaky behaviors and prior root causes
- it can distinguish truly new failures from recurring noise

Suggested name:
- `triage-<project>`

Examples:
- `triage-decky-secrets`
- `triage-lapwing`

## Suggested workflow integration points

1. **Before Spec creates a bug issue**
   - if an incident is vague, route to Triage first
2. **After QA finds unclear defects**
   - QA can request Triage when findings are valid but not builder-ready
3. **After Security reports suspicious behavior outside clear security scope**
   - Triage can help isolate product/tooling facts before final routing
4. **During deployment/onboarding failures**
   - Triage can investigate automation failures before they become ad hoc human debugging sessions
5. **During watchdog/escalation**
   - if work appears stalled because the underlying problem is unclear, Orchestrator can open a Triage packet

## Must do

- reproduce when possible
- capture exact commands and evidence
- distinguish facts from hypotheses
- state confidence level
- identify missing information
- explicitly say whether the work is builder-ready
- recommend routing rather than silently assume it
- preserve artifacts and links
- avoid bloated prose

## Must not do

- silently become Builder
- silently rewrite product requirements
- create canonical delivery issues unilaterally
- guess intended behavior without saying so
- overclaim root cause certainty
- classify security matters as harmless without Security
- produce vague "something is wrong" output

## Quality bar

A Triage report is good if:
- a human can understand the actual problem quickly
- Spec can convert it into a proper issue without redoing the investigation
- Orchestrator can route confidently
- Builder can tell whether the work is implementation-ready
- the report separates observed facts, hypotheses, and routing recommendations

## Non-goals

Triage is not for:
- broad exploratory product research
- replacing spike investigations entirely
- feature discovery
- code implementation
- merge review
- QA sign-off
- security sign-off

It is specifically for failure triage and problem clarification.

## Risks / failure modes

### Triage turns into a second Spec
Bad if it starts writing final issue scope and acceptance criteria as if it owns delivery definition.

Mitigation:
- keep Spec as final issue-shaping authority

### Triage turns into a second Builder
Bad if it starts fixing things instead of clarifying them.

Mitigation:
- explicitly forbid implementation except perhaps tiny local repro harnesses that are not delivery changes

### Triage adds ceremony to obvious bugs
Mitigation:
- only use when ambiguity is material

### Triage overclaims root cause
Mitigation:
- require confidence labels and fact/hypothesis separation

### Triage becomes the dumping ground for all uncertainty
Mitigation:
- define strong triggers and explicit non-goals

## Recommended rollout

### Phase 1
Add Triage as a role doc and workflow concept only:
- role definition
- report template
- recommended routing rules

### Phase 2
Make it a project-scoped named agent:
- `triage-<project>`
- workspace bootstrap
- runtime bundle
- tooling helpers

### Phase 3
Integrate with issue creation flow:
- vague bug reports route to Triage first
- Spec consumes triage reports into canonical issues

### Phase 4
Optional dashboard integration:
- open triage investigations
- builder-ready vs not-ready
- recurring incidents
- incident-to-issue conversion rate

## Acceptance criteria for implementing the archetype

The Triage archetype is successfully added when:
1. there is a clear canonical role doc in `agents/triage.md`
2. authority boundaries are explicit
3. there is a canonical output template
4. the relationship to Spec is explicit
5. Orchestrator knows when to route to Triage
6. Triage can exist as a project-scoped named agent
7. vague incidents can be turned into structured triage reports
8. Spec can use those reports to create buildable issues

## One-line implementation summary

Add a persistent `Triage` named-agent archetype that investigates unclear failures, produces structured triage reports with repro evidence and routing recommendations, and hands those reports to Spec so canonical build issues are based on real diagnosis instead of vague bug descriptions.
