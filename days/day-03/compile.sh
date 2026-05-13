#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${PROJECT_DIR:-/root/code/fraud-detection}"

cd "$PROJECT_DIR"
uv pip compile requirements.in -o requirements.txt

echo "Lockfile written to $PROJECT_DIR/requirements.txt"
echo "Top-level pins:"
grep -E '^(scikit-learn|mlflow|pandas|numpy)==' requirements.txt || true
