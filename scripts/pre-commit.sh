#!/usr/bin/env bash
# Git pre-commit hook — blocks commits when doc-quality score is non-zero
set -uo pipefail

ROOT="$(cd "$(git rev-parse --show-toplevel)" && pwd)"

echo "Running doc-quality checks..."
if ! bash "$ROOT/scripts/doc-quality.sh"; then
  echo ""
  echo "Commit blocked: fix the doc quality issues above before committing."
  exit 1
fi
