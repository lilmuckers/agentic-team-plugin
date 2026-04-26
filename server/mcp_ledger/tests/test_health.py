"""Tests for the /health HTTP endpoint."""
import urllib.request
import json
import pytest

from .conftest import MCP_URL


def test_health_returns_200():
    with urllib.request.urlopen(f"{MCP_URL}/health", timeout=5) as r:
        assert r.status == 200


def test_health_status_ok():
    with urllib.request.urlopen(f"{MCP_URL}/health", timeout=5) as r:
        body = json.loads(r.read())
    assert body["status"] == "ok"


def test_health_database_ok():
    with urllib.request.urlopen(f"{MCP_URL}/health", timeout=5) as r:
        body = json.loads(r.read())
    assert body["database"] == "ok"


def test_health_response_is_json():
    with urllib.request.urlopen(f"{MCP_URL}/health", timeout=5) as r:
        content_type = r.headers.get("content-type", "")
        body = r.read()
    assert "application/json" in content_type
    json.loads(body)  # must not raise
