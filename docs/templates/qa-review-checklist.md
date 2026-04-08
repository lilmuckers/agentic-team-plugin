# QA Review Checklist

Use this checklist when reviewing a PR.

## Contract Check

- [ ] PR links to a concrete issue
- [ ] Acceptance criteria are visible and testable
- [ ] Any deviations are explicitly documented

## Implementation Check

- [ ] Change appears to satisfy stated scope
- [ ] No obvious scope creep without documentation
- [ ] Edge cases considered at a sensible level
- [ ] Code is maintainable enough for the risk level

## Verification Check

- [ ] Tests are present or omission is justified
- [ ] Bugfixes include automated regression coverage, or Spec has explicitly accepted a documented impossibility exception
- [ ] CI/checks status is acceptable
- [ ] Manual verification evidence is sufficient if needed

## Documentation Check

- [ ] Behavior changes are documented
- [ ] Operational/developer docs updated if required
- [ ] Project-level assumptions were routed back to Spec where needed

## Outcome

- [ ] Approve
- [ ] Request changes
- [ ] Needs clarification from Spec
