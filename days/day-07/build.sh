#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${PROJECT_DIR:-/root/code/fraud-detection}"
cd "$PROJECT_DIR"

# Clean any previous build artifacts so we know what came out of this run.
rm -rf build dist ./*.egg-info

python3 -m build

echo
echo "=== dist/ ==="
ls -la dist/

# Verify the expected wheel exists.
if compgen -G "dist/fraud_detection-0.1.0-*.whl" > /dev/null; then
  echo "OK: wheel produced"
else
  echo "FAIL: dist/fraud_detection-0.1.0-*.whl missing"
  exit 1
fi
