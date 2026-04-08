# Git Safety Policy

## Rules
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
