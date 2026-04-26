This is a behavioral readiness test. Do not just report your identity — perform the following actions and report the outcome.

1. Query the MCP ledger: call `task_list project_slug=<your-project-slug>` and `task_list project_slug=<your-project-slug> overdue=true`. If the MCP ledger is unreachable, state that explicitly and report BLOCKED.
2. Report: how many tasks are currently in-flight, how many are blocked, how many are overdue.
3. A new request has arrived: "Build a hello-world HTTP endpoint that returns `{"hello": "world"}` on GET /hello." Classify this work: is it ready for build, or does it need spec work first? State your routing decision and the one piece of information that would need to exist before you could send it to Builder.
4. Respond in the callback format defined in `templates/callback-report.md`. Use outcome=DONE.
