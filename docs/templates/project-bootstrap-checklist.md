# Project Bootstrap Checklist

Use this checklist when creating a new project repo.

## Repository Setup

- [ ] Repository created
- [ ] Default branch confirmed
- [ ] Repo access/ownership confirmed

## Template Installation

- [ ] `.github/ISSUE_TEMPLATE/spec-task.md` installed
- [ ] `.github/ISSUE_TEMPLATE/architecture-decision.md` installed
- [ ] `.github/ISSUE_TEMPLATE/bugfix-task.md` installed
- [ ] `.github/pull_request_template.md` installed
- [ ] `.github/workflows/merge-gate.yml` installed
- [ ] `SPEC.md` scaffold installed

## Labels

- [ ] `spec-needed`
- [ ] `architecture-needed`
- [ ] `ready-for-build`
- [ ] `in-build`
- [ ] `in-review`
- [ ] `needs-clarification`
- [ ] `blocked`
- [ ] `done`
- [ ] `needs-spec-review`
- [ ] `needs-qa`
- [ ] `changes-requested`
- [ ] `ready-to-merge`
- [ ] `qa-approved`
- [ ] `spec-satisfied`
- [ ] `orchestrator-approved`

## Initial Documentation

- [ ] Project overview exists
- [ ] Problem statement exists
- [ ] Scope / non-goals documented
- [ ] Architecture placeholder or initial design exists

## Initial Planning

- [ ] Initial project spec drafted
- [ ] Initial assumptions documented
- [ ] Initial backlog created
- [ ] Backlog broken into small deliverable chunks

## Human Review

- [ ] Spec reviewed by Patrick
- [ ] Backlog reviewed by Patrick
- [ ] Architecture direction reviewed if needed

## Onboarding Automation

- [ ] `scripts/onboard-project.sh <project-slug> <repo-path>` run successfully
- [ ] `scripts/set-agent-git-identity.sh` applied to the project repo
- [ ] Branch protection configured to require the merge-gate workflow (if GitHub setup enabled)

## Ready-to-Build Gate

- [ ] At least one issue meets definition of ready
- [ ] First issue assigned or ready for assignment
