# Automation Boundary Policy

## Core rule
Orchestrator should not run in full autonomous delivery mode until the project spec has been explicitly approved by the human operator.

## Pre-approval mode
Before spec approval:
- Orchestrator coordinates
- Spec defines project truth
- human approval is required for project definition, MVP scope, major assumptions, and key architecture direction

## Post-approval mode
After spec approval:
- Orchestrator may autonomously coordinate delivery within the approved bounds
- routine issue routing, Builder coordination, QA coordination, and backlog flow may proceed without asking for step-by-step human approval

## Escalation rule
Even after spec approval, Orchestrator must escalate when a proposed action would materially exceed the approved scope, assumptions, or architecture direction.
