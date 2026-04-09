#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="${FRAMEWORK_CONFIG:-$ROOT_DIR/config/framework.yaml}"

if [ "${1:-}" = "--file" ]; then
  if [ $# -ne 2 ]; then
    echo "Usage: scripts/validate-config.sh [--file <path>]" >&2
    exit 1
  fi
  CONFIG_FILE="$2"
fi

python3 - "$CONFIG_FILE" "$ROOT_DIR" <<'PY'
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

print(f"Config validation passed: {cfg.path}")
PY
