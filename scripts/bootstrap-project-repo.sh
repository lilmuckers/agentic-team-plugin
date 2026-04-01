#!/usr/bin/env bash
set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required" >&2
  exit 1
fi

if [ $# -lt 1 ]; then
  cat >&2 <<'EOF'
Usage:
  scripts/bootstrap-project-repo.sh <owner/repo> [repo-path]

Examples:
  scripts/bootstrap-project-repo.sh PatrickMckinley/my-app ~/src/my-app
  scripts/bootstrap-project-repo.sh PatrickMckinley/my-app .
EOF
  exit 1
fi

REPO="$1"
REPO_PATH="${2:-.}"
WORKSPACE_ROOT="/data/.openclaw/workspace"
TEMPLATE_ROOT="$WORKSPACE_ROOT/repo-templates/.github"

if [ ! -d "$REPO_PATH" ]; then
  echo "Repo path does not exist: $REPO_PATH" >&2
  exit 1
fi

mkdir -p "$REPO_PATH/.github/ISSUE_TEMPLATE"
cp "$TEMPLATE_ROOT/ISSUE_TEMPLATE/spec-task.md" "$REPO_PATH/.github/ISSUE_TEMPLATE/spec-task.md"
cp "$TEMPLATE_ROOT/ISSUE_TEMPLATE/architecture-decision.md" "$REPO_PATH/.github/ISSUE_TEMPLATE/architecture-decision.md"
cp "$TEMPLATE_ROOT/ISSUE_TEMPLATE/bugfix-task.md" "$REPO_PATH/.github/ISSUE_TEMPLATE/bugfix-task.md"
cp "$TEMPLATE_ROOT/pull_request_template.md" "$REPO_PATH/.github/pull_request_template.md"

echo "Installed GitHub templates into $REPO_PATH/.github"

create_label() {
  local name="$1"
  local color="$2"
  local description="$3"
  gh label create "$name" --repo "$REPO" --color "$color" --description "$description" 2>/dev/null \
    || gh label edit "$name" --repo "$REPO" --color "$color" --description "$description" >/dev/null
}

create_label "spec-needed" "5319E7" "Issue requires specification or refinement before build"
create_label "architecture-needed" "1D76DB" "Architecture exploration or decision required"
create_label "ready-for-build" "0E8A16" "Issue is sufficiently specified and ready for Builder"
create_label "in-build" "FBCA04" "Implementation in progress"
create_label "in-review" "C2E0C6" "PR open or awaiting review"
create_label "needs-clarification" "D876E3" "Project-level ambiguity needs Spec input"
create_label "blocked" "B60205" "External or dependency blocker prevents progress"
create_label "done" "1A7F37" "Task completed"
create_label "needs-spec-review" "8B5CF6" "PR requires Spec review or clarifying decision"
create_label "needs-qa" "0052CC" "PR is ready for QA or code review"
create_label "changes-requested" "D93F0B" "Review identified required changes"
create_label "ready-to-merge" "0E8A16" "Review is complete and merge is appropriate"

echo "Created or updated standard labels in $REPO"
echo "Bootstrap complete. Next steps:"
echo "  1. Commit the copied .github templates in $REPO_PATH"
echo "  2. Create initial project docs/spec"
echo "  3. Create starter issues"
