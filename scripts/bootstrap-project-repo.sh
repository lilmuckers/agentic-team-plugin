#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT_DIR/scripts/lib/config.sh"
load_framework_config

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required" >&2
  exit 1
fi

if [ $# -lt 1 ]; then
  cat >&2 <<'EOF'
Usage:
  scripts/bootstrap-project-repo.sh <owner/repo> [repo-path]

Examples:
  scripts/bootstrap-project-repo.sh my-org/my-app ~/src/my-app
  scripts/bootstrap-project-repo.sh my-org/my-app .
EOF
  exit 1
fi

REPO="$1"
REPO_PATH="${2:-.}"
WORKSPACE_ROOT="$ROOT_DIR"
TEMPLATE_ROOT="$WORKSPACE_ROOT/repo-templates/.github"

if [ ! -d "$REPO_PATH" ]; then
  echo "Repo path does not exist: $REPO_PATH" >&2
  exit 1
fi

mkdir -p "$REPO_PATH/.github/ISSUE_TEMPLATE"
cp "$TEMPLATE_ROOT/ISSUE_TEMPLATE/spec-task.md" "$REPO_PATH/.github/ISSUE_TEMPLATE/spec-task.md"
cp "$TEMPLATE_ROOT/ISSUE_TEMPLATE/architecture-decision.md" "$REPO_PATH/.github/ISSUE_TEMPLATE/architecture-decision.md"
cp "$TEMPLATE_ROOT/ISSUE_TEMPLATE/bugfix-task.md" "$REPO_PATH/.github/ISSUE_TEMPLATE/bugfix-task.md"
cp "$TEMPLATE_ROOT/ISSUE_TEMPLATE/release-tracking.md" "$REPO_PATH/.github/ISSUE_TEMPLATE/release-tracking.md"
cp "$TEMPLATE_ROOT/ISSUE_TEMPLATE/spec-approval.md" "$REPO_PATH/.github/ISSUE_TEMPLATE/spec-approval.md"
cp "$TEMPLATE_ROOT/pull_request_template.md" "$REPO_PATH/.github/pull_request_template.md"
mkdir -p "$REPO_PATH/.github/workflows"
cp "$TEMPLATE_ROOT/workflows/merge-gate.yml" "$REPO_PATH/.github/workflows/merge-gate.yml"
cp "$WORKSPACE_ROOT/repo-templates/SPEC.md" "$REPO_PATH/SPEC.md"
mkdir -p "$REPO_PATH/docs/delivery"
cp "$WORKSPACE_ROOT/repo-templates/docs/delivery/release-state.md" "$REPO_PATH/docs/delivery/release-state.md"
cp "$WORKSPACE_ROOT/repo-templates/docs/delivery/task-ledger.md" "$REPO_PATH/docs/delivery/task-ledger.md"

echo "Installed GitHub templates, SPEC.md, and delivery scaffolding into $REPO_PATH"
"$WORKSPACE_ROOT/scripts/validate-project-bootstrap.sh" "$REPO_PATH" >/dev/null

create_label() {
  local name="$1"
  local color="$2"
  local description="$3"
  gh label create "$name" --repo "$REPO" --color "$color" --description "$description" 2>/dev/null \
    || gh label edit "$name" --repo "$REPO" --color "$color" --description "$description" >/dev/null
}

create_label "feature" "0E8A16" "High-level issue type: new capability or user-facing functionality"
create_label "bug" "B60205" "High-level issue type: defect or broken behavior"
create_label "change" "1D76DB" "High-level issue type: non-trivial change that is not best described as a feature or bug"
create_label "chore" "6E7781" "High-level issue type: maintenance or operational work"
create_label "docs" "5319E7" "High-level issue type: documentation-focused work"
create_label "investigation" "FBCA04" "High-level issue type: discovery, diagnosis, or exploration"
create_label "spike" "C5DEF5" "High-level issue type: bounded feasibility experiment to inform next steps"
create_label "spec-needed" "8B5CF6" "Issue requires specification or refinement before build"
create_label "architecture-needed" "1D76DB" "Architecture exploration or decision required"
create_label "ready-for-build" "0E8A16" "Issue is sufficiently specified and ready for Builder"
create_label "in-build" "FBCA04" "Implementation in progress"
create_label "in-review" "C2E0C6" "PR open or awaiting review"
create_label "needs-clarification" "D876E3" "Project-level ambiguity needs Spec input"
create_label "blocked" "B60205" "External or dependency blocker prevents progress"
create_label "done" "1A7F37" "Task completed"
create_label "security-scope" "B60205" "Issue or PR touches security-sensitive scope and requires Security participation"
create_label "security-review-required" "D93F0B" "PR is awaiting formal Security review before QA or merge"
create_label "release-tracking" "5319E7" "Release coordination issue owned by Release Manager"
create_label "needs-spec-review" "8B5CF6" "PR requires Spec review or clarifying decision"
create_label "needs-qa" "0052CC" "PR is ready for QA or code review"
create_label "changes-requested" "D93F0B" "Review identified required changes"
create_label "ready-to-merge" "0E8A16" "Review is complete and merge is appropriate"
create_label "qa-approved" "0E8A16" "QA has completed review and approved the PR"
create_label "spec-satisfied" "1D76DB" "Spec confirms project-level assumptions, docs, and intent are satisfied"
create_label "orchestrator-approved" "5319E7" "Orchestrator confirms merge-gate conditions are met and merge is appropriate now"
create_label "security-approved" "B60205" "Security confirms security-scope requirements are satisfied"
create_label "spec-approval" "FBCA04" "Spec-approval gate: Orchestrator stays in guided mode until this issue is closed by the human operator"

echo "Created or updated standard labels in $REPO"

# ── spec-approval gate issue ───────────────────────────────────────────────────
# Create the spec-approval gate issue if one does not already exist.
# Orchestrator requires this issue to exist (open or closed) — absence is a
# misconfiguration, not implicit approval.

EXISTING_SPEC_APPROVAL=$(gh issue list --repo "$REPO" --label spec-approval --state all --json number --jq '.[0].number' 2>/dev/null || true)
if [ -n "$EXISTING_SPEC_APPROVAL" ]; then
  echo "spec-approval gate issue already exists: #$EXISTING_SPEC_APPROVAL (skipping creation)"
else
  REPO_NAME="$(basename "$REPO")"
  SPEC_APPROVAL_NUMBER=$(gh issue create \
    --repo "$REPO" \
    --title "spec-approval: $REPO_NAME" \
    --label "spec-approval" \
    --body "$(cat <<'ISSUE_BODY'
## Purpose

This issue is the spec-approval gate for this project.

While this issue is **open**, the Orchestrator operates in **guided mode**:
- work may be dispatched to Spec and Builder
- but merge and release decisions require human confirmation

When the human operator closes this issue, the Orchestrator may proceed in **autonomous delivery mode**.

## Spec approval checklist

- [ ] \`SPEC.md\` reflects the agreed project definition
- [ ] wiki pages are created and linked
- [ ] initial backlog issues are created and scoped
- [ ] acceptance criteria are visible and buildable
- [ ] Orchestrator has been briefed on the approved delivery scope

## Instructions for the operator

Close this issue when you are satisfied that:
1. the project spec is correct
2. the initial issues are ready to build
3. the swarm is correctly configured

Do not close this issue to unblock a stuck run — only close it when spec-level approval has genuinely been given.
ISSUE_BODY
)" \
    --json number --jq '.number')
  echo "Created spec-approval gate issue: #$SPEC_APPROVAL_NUMBER"
  echo "IMPORTANT: Orchestrator will stay in guided mode until you close issue #$SPEC_APPROVAL_NUMBER"
fi

echo ""
echo "Bootstrap complete. Next steps:"
echo "  1. Commit the copied .github templates in $REPO_PATH"
echo "  2. Confirm branch protection requires .github/workflows/merge-gate.yml in $REPO"
echo "  3. Review and close the spec-approval gate issue (#${SPEC_APPROVAL_NUMBER:-$EXISTING_SPEC_APPROVAL}) when the project spec is approved"
echo "  4. Create initial project docs/spec"
echo "  5. For application repos, add docker-compose.yml and .devcontainer/devcontainer.json"
echo "  6. Create starter issues"
echo "  7. Configure per-agent git identities with scripts/set-agent-git-identity.sh as needed"
