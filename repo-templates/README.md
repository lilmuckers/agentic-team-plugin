# Repo Templates

This directory contains files intended to be copied into individual project GitHub repositories.

## Purpose

These are **project-repo assets**, not control-plane documents.
Each software project should have its own GitHub repo and should receive its own copy of relevant templates.

## Contents

- `.github/ISSUE_TEMPLATE/spec-task.md`
- `.github/ISSUE_TEMPLATE/architecture-decision.md`
- `.github/ISSUE_TEMPLATE/bugfix-task.md`
- `.github/ISSUE_TEMPLATE/release-tracking.md`
- `.github/pull_request_template.md`
- `.github/workflows/merge-gate.yml`
- `SPEC.md`
- `docs/delivery/release-state.md`

## Usage

When bootstrapping a new project repository:

1. Copy the relevant files from this directory into the repo root.
2. Customize labels, language, and checks as needed for the project.
3. Keep project-specific docs, issue history, PRs, and wiki content in that repo.
4. For application repos, add `docker-compose.yml` and `.devcontainer/devcontainer.json` to satisfy the Docker-first local-dev contract.

The merge-gate template now conditionally requires `security-approved` when a PR carries `security-scope` or `security-review-required`.

## Boundary

- `docs/` in this workspace = delivery control-plane guidance
- `repo-templates/` in this workspace = reusable files to install into each project repo
