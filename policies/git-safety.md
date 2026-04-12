# Git Safety Policy

## Rules
- Every agent session must work from its own dedicated local clone of the project repo, stored as a named subdirectory inside that agent's workspace directory (e.g. `workspace-builder-myproject/repo/`). The clone must be a subdirectory, never the workspace root itself — workspace files (framework config, agent identity, soul files, boot manifests) must not be inside the git working tree or they risk being committed into the project repo. Never share a checkout between concurrent agent sessions — different agents will be on different branches simultaneously and sharing one directory will cause branch conflicts and data loss. If the subdirectory clone does not yet exist, clone it before starting any git work.
- Prefer feature branches for all changes after initial bootstrap
- Keep commits scoped and reviewable
- Avoid mixing framework changes with unrelated workspace changes
- Do not force-push shared branches without explicit approval
- Treat `main` as protected by review intent, even if branch protection is not yet configured
- After every agent-made commit, immediately run `git push` if a remote is configured
- If a push is rejected, halt and surface the conflict to Orchestrator; do not self-resolve with rebases, force-pushes, or clever git surgery
- If no remote is configured, note that explicitly in the callback report or PR update

## Pull request expectations
- explain intent clearly
- summarize validation performed
- state known follow-ups
- flag risky or user-visible changes
