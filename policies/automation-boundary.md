# Automation Boundary Policy

## Core rule
Orchestrator should not run in full autonomous delivery mode until the designated spec-related approval-gate issue (identified by labels, not title alone) has been explicitly completed/closed by the human operator.

## Pre-approval mode
While the designated spec-approval issue remains open:
- Orchestrator coordinates
- Spec defines project truth
- human approval is required for project definition, MVP scope, major assumptions, and key architecture direction

## Post-approval mode
After the designated spec-approval issue is completed/closed:
- Orchestrator may autonomously coordinate delivery within the approved bounds
- routine issue routing, Builder coordination, QA coordination, and backlog flow may proceed without asking for step-by-step human approval

## Escalation rule
Even after spec approval, Orchestrator must escalate when a proposed action would materially exceed the approved scope, assumptions, or architecture direction.
