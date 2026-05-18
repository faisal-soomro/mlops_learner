#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${PROJECT_DIR:-/root/code/fraud-detection}"
cd "$PROJECT_DIR"

echo "=== ruff check src/ ==="
ruff check src/

echo "=== black --check src/ ==="
black --check src/

echo "Both tools passed."
