#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${PROJECT_DIR:-/root/code/fraud-detection}"
cd "$PROJECT_DIR"

# 1. Rename singular -> plural for any misnamed src/ subdirs.
#    `mv` would refuse to overwrite if the target already exists; check first.
for pair in "feature features" "util utils"; do
  src="${pair% *}"
  dst="${pair#* }"
  if [ -d "src/$src" ]; then
    if [ -d "src/$dst" ]; then
      echo "warn: both src/$src and src/$dst exist — merging $src into $dst, then removing $src"
      cp -a "src/$src/." "src/$dst/"
      rm -rf "src/$src"
    else
      mv "src/$src" "src/$dst"
    fi
  fi
done

# 2. Create the target directory tree (idempotent).
mkdir -p data/raw data/processed models notebooks \
         src/data src/features src/models src/utils \
         tests configs

# 3. __init__.py under every src/ subdir (top-level src/ too, for cleanliness).
touch src/__init__.py \
      src/data/__init__.py \
      src/features/__init__.py \
      src/models/__init__.py \
      src/utils/__init__.py

# 4. Required dependencies, one per line.
cat > requirements.txt <<'EOF'
scikit-learn
pandas
numpy
mlflow
EOF

# 5. README.md must start with `# fraud-detection`.
if [ ! -f README.md ]; then
  echo "# fraud-detection" > README.md
elif ! head -1 README.md | grep -qx '# fraud-detection'; then
  tmp="$(mktemp)"
  { echo "# fraud-detection"; echo; tail -n +2 README.md; } > "$tmp"
  mv "$tmp" README.md
fi

echo "Project layout fixed at $PROJECT_DIR"
