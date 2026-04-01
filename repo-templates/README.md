# Repo Templates

This directory contains files intended to be copied into individual project GitHub repositories.

## Purpose

These are **project-repo assets**, not control-plane documents.
Each software project should have its own GitHub repo and should receive its own copy of relevant templates.

## Contents

- `.github/ISSUE_TEMPLATE/spec-task.md`
- `.github/ISSUE_TEMPLATE/architecture-decision.md`
- `.github/ISSUE_TEMPLATE/bugfix-task.md`
- `.github/pull_request_template.md`
- `SPEC.md`

## Usage

When bootstrapping a new project repository:

1. Copy the relevant files from this directory into the repo root.
2. Customize labels, language, and checks as needed for the project.
3. Keep project-specific docs, issue history, PRs, and wiki content in that repo.

## Boundary

- `docs/` in this workspace = delivery control-plane guidance
- `repo-templates/` in this workspace = reusable files to install into each project repo
