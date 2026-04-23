#!/usr/bin/env bash
set -euo pipefail

load_framework_config() {
  local root_dir config_file exports
  root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  config_file="${1:-${FRAMEWORK_CONFIG:-$root_dir/config/framework.yaml}}"

  exports="$(python3 - "$config_file" "$root_dir" <<'PY'
import shlex
import sys
from pathlib import Path

config_path = Path(sys.argv[1])
root_dir = Path(sys.argv[2])
sys.path.insert(0, str(root_dir))
from scripts.lib.config import ConfigError, load_config

try:
    cfg = load_config(config_path)
except ConfigError as exc:
    print(f"ERROR: {exc}", file=sys.stderr)
    raise SystemExit(1)

print(f"FRAMEWORK_CONFIG={shlex.quote(str(cfg.path))}")
print(f"FRAMEWORK_OPERATOR_NAME={shlex.quote(cfg.operator_name)}")
print(f"FRAMEWORK_OPERATOR_CALLNAME={shlex.quote(cfg.operator_callname)}")
print(f"FRAMEWORK_OPERATOR_EMAIL_DOMAIN={shlex.quote(cfg.operator_email_domain)}")
print(f"FRAMEWORK_OPERATOR_TIMEZONE={shlex.quote(cfg.operator_timezone)}")
print(f"FRAMEWORK_OPENCLAW_WORKSPACE_ROOT={shlex.quote(cfg.workspace_root)}")
for archetype in ["orchestrator", "spec", "builder", "qa", "security", "release_manager", "triage"]:
    env_key = f"FRAMEWORK_AGENT_PERSONA_{archetype.upper()}"
    print(f"{env_key}={shlex.quote(cfg.persona_for(archetype))}")
PY
)"

  eval "export $exports"
}
