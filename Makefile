.PHONY: check lint link-check all setup-hooks

# Run all checks (same as CI)
all: check lint

# Doc quality checks — the autoresearch mechanical metric
check:
	@bash scripts/doc-quality.sh

# Markdown linting (requires markdownlint-cli2: npm install -g markdownlint-cli2)
lint:
	@markdownlint-cli2 README.md "skills/**/*.md" 2>/dev/null || echo "Install markdownlint-cli2: npm install -g markdownlint-cli2"

# Link validation (requires markdown-link-check: npm install -g markdown-link-check)
link-check:
	@markdown-link-check README.md skills/autoresearch/SKILL.md 2>/dev/null || echo "Install markdown-link-check: npm install -g markdown-link-check"

# Install git pre-commit hook
setup-hooks:
	@ln -sf ../../scripts/pre-commit.sh .git/hooks/pre-commit
	@echo "Pre-commit hook installed."

# ShellCheck (requires shellcheck)
shellcheck:
	@shellcheck scripts/*.sh 2>/dev/null || echo "Install shellcheck: apt install shellcheck"
