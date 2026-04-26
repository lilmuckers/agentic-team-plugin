"""
Shared fixtures and helpers for the task-ledger MCP integration tests.

Tests run against a live server. Set MCP_LEDGER_URL to override the default.
The server must be running before pytest is invoked (docker compose up -d).
"""
import json
import os
import uuid

import pytest
from mcp import ClientSession
from mcp.client.sse import sse_client

MCP_URL = os.getenv("MCP_LEDGER_URL", "http://localhost:8000")


# ---------------------------------------------------------------------------
# Error type
# ---------------------------------------------------------------------------


class ToolFailed(Exception):
    """Raised when a tool returns isError=true with a structured ToolError payload."""

    def __init__(self, code: str, message: str) -> None:
        self.code = code
        self.message = message
        super().__init__(f"[{code}] {message}")


# ---------------------------------------------------------------------------
# Low-level call helper
# ---------------------------------------------------------------------------


async def call(session: ClientSession, tool: str, **kwargs):
    """
    Call an MCP tool and return the parsed JSON result.

    Raises ToolFailed (with .code and .message) if isError=true and the
    content is a structured ToolError JSON payload.
    Raises AssertionError if isError=true but the content is not structured.
    """
    result = await session.call_tool(tool, arguments=kwargs)
    texts = [c.text for c in result.content if hasattr(c, "text")]
    text = texts[0] if texts else ""

    if result.isError:
        # FastMCP prepends "Error executing tool {name}: " before our JSON payload
        brace = text.find("{")
        if brace >= 0:
            try:
                payload = json.loads(text[brace:])
                if "error_code" in payload and "message" in payload:
                    raise ToolFailed(payload["error_code"], payload["message"])
            except json.JSONDecodeError:
                pass
        raise AssertionError(f"isError=true but not a structured ToolError: {text[:300]}")

    try:
        return json.loads(text)
    except json.JSONDecodeError:
        raise RuntimeError(f"Unexpected non-JSON tool response: {text[:300]}")


# ---------------------------------------------------------------------------
# Session fixture  (function scope — one SSE connection per test)
# ---------------------------------------------------------------------------


@pytest.fixture
async def mcp():
    """Open an MCP ClientSession over SSE for the duration of one test."""
    async with sse_client(f"{MCP_URL}/sse") as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            yield session


# ---------------------------------------------------------------------------
# Project fixture  (creates a unique project per test)
# ---------------------------------------------------------------------------


@pytest.fixture
async def project(mcp):
    """
    Create a disposable project with a unique slug.
    Yields a dict with project_id, project_token, project_slug, ledger_namespace.
    """
    slug = f"tp-{uuid.uuid4().hex[:8]}"
    data = await call(mcp, "project_create",
                      project_slug=slug, display_name=f"Test {slug}")
    yield data


# ---------------------------------------------------------------------------
# Task fixture  (creates a single task inside the project fixture)
# ---------------------------------------------------------------------------


@pytest.fixture
async def task(mcp, project):
    """
    Create a disposable task inside the project fixture.
    Yields a dict containing all task fields plus project_id and project_token
    so tests can call write operations without looking them up separately.
    """
    data = await call(
        mcp, "task_create",
        project_id=project["project_id"],
        project_token=project["project_token"],
        kind="bug",
        title="Fixture task",
        state="new",
        priority="medium",
        owner_agent_type="orchestrator",
        owner_agent_id=f"orchestrator-{project['project_slug']}",
    )
    yield {
        **data,
        "project_id": project["project_id"],
        "project_token": project["project_token"],
        "project_slug": project["project_slug"],
    }
