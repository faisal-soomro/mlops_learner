#!/usr/bin/env bash
set -euo pipefail

CODE_DIR="${CODE_DIR:-/root/code}"
VENV_DIR="$CODE_DIR/ml-env"

mkdir -p "$CODE_DIR"
python3 -m venv "$VENV_DIR"

# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"

pip install --upgrade pip
pip install numpy pandas scikit-learn matplotlib

pip freeze > "$CODE_DIR/requirements.txt"

echo "venv ready at $VENV_DIR"
echo "requirements written to $CODE_DIR/requirements.txt"
