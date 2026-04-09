# Release Manager Operating Model

## Purpose

Define the durable release-state path for project repos.

## Required visible artifacts

For each active release, keep these artifacts current:
- a release tracking issue labeled `release-tracking`
- `docs/delivery/release-state.md`
- GitHub tags / pre-releases / final release entries

## Default iteration model

1. open or update the release tracking issue
2. update `docs/delivery/release-state.md`
3. cut beta tag
4. request QA and Security release testing
5. triage accepted issues with Spec and Orchestrator
6. repeat beta or rc iterations until clean
7. publish final release and close tracking

## Helper

Use `scripts/update-release-state.py` to keep the `## Current Release` JSON block current.
