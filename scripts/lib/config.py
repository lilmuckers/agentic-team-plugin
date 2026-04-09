#!/usr/bin/env python3
from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any


class ConfigError(RuntimeError):
    pass


@dataclass(frozen=True)
class FrameworkConfig:
    operator_name: str
    operator_callname: str
    operator_email_domain: str
    operator_timezone: str
    workspace_root: str
    agent_personas: dict[str, str]
    path: Path

    def persona_for(self, archetype: str) -> str:
        key = archetype.strip().lower().replace("-", "_")
        return self.agent_personas.get(key) or archetype


REQUIRED_FIELDS = {
    "operator.name": "operator_name",
    "operator.callname": "operator_callname",
    "operator.email_domain": "operator_email_domain",
    "operator.timezone": "operator_timezone",
    "openclaw.workspace_root": "workspace_root",
}


def _strip_quotes(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
        return value[1:-1]
    return value


def _parse_simple_yaml(path: Path) -> dict[str, Any]:
    root: dict[str, Any] = {}
    stack: list[tuple[int, dict[str, Any]]] = [(-1, root)]

    for line_number, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if not raw_line.strip() or raw_line.lstrip().startswith("#"):
            continue
        indent = len(raw_line) - len(raw_line.lstrip(" "))
        if indent % 2 != 0:
            raise ConfigError(f"{path}: line {line_number}: indentation must use multiples of two spaces")
        stripped = raw_line.strip()
        if ":" not in stripped:
            raise ConfigError(f"{path}: line {line_number}: expected 'key: value' mapping")
        key, value = stripped.split(":", 1)
        key = key.strip()
        value = value.strip()

        while stack and indent <= stack[-1][0]:
            stack.pop()
        if not stack:
            raise ConfigError(f"{path}: line {line_number}: invalid indentation structure")
        current = stack[-1][1]

        if not value:
            child: dict[str, Any] = {}
            current[key] = child
            stack.append((indent, child))
        else:
            current[key] = _strip_quotes(value)

    return root


def load_config(config_path: str | Path | None = None, *, require_live: bool = True) -> FrameworkConfig:
    root = Path(__file__).resolve().parents[2]
    path = Path(config_path or os.environ.get("FRAMEWORK_CONFIG") or root / "config" / "framework.yaml")
    if not path.exists():
        raise ConfigError(f"config file not found: {path}")

    payload = _parse_simple_yaml(path)

    values: dict[str, str] = {}
    for dotted, attr in REQUIRED_FIELDS.items():
        cursor: Any = payload
        for part in dotted.split("."):
            if not isinstance(cursor, dict) or part not in cursor:
                raise ConfigError(f"missing required config field: {dotted}")
            cursor = cursor[part]
        if not isinstance(cursor, str) or not cursor.strip():
            raise ConfigError(f"missing required config field: {dotted}")
        values[attr] = cursor.strip()

    personas = payload.get("agent_personas")
    if personas is None:
        personas = {}
    if not isinstance(personas, dict):
        raise ConfigError("agent_personas must be a mapping")

    normalized_personas = {
        str(key).strip().lower(): str(value).strip()
        for key, value in personas.items()
        if isinstance(value, str) and str(value).strip()
    }

    return FrameworkConfig(path=path, agent_personas=normalized_personas, **values)


if __name__ == "__main__":
    config = load_config(require_live=False)
    print(config)
