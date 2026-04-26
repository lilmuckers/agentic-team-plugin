# Task Ledger MCP — Practical Access Reference

## What the tool call syntax in docs actually means

Throughout the framework docs, MCP operations are written in shorthand form:

```
task_list project_slug=<slug> overdue=true
task_transition task_id=<uuid> to_state=building ...
```

These are **MCP tool invocations** — not shell commands and not API calls the agent constructs manually. When an agent calls `task_list`, it is invoking the `task_list` tool registered on the MCP server that has been configured for its session. The agent calls the tool by name with its arguments; the runtime handles the transport.

This document explains the framework-side contract for making that work.

---

## Runtime context

Named agents in this framework run under **OpenClaw**. OpenClaw manages agent sessions, named-agent identity, dispatch, and the tool surface each agent session has access to. MCP server registration for a named-agent session is an OpenClaw configuration concern — consult the OpenClaw documentation for the exact mechanism to provision a named agent with access to an SSE MCP server.

The framework's responsibility is:

1. Running the MCP server so it is reachable from the agent host
2. Recording the server URL in the agent workspace bootstrap files so agents know where to reach it
3. Storing the `project_token` in the Orchestrator workspace
4. Defining the per-task token-delegation model for narrow writes

---

## The MCP server

The task-ledger MCP server uses SSE transport:

- **SSE endpoint:** `http://<host>:8000/sse`
- **Health check:** `GET http://<host>:8000/health` → `{"status":"ok","database":"ok"}`
- **Source:** `server/mcp_ledger/`
- **Docker Compose:** `server/docker-compose.yml`

The server is deployed alongside Postgres via Docker Compose. The `HOST` and `PORT` environment variables control the bind address (defaults: `0.0.0.0`, `8000`).

Confirm the server is reachable before expecting tool calls to succeed:

```bash
curl http://<host>:8000/health
```

A `200` response with `"database":"ok"` means the server and Postgres are both healthy.

---

## Recording the server URL in agent workspaces

The server URL should be written into the agent workspace bootstrap files so each named agent can read it at session start without relying on session memory. The framework deployment scripts (`scripts/deploy-project-agent-workspaces.py`, `scripts/deploy-named-agents.py`) are the appropriate place to write this configuration when generating managed workspace files.

See `docs/delivery/managed-workspace-files.md` for the list of bootstrap files managed per workspace and `docs/delivery/workspace-bootstrap-deployment.md` for the reload model.

---

## Where the project_token is stored

The `project_token` is generated once at `project_create` and is the write secret for a project.

**Orchestrator workspace only.** Store it in the Orchestrator's named-agent workspace bootstrap config — for example as a dedicated entry in a project config file that the agent reads at session start. It must never be committed to the project repo or propagated to other agents as standing configuration.

Other agents only receive the `project_token` when Orchestrator explicitly includes it in a task packet for a specific write operation. This is a per-task grant. See `skills/task-ledger-mcp/SKILL.md` for the full authority model.

---

## What happens when the server is unreachable

If a tool call fails because the MCP server is not reachable:

1. **Do not continue the task** as if the write succeeded.
2. **Do not fall back to writing state into markdown files.**
3. Report `BLOCKED` with reason `mcp-unavailable` to whoever dispatched the work.
4. When the server is confirmed reachable again, call `task_get` to re-read current state before resuming — do not assume the state last observed is still current.

---

## Session startup checklist for Orchestrator

On each session start, before taking new work:

1. Confirm the MCP server is reachable via the health check.
2. Query open tasks: `task_list project_slug=<slug>`
3. Query overdue tasks: `task_list project_slug=<slug> overdue=true`
4. Query blocked tasks: `task_list project_slug=<slug> state=blocked`
5. Surface any items needing attention before acting on new requests.

If step 1 fails, report the outage and halt until the server is available.

---

## Read-only access for non-Orchestrator agents

Non-Orchestrator agents do not need the `project_token` to read task state. With the MCP server accessible in their session, they call the read-only tools directly:

| Tool | What it returns |
|---|---|
| `task_get task_id=<uuid>` | Full task record |
| `task_list project_slug=<slug>` | Tasks matching filters |
| `task_history task_id=<uuid>` | Events, notes, and artifacts for a task |
| `project_get project_slug=<slug>` | Project metadata (no token returned) |
| `project_list` | All known projects (no tokens returned) |

---

## Reference

- Operating model: `docs/delivery/task-mcp-operating-model.md`
- Skill (authority and error handling): `skills/task-ledger-mcp/SKILL.md`
- Full tool reference: `server/mcp_ledger/README.md`
- Managed workspace files: `docs/delivery/managed-workspace-files.md`
