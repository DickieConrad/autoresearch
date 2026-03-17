#!/bin/bash
set -euo pipefail

# Only run in remote (Claude Code on the web) environments
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# Install markdownlint-cli2 for markdown linting
npm install -g markdownlint-cli2

# Install shellcheck for shell script linting
apt-get update -qq && apt-get install -y -qq shellcheck
