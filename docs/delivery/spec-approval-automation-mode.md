# Spec Approval and Automation Mode

## Purpose

Define the approval boundary between human-guided setup and autonomous delivery orchestration.

## Core rule
Before the project spec is approved, Orchestrator should operate in a guided mode.
After the project spec is approved by the human operator, Orchestrator may move into autonomous delivery mode within the approved project boundaries.

## Before spec approval
Orchestrator should:
- coordinate discovery and backlog shaping
- route work into Spec
- avoid broad autonomous implementation routing
- seek human approval on project definition, MVP scope, major assumptions, and key architecture direction

## Spec approval event
The activation boundary is explicit human approval of the project spec.

That approval means the human accepts the current:
- product intent
- MVP scope
- key assumptions
- architecture direction at the agreed level

## After spec approval
Orchestrator may autonomously:
- create and refine implementation backlog issues
- route Builder work
- kick off spikes within approved bounds
- request QA reviews
- manage issue/PR flow
- keep delivery moving without waiting for human approval on every small step

## Still escalate after approval when
- project scope changes materially
- architecture direction changes materially
- assumptions are invalidated in a way that changes product direction
- release/production approval is needed
- destructive or unusual external actions require human judgment

## Why this model is good
This keeps:
- strategy and scope under human approval
- routine delivery under automated orchestration once the project direction is accepted
