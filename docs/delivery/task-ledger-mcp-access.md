# Task Ledger MCP — Practical Access Reference

## What the tool call syntax in docs actually means

Throughout the framework docs, MCP operations are written in shorthand form:

```
task_list project_slug=<slug> overdue=true
task_transition task_id=<uuid> to_state=building ...
```

These are **MCP tool invocations** — not shell commands, not Python calls, not API requests. When an agent calls `task_list`, it is invoking the `task_list` tool registered on the configured MCP server. Claude Code handles the SSE protocol and JSON-RPC framing automatically. The agent simply calls the tool by name with its arguments.

This document explains the concrete path from "configured workspace" to "working tool call."

---

## How named agents connect to the MCP server

The task-ledger MCP server uses SSE transport. It must be declared as an MCP server in the agent's Claude Code configuration before tool calls will work.

### Configuration location

Each named-agent workspace has a `.claude/settings.json` file managed by the framework deployment. Add the `mcpServers` entry there:

```json
{
  "mcpServers": {
    "task-ledger": {
      "type": "sse",
      "url": "http://<host>:8000/sse"
    }
  }
}
```

Replace `<host>` with the hostname or IP where the MCP server is running. In the standard Docker Compose deployment this is the host running `server/docker-compose.yml`. The port is `8000` by default (set via the `PORT` environment variable on the `mcp_ledger` service).

### Where the URL comes from

The server URL should be stored in the agent workspace bootstrap config (e.g. as a line in `AGENTS.md` or a dedicated `MCP_CONFIG.md` loaded at session start) so the agent can reference it without relying on session memory.

The framework deployment scripts (`scripts/deploy-project-agent-workspaces.py`, `scripts/deploy-named-agents.py`) are the appropriate place to write this configuration when generating managed workspace files. See `docs/delivery/managed-workspace-files.md`.

### Verifying the server is reachable

Before expecting tool calls to succeed, confirm the server is up:

```bash
curl http://<host>:8000/health
# {"status":"ok","database":"ok"}
```

A `200` response with `"database":"ok"` means the server is up and Postgres is reachable. Any other response means the server is not ready — tool calls will fail.

---

## Where the project_token is stored

The `project_token` is generated once at `project_create` and is the write secret for a project.

**Orchestrator workspace only.** Store it in a file in the Orchestrator's named-agent workspace — for example `workspace-orchestrator/.env` or a dedicated `PROJECT_CONFIG.md` that the agent reads at session start. It must never be committed to the project repo or passed to other agents as a standing configuration.

Other agents only receive the `project_token` when Orchestrator explicitly includes it in a task packet for a specific write operation. This is a per-task grant. See `skills/task-ledger-mcp/SKILL.md` for the authority model.

---

## What happens when the server is unreachable

If a tool call fails because the MCP server is not configured or not reachable:

1. **Do not attempt to continue the task** as if the write succeeded.
2. **Do not fall back to writing state into markdown files.**
3. Report `BLOCKED` with reason `mcp-unavailable` to whoever dispatched the work.
4. When the server is confirmed reachable again, re-read current task state with `task_get` before resuming — do not assume the state you last observed is still current.

---

## Session startup checklist for Orchestrator

On each session start, before taking new work:

1. Confirm the MCP server is reachable: `GET /health`
2. Query open tasks: `task_list project_slug=<slug>`
3. Query overdue tasks: `task_list project_slug=<slug> overdue=true`
4. Query blocked tasks: `task_list project_slug=<slug> state=blocked`
5. Surface any items needing attention before acting on new requests.

If step 1 fails, report the outage and halt until the server is available.

---

## Read-only access for non-Orchestrator agents

Non-Orchestrator agents do not need the `project_token` to read task state. With the MCP server configured in their workspace `.claude/settings.json`, they can call the read-only tools directly:

| Tool | What it returns |
|---|---|
| `task_get task_id=<uuid>` | Full task record |
| `task_list project_slug=<slug>` | Tasks matching filters |
| `task_history task_id=<uuid>` | Events, notes, and artifacts for a task |
| `project_get project_slug=<slug>` | Project metadata (no token returned) |
| `project_list` | All known projects (no tokens returned) |

The MCP server URL must be the same for all agents in a project. Typically this is a shared service address in the deployment environment.

---

## Reference

- MCP server source: `server/mcp_ledger/`
- Full tool reference with all parameters: `server/mcp_ledger/README.md`
- Operating model: `docs/delivery/task-mcp-operating-model.md`
- Skill (authority and error handling): `skills/task-ledger-mcp/SKILL.md`
- Docker Compose: `server/docker-compose.yml`
