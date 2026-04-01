# Spec Approval Labels

## Purpose

Define the label-based convention for identifying spec-related issues and the automation gate issue.

## Core rule
Do not infer spec approval from issue titles alone.
Use labels.

## Label model

### Spec-relatedness
Use labels to indicate that an issue belongs to the Spec lane or is owned by Spec.

### Automation gate
Use a dedicated label to indicate that an issue is the project's spec-approval gate.

Recommended label:
- `spec-approval`

## Automation trigger rule

Orchestrator should look for the issue that:
- is spec-related by label
- carries the `spec-approval` label

### If that issue is open
- guided mode

### If that issue is closed/completed
- autonomous delivery mode within approved bounds

## Why this is better
This is more machine-readable and less brittle than relying on issue title patterns.
