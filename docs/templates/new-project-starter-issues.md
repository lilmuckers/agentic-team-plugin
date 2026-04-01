# New Project Starter Issues

Use this as a guide for the first issues created in a new project repo.

## 1. Project specification issue

Purpose:
- define the project clearly
- establish scope and non-goals
- surface assumptions

Suggested output:
- initial spec doc/wiki page
- clarified acceptance framing for early work

## 2. Architecture exploration issue

Create only if the project has meaningful design uncertainty.

Purpose:
- explore architecture choices
- capture tradeoffs
- inform early decomposition

Suggested output:
- architecture note
- decision recommendation
- follow-up work implications

## 3. First implementation slice

Purpose:
- create the first genuinely buildable unit of delivery
- prove the workflow works on a small slice

Properties:
- narrow scope
- explicit acceptance criteria
- minimal hidden assumptions

## 4. Tooling / environment setup issue

Create only if project bootstrapping work is needed.

Examples:
- CI setup
- formatting/linting
- base framework scaffolding
- test harness setup

## 5. Documentation baseline issue

Purpose:
- ensure essential docs exist early
- prevent code racing ahead of shared understanding

Examples:
- developer setup docs
- architecture overview placeholder
- domain glossary

## Rule of thumb

The first issues should make the project more legible and more buildable.
They should not attempt to represent the entire roadmap in one dramatic heap.
