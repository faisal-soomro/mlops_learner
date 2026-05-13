#!/usr/bin/env bash
set -euo pipefail

VENV="${VENV:-/root/code/ml-env}"
CONFIG="${CONFIG:-/root/code/jupyter_lab_config.py}"
ROOT_DIR="${ROOT_DIR:-/root/notebooks}"

mkdir -p "$ROOT_DIR"

# shellcheck disable=SC1091
source "$VENV/bin/activate"

jupyter lab --config="$CONFIG" --allow-root --no-browser &
JUPYTER_PID=$!

echo "JupyterLab started (pid=$JUPYTER_PID)"
echo "Check it is listening on 0.0.0.0:8888 with: ss -tlnp | grep 8888"
