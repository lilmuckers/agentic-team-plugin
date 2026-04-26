"""Tests for project_create, project_get, project_list, project_rotate_token."""
import re
import uuid

import pytest

from .conftest import MCP_URL, ToolFailed, call

pytestmark = pytest.mark.anyio

# ---------------------------------------------------------------------------
# project_create
# ---------------------------------------------------------------------------


async def test_project_create_returns_required_fields(mcp):
    slug = f"tp-{uuid.uuid4().hex[:8]}"
    result = await call(mcp, "project_create", project_slug=slug, display_name="Test")
    assert "project_id" in result
    assert "project_slug" in result
    assert "ledger_namespace" in result
    assert "project_token" in result
    assert "created_at" in result


async def test_project_create_slug_matches_input(mcp):
    slug = f"tp-{uuid.uuid4().hex[:8]}"
    result = await call(mcp, "project_create", project_slug=slug, display_name="Test")
    assert result["project_slug"] == slug


async def test_project_create_token_is_64_hex_chars(mcp):
    slug = f"tp-{uuid.uuid4().hex[:8]}"
    result = await call(mcp, "project_create", project_slug=slug, display_name="Test")
    token = result["project_token"]
    assert len(token) == 64
    assert re.fullmatch(r"[0-9a-f]{64}", token)


async def test_project_create_id_is_uuid(mcp):
    slug = f"tp-{uuid.uuid4().hex[:8]}"
    result = await call(mcp, "project_create", project_slug=slug, display_name="Test")
    uuid.UUID(result["project_id"])  # raises if invalid


async def test_project_create_namespace_contains_slug(mcp):
    slug = f"tp-{uuid.uuid4().hex[:8]}"
    result = await call(mcp, "project_create", project_slug=slug, display_name="Test")
    assert slug in result["ledger_namespace"]


async def test_project_create_duplicate_slug_raises_duplicate_slug(mcp, project):
    with pytest.raises(ToolFailed) as exc:
        await call(mcp, "project_create",
                   project_slug=project["project_slug"], display_name="Dup")
    assert exc.value.code == "duplicate_slug"


# ---------------------------------------------------------------------------
# project_get
# ---------------------------------------------------------------------------


async def test_project_get_by_slug(mcp, project):
    result = await call(mcp, "project_get", project_slug=project["project_slug"])
    assert result["project_id"] == project["project_id"]
    assert result["project_slug"] == project["project_slug"]


async def test_project_get_by_id(mcp, project):
    result = await call(mcp, "project_get", project_id=project["project_id"])
    assert result["project_slug"] == project["project_slug"]


async def test_project_get_never_exposes_token(mcp, project):
    result = await call(mcp, "project_get", project_slug=project["project_slug"])
    assert "project_token" not in result
    assert "project_token_hash" not in result


async def test_project_get_not_found_raises_project_not_found(mcp):
    with pytest.raises(ToolFailed) as exc:
        await call(mcp, "project_get", project_id=str(uuid.uuid4()))
    assert exc.value.code == "project_not_found"


async def test_project_get_unknown_slug_raises_project_not_found(mcp):
    with pytest.raises(ToolFailed) as exc:
        await call(mcp, "project_get", project_slug="does-not-exist")
    assert exc.value.code == "project_not_found"


async def test_project_get_no_args_raises_validation_error(mcp):
    with pytest.raises(ToolFailed) as exc:
        await call(mcp, "project_get")
    assert exc.value.code == "validation_error"


# ---------------------------------------------------------------------------
# project_list
# ---------------------------------------------------------------------------


async def test_project_list_returns_list(mcp, project):
    result = await call(mcp, "project_list")
    assert isinstance(result, list)


async def test_project_list_contains_created_project(mcp, project):
    result = await call(mcp, "project_list")
    ids = [p["project_id"] for p in result]
    assert project["project_id"] in ids


async def test_project_list_never_exposes_tokens(mcp, project):
    result = await call(mcp, "project_list")
    for p in result:
        assert "project_token" not in p
        assert "project_token_hash" not in p


# ---------------------------------------------------------------------------
# project_rotate_token
# ---------------------------------------------------------------------------


async def test_project_rotate_token_returns_new_token(mcp, project):
    result = await call(mcp, "project_rotate_token",
                        project_id=project["project_id"],
                        project_token=project["project_token"])
    assert "project_token" in result
    assert result["project_token"] != project["project_token"]


async def test_project_rotate_token_new_token_is_64_hex(mcp, project):
    result = await call(mcp, "project_rotate_token",
                        project_id=project["project_id"],
                        project_token=project["project_token"])
    assert len(result["project_token"]) == 64
    assert re.fullmatch(r"[0-9a-f]{64}", result["project_token"])


async def test_project_rotate_token_old_token_rejected_after_rotation(mcp, project):
    old_token = project["project_token"]
    await call(mcp, "project_rotate_token",
               project_id=project["project_id"],
               project_token=old_token)
    with pytest.raises(ToolFailed) as exc:
        await call(mcp, "project_rotate_token",
                   project_id=project["project_id"],
                   project_token=old_token)
    assert exc.value.code == "invalid_token"


async def test_project_rotate_token_wrong_token_raises_invalid_token(mcp, project):
    with pytest.raises(ToolFailed) as exc:
        await call(mcp, "project_rotate_token",
                   project_id=project["project_id"],
                   project_token="dead" * 16)
    assert exc.value.code == "invalid_token"


async def test_project_rotate_token_unknown_project_raises_project_not_found(mcp):
    with pytest.raises(ToolFailed) as exc:
        await call(mcp, "project_rotate_token",
                   project_id=str(uuid.uuid4()),
                   project_token="dead" * 16)
    assert exc.value.code == "project_not_found"
