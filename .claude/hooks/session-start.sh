#!/bin/bash
set -euo pipefail

# Only run in remote (Claude Code on the web) environments
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# Install npm-based linting tools globally
npm install -g markdownlint-cli2 markdown-link-check

# Install shellcheck for shell script linting
if ! command -v shellcheck &>/dev/null; then
  apt-get update -qq && apt-get install -y -qq shellcheck
fi
