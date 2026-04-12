# agentic-team-plugin

Versioned framework for a reusable agentic delivery team: orchestrator, spec, security, release manager, builder, QA, shared skills, workflows, policies, and deployment sync mechanics.

## Purpose

This repository is the source of truth for the delivery-team framework. It defines:

- reusable agent roles and workspace bootstrap files
- reusable skills for software delivery workflows
- workflow contracts, policies, and governance rules
- a dev → review → deploy promotion model for the framework itself
- onboarding tooling to commission a new project under the team

## Prerequisites

| Tool | Purpose |
|------|---------|
| [OpenClaw](https://openclaw.ai) | Agent runtime — named agents and cron |
| `git` | Version control |
| `gh` | GitHub CLI — PR/issue/label management |
| `python3` | Config loaders and deploy scripts |
| `yq` | YAML parsing in shell scripts |
| `docker` + `docker compose` | Local dev environments for downstream projects |
| `rsync` (optional) | Framework sync; falls back to `scripts/sync-tree.py` |

---

## 1. Setup

### 1.1 Clone the framework

```bash
git clone <your-framework-repo-url> agentic-team-plugin
cd agentic-team-plugin
```

### 1.2 Create your operator config

```bash
cp config/framework.yaml.example config/framework.yaml
```

Edit `config/framework.yaml`:

```yaml
operator:
  name: "Your Name"          # used in workspace boot files and git identity
  callname: "YourCallname"   # short handle agents use when addressing you
  email_domain: "example.com" # bot git commits use bot-<archetype>@<domain>
  timezone: "Europe/London"  # agent schedules and timestamps

openclaw:
  workspace_root: "/data/.openclaw"  # OpenClaw workspace directory

agent_personas:
  orchestrator: "Cohen"      # optional — name the agents as you like
  spec: "Marlowe"
  builder: "Reeves"
  qa: "Quinn"
  security: "Vesper"
  release_manager: "Sterling"
```

`config/framework.yaml` is gitignored. Never commit it. The example file is the committed template.

### 1.3 Validate the config

```bash
scripts/validate-config.sh
```

This confirms all required fields are present and well-formed before any other script runs.

### 1.4 Validate the full framework

```bash
scripts/validate-framework.sh
```

Checks that all expected agent role docs, skills, workflows, policies, schemas, and deploy artifacts are present.

---

## 2. Getting it running

### 2.1 Deploy the framework to OpenClaw

From the `main` branch only (the deploy script enforces this):

```bash
deploy/sync-framework.sh
```

This:
1. Validates the working copy (`scripts/validate-framework.sh`)
2. Syncs managed framework files to `.active/framework/`
3. Validates the active copy
4. Generates archetype runtime bundles (`.runtime/`)
5. Deploys named-agent config under `$openclaw.workspace_root/agents/`
6. Deploys workspace bootstrap files for all six archetypes
7. Records the deployed SHA and timestamp to `.state/framework/`

After this runs, the six archetype workspaces (`workspace-orchestrator`, `workspace-spec`, `workspace-security`, `workspace-release-manager`, `workspace-builder`, `workspace-qa`) are populated under your OpenClaw workspace root.

### 2.2 Set up the OpenClaw watchdog cron

Register a native OpenClaw cron job to keep persistent agents ticking:

```
openclaw cron add --schedule "*/30 * * * *" \
  --agent orchestrator \
  --message "Heartbeat: review the task ledger and update current_action if anything has changed."
```

Repeat for `spec`, `security`, and `release-manager`. Builder and QA are ephemeral — they are spawned per task, not scheduled.

The 30-minute cadence is the recommended baseline. Adjust per project load.

### 2.3 Session topology

| Archetype | Session type | Lifecycle |
|-----------|-------------|-----------|
| `orchestrator-<project>` | Persistent | Lives for the project duration; owns the task ledger |
| `spec-<project>` | Persistent | Lives for the project duration; owns SPEC.md |
| `security-<project>` | Persistent | Lives for the project duration; three touch points |
| `release-manager-<project>` | Persistent | Lives for the project duration; owns release-state.md |
| `builder-<project>` | Ephemeral | Spawned per task, exits on completion |
| `qa-<project>` | Ephemeral | Spawned per review, exits on completion |

Persistent agents are invoked with a stable session ID to give them routing identity. The task ledger (`docs/delivery/task-ledger.md` in the project repo) is the sole persistence mechanism — not session memory.

---

## 3. Commissioning a new project

### 3.1 Prepare a project repo

Create your project repo (GitHub recommended) and clone it locally. It can be empty at this point.

```bash
git clone git@github.com:your-org/your-project.git
cd your-project
```

> **Important — separate checkouts per agent.** Each agent must work from its own dedicated local clone of the project repo, stored inside its workspace directory. Never let two agent sessions share a checkout: Builder may be on a feature branch while QA is on `main` simultaneously, and sharing one directory will cause branch conflicts and data loss. Each agent clones the repo into its workspace on first use.

### 3.2 Run project onboarding

From the framework directory:

```bash
scripts/onboard-project.sh <project-slug> <path-to-project-repo>
```

Example:

```bash
scripts/onboard-project.sh musical-statues ../musical-statues
```

This will:
- Create six project-scoped named agents in OpenClaw: `orchestrator-musical-statues`, `spec-musical-statues`, etc.
- Deploy project-specific workspace files to each agent's workspace
- Install repo templates into the project repo: `SPEC.md`, `docs/delivery/release-state.md`, `.github/workflows/merge-gate.yml`, PR template, and issue templates
- Set the repo-local git identity to the Orchestrator persona

To also bootstrap GitHub labels, branch protections, and wikis in one step:

```bash
GITHUB_REPO=your-org/your-project \
  scripts/onboard-project.sh musical-statues ../musical-statues --with-github-setup
```

Use `--dry-run` to preview what would happen without making changes.

After onboarding completes, the script automatically runs a swarm smoke test. Each of the six agents is sent a startup verification message and asked to report their name, purpose, what they are ready to do, and any gaps in their configuration. Review each response to confirm they are correctly wired before starting work. If any agent fails or reports a missing prerequisite, investigate before proceeding.

You can re-run the smoke test at any time:

```bash
scripts/smoke-test-agent-swarm.sh <project-slug>
# or a subset
scripts/smoke-test-agent-swarm.sh musical-statues --agents orchestrator,spec
```

### 3.3 Agree the starting version

Open `docs/delivery/release-state.md` in the project repo and set the initial version entry. The Release Manager and Orchestrator must agree on the starting version (typically `0.1.0-beta1`) before any build work begins.

### 3.4 Start the first spec conversation

Invoke the project Spec agent directly and begin describing what you want to build:

```bash
scripts/invoke-named-agent.sh musical-statues spec spec-kickoff.md
```

Where `spec-kickoff.md` contains your initial brief. The Spec agent will run a conversational session with you to work out the full `SPEC.md` — requirements, architecture decisions, acceptance criteria, and test strategy — before any Builder work begins.

Once `SPEC.md` is drafted, the Orchestrator reviews it and breaks it into tasks in the task ledger.

---

## 4. Day-to-day operation

### Invoking agents

```bash
# General form
scripts/invoke-named-agent.sh <project> <agent> <message-file> [task-suffix] [thinking] [verbose]

# Examples
scripts/invoke-named-agent.sh musical-statues orchestrator orchestrator.md
scripts/invoke-named-agent.sh musical-statues builder issue-2.md issue-2 low on
```

### Task ledger

The Orchestrator maintains `docs/delivery/task-ledger.md` in the project repo. Each task entry is a markdown section with an embedded JSON payload covering: `task`, `state`, `current_action`, `next_action`, and a `history` array. All state transitions are committed to git so the full delivery history is auditable.

### Merge gate

PRs require three labels before merge: `qa-approved`, `spec-satisfied`, `orchestrator-approved`. PRs touching security-relevant paths also require `security-approved`. The merge gate workflow is installed at `.github/workflows/merge-gate.yml` during onboarding.

### Releases

The Release Manager drives the full release cycle:

```bash
# Tag and create a GitHub release
scripts/cut-release-tag.sh <project-repo> <version>  # e.g. 0.1.0-beta1

# Check open issues for a release
scripts/check-release-issues.sh <project-repo> <version>

# Generate release notes
scripts/generate-release-notes.sh <project-repo> <version>
```

Release versions follow SemVer with the flow: `beta1 → betaN → rc1 → rcN → final`. Scale (major/minor/patch) is determined by Spec and Orchestrator; the Release Manager applies it mechanically.

---

## Layout

```
agents/         role definitions for the six archetypes + specialist templates
skills/         reusable skills the team can invoke
workflows/      multi-agent workflow definitions
policies/       governance and safety rules
templates/      reusable text artifacts (decision records, bug reports)
schemas/        shared JSON schemas
deploy/         sync/deploy rules and scripts
repo-templates/ downstream project GitHub templates
scripts/        all helper scripts
docs/           design notes, agent reference docs, operating models
tests/          validation fixtures and examples
config/         framework.yaml.example (live config is gitignored)
```

## Repo boundary

Included intentionally:
- delivery agent role definitions
- reusable skills and templates
- delivery architecture and operating-model docs
- repo-management policy and operating model
- project bootstrap assets for downstream repos
- deployment manifests and sync tooling

Excluded intentionally:
- `config/framework.yaml` (operator-specific, gitignored)
- local OpenClaw runtime metadata
- agent personal memory and chat continuity files (`SOUL.md`, `IDENTITY.md`, `USER.md`, `MEMORY.md`, `AGENTS.md`, `TOOLS.md`, `HEARTBEAT.md`)

## Operating model

- `main` is the approved framework baseline.
- All changes use feature branches + pull requests.
- The active deployment copy is promoted from reviewed commits on `main` via `deploy/sync-framework.sh`.
- Downstream projects are onboarded per-project with `scripts/onboard-project.sh`.
