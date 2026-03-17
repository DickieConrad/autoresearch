#!/usr/bin/env bash
# doc-quality.sh — Mechanical quality checker for autoresearch docs
# Counts issues: lower is better
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ISSUES=0

# ── 1. Broken internal references ──────────────────────────────────
# Find all `references/X.md` or backtick-quoted file mentions and check they exist
REFS=$(grep -roh 'references/[a-z_-]*\.md' "$ROOT/skills/autoresearch/" "$ROOT/README.md" 2>/dev/null | sort -u || true)
while IFS= read -r ref; do
  [[ -z "$ref" ]] && continue
  file="$ROOT/skills/autoresearch/$ref"
  if [[ ! -f "$file" ]]; then
    echo "BROKEN_REF: $ref"
    ((ISSUES++))
  fi
done <<< "$REFS"

# ── 2. Number consistency: principles count ────────────────────────
# core-principles.md header says N principles — count actual ## headings
PRINCIPLES_CLAIMED=$(grep -oP '\d+(?= universal principles)' "$ROOT/skills/autoresearch/references/core-principles.md" 2>/dev/null || echo "0")
PRINCIPLES_ACTUAL=$(grep -cP '^## \d+\.' "$ROOT/skills/autoresearch/references/core-principles.md" 2>/dev/null || echo "0")
if [[ "$PRINCIPLES_CLAIMED" != "$PRINCIPLES_ACTUAL" ]]; then
  echo "INCONSISTENCY: core-principles.md claims $PRINCIPLES_CLAIMED principles but has $PRINCIPLES_ACTUAL"
  ((ISSUES++))
fi

# README principles count
README_PRINCIPLES_CLAIMED=$(grep -oP 'These \K\d+(?= principles)' "$ROOT/README.md" 2>/dev/null || echo "0")
if [[ "$README_PRINCIPLES_CLAIMED" != "0" && "$README_PRINCIPLES_CLAIMED" != "$PRINCIPLES_ACTUAL" ]]; then
  echo "INCONSISTENCY: README claims $README_PRINCIPLES_CLAIMED principles but core-principles.md has $PRINCIPLES_ACTUAL"
  ((ISSUES++))
fi

# ── 3. Version consistency ─────────────────────────────────────────
SKILL_VERSION=$(grep -oP 'version: \K[0-9.]+' "$ROOT/skills/autoresearch/SKILL.md" 2>/dev/null || echo "none")
README_VERSION=$(grep -oP 'version-\K[0-9.]+' "$ROOT/README.md" 2>/dev/null | head -1 || echo "none")
if [[ "$SKILL_VERSION" != "$README_VERSION" ]]; then
  echo "INCONSISTENCY: SKILL.md version=$SKILL_VERSION vs README badge version=$README_VERSION"
  ((ISSUES++))
fi

# ── 4. Subcommand consistency ──────────────────────────────────────
# SKILL.md subcommand table should list all subcommands mentioned in README
SKILL_SUBCMDS=$(grep -oP '/autoresearch:\w+' "$ROOT/skills/autoresearch/SKILL.md" 2>/dev/null | sort -u)
README_SUBCMDS=$(grep -oP '/autoresearch:\w+' "$ROOT/README.md" 2>/dev/null | sort -u)
while IFS= read -r cmd; do
  if ! echo "$SKILL_SUBCMDS" | grep -qF "$cmd"; then
    echo "MISSING_IN_SKILL: $cmd referenced in README but not in SKILL.md"
    ((ISSUES++))
  fi
done <<< "$README_SUBCMDS"
while IFS= read -r cmd; do
  if ! echo "$README_SUBCMDS" | grep -qF "$cmd"; then
    echo "MISSING_IN_README: $cmd defined in SKILL.md but not in README"
    ((ISSUES++))
  fi
done <<< "$SKILL_SUBCMDS"

# ── 5. Critical rules count ───────────────────────────────────────
README_RULES_HEADER=$(grep -oP '\d+(?= Critical Rules)' "$ROOT/README.md" 2>/dev/null || echo "0")
README_RULES_ACTUAL=$(grep -cP '^\| \d+ \|' "$ROOT/README.md" 2>/dev/null || echo "0")
if [[ "$README_RULES_HEADER" != "0" && "$README_RULES_HEADER" != "$README_RULES_ACTUAL" ]]; then
  echo "INCONSISTENCY: README header says $README_RULES_HEADER critical rules but table has $README_RULES_ACTUAL"
  ((ISSUES++))
fi

# ── 6. Loop description consistency ───────────────────────────────
# SKILL.md and README should both mention spec gate if spec-driven-workflow.md exists
if [[ -f "$ROOT/skills/autoresearch/references/spec-driven-workflow.md" ]]; then
  if ! grep -q 'spec' "$ROOT/skills/autoresearch/SKILL.md" 2>/dev/null; then
    echo "MISSING: spec-driven-workflow.md exists but SKILL.md doesn't mention specs"
    ((ISSUES++))
  fi
  if ! grep -q 'spec' "$ROOT/README.md" 2>/dev/null; then
    echo "MISSING: spec-driven-workflow.md exists but README doesn't mention specs"
    ((ISSUES++))
  fi
  # The loop protocol should mention spec
  if ! grep -q 'spec' "$ROOT/skills/autoresearch/references/autonomous-loop-protocol.md" 2>/dev/null; then
    echo "MISSING: spec-driven-workflow.md exists but autonomous-loop-protocol.md doesn't mention specs"
    ((ISSUES++))
  fi
fi

# ── 7. Repo structure in README matches actual files ───────────────
while IFS= read -r listed; do
  # Extract filenames from the tree diagram
  fname=$(echo "$listed" | sed 's/.*[├└│─ ]*//' | sed 's/ *←.*//' | xargs)
  if [[ -n "$fname" && "$fname" == *.md ]]; then
    # Try to find this file
    found=$(find "$ROOT/skills" -name "$fname" 2>/dev/null | head -1)
    if [[ -z "$found" && "$fname" != "README.md" && "$fname" != "LICENSE" ]]; then
      echo "REPO_STRUCTURE: $fname listed in README tree but not found"
      ((ISSUES++))
    fi
  fi
done <<< "$(grep -A 20 "Repository Structure" "$ROOT/README.md" | grep -E '(├|└|│)' 2>/dev/null || true)"

# ── 8. TSV format consistency ──────────────────────────────────────
# If results-logging.md and autonomous-loop-protocol.md both show TSV, columns should match
# Just check that loop protocol has more columns than results-logging (since we added spec_status)
# This is a loose check — tight checking is fragile

# ── 9. Orphan references ──────────────────────────────────────────
# Reference files that exist but are never mentioned in SKILL.md
for ref in "$ROOT/skills/autoresearch/references/"*.md; do
  fname=$(basename "$ref")
  if ! grep -q "$fname" "$ROOT/skills/autoresearch/SKILL.md" 2>/dev/null; then
    echo "ORPHAN_REF: references/$fname not mentioned in SKILL.md"
    ((ISSUES++))
  fi
done

# ── 10. Duplicate sections ────────────────────────────────────────
# Check for exact duplicate H2/H3 headers in README
DUP_HEADERS=$(grep -E '^#{2,3} ' "$ROOT/README.md" | sort | uniq -d | wc -l)
if [[ "$DUP_HEADERS" -gt 0 ]]; then
  echo "DUPLICATE_HEADERS: $DUP_HEADERS duplicate section headers in README"
  ((ISSUES++))
fi

# ── 11. Plan workflow references ──────────────────────────────────
# plan-workflow.md should be mentioned in both SKILL.md and README
if [[ -f "$ROOT/skills/autoresearch/references/plan-workflow.md" ]]; then
  if ! grep -q 'plan-workflow.md' "$ROOT/skills/autoresearch/SKILL.md" 2>/dev/null; then
    echo "MISSING: plan-workflow.md not cross-referenced in SKILL.md"
    ((ISSUES++))
  fi
fi

# ── 12. Meta-principle consistency ─────────────────────────────────
# The meta-principle quote should be consistent across files
META_CORE=$(grep -c 'encode behavioral intent in specs' "$ROOT/skills/autoresearch/references/core-principles.md" 2>/dev/null || echo "0")
META_README=$(grep -c 'encode behavioral intent in specs' "$ROOT/README.md" 2>/dev/null || echo "0")
if [[ "$META_CORE" -gt 0 && "$META_README" -eq 0 ]]; then
  echo "INCONSISTENCY: core-principles.md meta-principle mentions specs but README doesn't"
  ((ISSUES++))
fi

# ── 13. TSV column consistency ─────────────────────────────────────
# results-logging.md defines the canonical columns; autonomous-loop-protocol.md should match
LOGGING_HEADER=$(grep -A1 '^```tsv' "$ROOT/skills/autoresearch/references/results-logging.md" 2>/dev/null | tail -1 || true)
# Check that results-logging.md includes spec_status if spec workflow exists
if [[ -f "$ROOT/skills/autoresearch/references/spec-driven-workflow.md" ]]; then
  if ! echo "$LOGGING_HEADER" | grep -q 'spec_status'; then
    echo "INCONSISTENCY: spec-driven-workflow.md exists but results-logging.md TSV header lacks spec_status column"
    ((ISSUES++))
  fi
fi

# ── 14. Setup phase consistency ───────────────────────────────────
# SKILL.md setup phase should mention spec if spec workflow exists
if [[ -f "$ROOT/skills/autoresearch/references/spec-driven-workflow.md" ]]; then
  SETUP_SECTION=$(sed -n '/## Setup Phase/,/## The Loop/p' "$ROOT/skills/autoresearch/SKILL.md" 2>/dev/null || true)
  if [[ -n "$SETUP_SECTION" ]] && ! echo "$SETUP_SECTION" | grep -qi 'spec'; then
    echo "MISSING: Setup Phase in SKILL.md doesn't mention spec generation"
    ((ISSUES++))
  fi
fi

# ── 15. README setup steps should mention spec ────────────────────
if [[ -f "$ROOT/skills/autoresearch/references/spec-driven-workflow.md" ]]; then
  README_SETUP=$(sed -n '/### The Setup Phase/,/### The Autonomous Loop/p' "$ROOT/README.md" 2>/dev/null || true)
  if [[ -n "$README_SETUP" ]] && ! echo "$README_SETUP" | grep -qi 'spec'; then
    echo "MISSING: README Setup Phase table doesn't mention spec generation"
    ((ISSUES++))
  fi
fi

# ── 16. Spec workflow cross-references ────────────────────────────
# spec-driven-workflow.md should reference autonomous-loop-protocol.md and vice versa
if [[ -f "$ROOT/skills/autoresearch/references/spec-driven-workflow.md" ]]; then
  if ! grep -q 'autonomous-loop-protocol' "$ROOT/skills/autoresearch/references/spec-driven-workflow.md" 2>/dev/null; then
    echo "MISSING: spec-driven-workflow.md doesn't cross-reference autonomous-loop-protocol.md"
    ((ISSUES++))
  fi
fi

# ── 17. Plan workflow should suggest spec ─────────────────────────
# plan-workflow.md should mention spec generation as an optional step
if [[ -f "$ROOT/skills/autoresearch/references/spec-driven-workflow.md" ]]; then
  if ! grep -qi 'spec' "$ROOT/skills/autoresearch/references/plan-workflow.md" 2>/dev/null; then
    echo "MISSING: plan-workflow.md doesn't suggest running /autoresearch:spec"
    ((ISSUES++))
  fi
fi

# ── 18. README "How It Works" loop description should mention spec ─
README_LOOP_DESC=$(sed -n '/### The Autonomous Loop/,/### Results Tracking/p' "$ROOT/README.md" 2>/dev/null || true)
if [[ -f "$ROOT/skills/autoresearch/references/spec-driven-workflow.md" ]]; then
  if [[ -n "$README_LOOP_DESC" ]] && ! echo "$README_LOOP_DESC" | grep -qi 'spec'; then
    echo "MISSING: README 'The Autonomous Loop' section doesn't mention spec gate"
    ((ISSUES++))
  fi
fi

# ── 19. Results tracking in README should show spec_status ────────
README_RESULTS=$(sed -n '/### Results Tracking/,/^---/p' "$ROOT/README.md" 2>/dev/null || true)
if [[ -f "$ROOT/skills/autoresearch/references/spec-driven-workflow.md" ]]; then
  if [[ -n "$README_RESULTS" ]] && ! echo "$README_RESULTS" | grep -q 'spec_status'; then
    echo "MISSING: README Results Tracking section doesn't show spec_status column"
    ((ISSUES++))
  fi
fi

# ── 20. Contributing section should mention specs ─────────────────
if [[ -f "$ROOT/skills/autoresearch/references/spec-driven-workflow.md" ]]; then
  CONTRIB=$(sed -n '/## Contributing/,/^---/p' "$ROOT/README.md" 2>/dev/null || true)
  if [[ -n "$CONTRIB" ]] && ! echo "$CONTRIB" | grep -qi 'spec'; then
    echo "MISSING: Contributing section doesn't mention spec-related contributions"
    ((ISSUES++))
  fi
fi

# ── 21. SKILL.md critical rules should mention spec ──────────────
if [[ -f "$ROOT/skills/autoresearch/references/spec-driven-workflow.md" ]]; then
  RULES_SECTION=$(sed -n '/## Critical Rules/,/## Principles/p' "$ROOT/skills/autoresearch/SKILL.md" 2>/dev/null || true)
  if [[ -n "$RULES_SECTION" ]] && ! echo "$RULES_SECTION" | grep -qi 'spec'; then
    echo "MISSING: SKILL.md Critical Rules section doesn't mention spec validation"
    ((ISSUES++))
  fi
fi

# ── 22. README critical rules table should mention spec ──────────
if [[ -f "$ROOT/skills/autoresearch/references/spec-driven-workflow.md" ]]; then
  README_RULES=$(sed -n '/## 8 Critical Rules/,/^---/p' "$ROOT/README.md" 2>/dev/null || true)
  if [[ -z "$README_RULES" ]]; then
    README_RULES=$(sed -n '/Critical Rules/,/^---/p' "$ROOT/README.md" 2>/dev/null || true)
  fi
  if [[ -n "$README_RULES" ]] && ! echo "$README_RULES" | grep -qi 'spec'; then
    echo "MISSING: README Critical Rules table doesn't mention spec validation"
    ((ISSUES++))
  fi
fi

# ── 23. FAQ should mention spec ──────────────────────────────────
if [[ -f "$ROOT/skills/autoresearch/references/spec-driven-workflow.md" ]]; then
  FAQ=$(sed -n '/## FAQ/,/^---/p' "$ROOT/README.md" 2>/dev/null || true)
  if [[ -n "$FAQ" ]] && ! echo "$FAQ" | grep -qi 'spec'; then
    echo "MISSING: README FAQ doesn't mention /autoresearch:spec"
    ((ISSUES++))
  fi
fi

# ── 24. Crash Recovery should mention spec validation failures ───
if [[ -f "$ROOT/skills/autoresearch/references/spec-driven-workflow.md" ]]; then
  CRASH_README=$(sed -n '/## Crash Recovery/,/^---/p' "$ROOT/README.md" 2>/dev/null || true)
  if [[ -n "$CRASH_README" ]] && ! echo "$CRASH_README" | grep -qi 'spec'; then
    echo "MISSING: README Crash Recovery doesn't address spec validation failures"
    ((ISSUES++))
  fi
fi

# ── 25. Spec workflow should mention crash recovery ──────────────
if [[ -f "$ROOT/skills/autoresearch/references/spec-driven-workflow.md" ]]; then
  if ! grep -qi 'crash\|failure\|error recovery' "$ROOT/skills/autoresearch/references/spec-driven-workflow.md" 2>/dev/null; then
    echo "MISSING: spec-driven-workflow.md doesn't address error/failure recovery"
    ((ISSUES++))
  fi
fi

# ── 26. Loop protocol When Stuck should consider spec ────────────
if [[ -f "$ROOT/skills/autoresearch/references/spec-driven-workflow.md" ]]; then
  STUCK=$(sed -n '/When Stuck/,/## Crash/p' "$ROOT/skills/autoresearch/references/autonomous-loop-protocol.md" 2>/dev/null || true)
  if [[ -n "$STUCK" ]] && ! echo "$STUCK" | grep -qi 'spec'; then
    echo "MISSING: autonomous-loop-protocol.md 'When Stuck' section doesn't mention reviewing spec"
    ((ISSUES++))
  fi
fi

# ── 27. README Pattern sections should include a spec pattern ────
if [[ -f "$ROOT/skills/autoresearch/references/spec-driven-workflow.md" ]]; then
  PATTERNS=$(sed -n '/## Claude Code Patterns/,/## Writing Verification/p' "$ROOT/README.md" 2>/dev/null || true)
  if [[ -n "$PATTERNS" ]] && ! echo "$PATTERNS" | grep -qi 'spec'; then
    echo "MISSING: README Claude Code Patterns section doesn't include a spec-driven pattern"
    ((ISSUES++))
  fi
fi

# ── 28. Spec workflow should have summary section ────────────────
if [[ -f "$ROOT/skills/autoresearch/references/spec-driven-workflow.md" ]]; then
  if ! grep -qP '^## (Summary|Quick Reference|TL;DR)' "$ROOT/skills/autoresearch/references/spec-driven-workflow.md" 2>/dev/null; then
    echo "MISSING: spec-driven-workflow.md lacks a summary/quick-reference section"
    ((ISSUES++))
  fi
fi

# ── 29. All reference docs should have consistent header format ──
for ref in "$ROOT/skills/autoresearch/references/"*.md; do
  fname=$(basename "$ref")
  # Each should start with a H1 header
  FIRST_LINE=$(head -1 "$ref")
  if [[ ! "$FIRST_LINE" =~ ^#\  ]]; then
    echo "FORMAT: references/$fname doesn't start with H1 header"
    ((ISSUES++))
  fi
done

# ── 30. Results-logging should mention spec_status in Columns table ──
if [[ -f "$ROOT/skills/autoresearch/references/spec-driven-workflow.md" ]]; then
  COLS_TABLE=$(sed -n '/### Columns/,/### Example/p' "$ROOT/skills/autoresearch/references/results-logging.md" 2>/dev/null || true)
  if [[ -n "$COLS_TABLE" ]] && ! echo "$COLS_TABLE" | grep -q 'spec_status'; then
    echo "MISSING: results-logging.md Columns table doesn't document spec_status"
    ((ISSUES++))
  fi
fi

# ── 31. README Quick Start should mention all 3 subcommands ──────
QS=$(sed -n '/## Quick Start/,/^---/p' "$ROOT/README.md" 2>/dev/null || true)
if [[ -n "$QS" ]] && ! echo "$QS" | grep -q 'autoresearch:spec'; then
  echo "MISSING: README Quick Start section doesn't mention /autoresearch:spec"
  ((ISSUES++))
fi

# ── 32. Spec workflow examples should cover at least 3 domains ───
if [[ -f "$ROOT/skills/autoresearch/references/spec-driven-workflow.md" ]]; then
  EXAMPLE_COUNT=$(grep -c '^### Example:' "$ROOT/skills/autoresearch/references/spec-driven-workflow.md" 2>/dev/null || echo "0")
  if [[ "$EXAMPLE_COUNT" -lt 3 ]]; then
    echo "COVERAGE: spec-driven-workflow.md has only $EXAMPLE_COUNT examples (need at least 3)"
    ((ISSUES++))
  fi
fi

# ── 33. README "What Is This" section should mention spec ────────
if [[ -f "$ROOT/skills/autoresearch/references/spec-driven-workflow.md" ]]; then
  WHAT_IS=$(sed -n '/## What Is This/,/^---/p' "$ROOT/README.md" 2>/dev/null || true)
  if [[ -n "$WHAT_IS" ]] && ! echo "$WHAT_IS" | grep -qi 'spec'; then
    echo "MISSING: README 'What Is This' section doesn't mention spec-driven verification"
    ((ISSUES++))
  fi
fi

# ── 34. SKILL.md domain adaptation table should mention spec ─────
if [[ -f "$ROOT/skills/autoresearch/references/spec-driven-workflow.md" ]]; then
  ADAPT=$(sed -n '/## Adapting to Different Domains/,$p' "$ROOT/skills/autoresearch/SKILL.md" 2>/dev/null || true)
  if [[ -n "$ADAPT" ]] && ! echo "$ADAPT" | grep -qi 'spec'; then
    echo "MISSING: SKILL.md domain adaptation section doesn't mention specs"
    ((ISSUES++))
  fi
fi

# ── 35. README Combining with MCP should mention spec ────────────
if [[ -f "$ROOT/skills/autoresearch/references/spec-driven-workflow.md" ]]; then
  MCP=$(sed -n '/## Combining with MCP/,/^---/p' "$ROOT/README.md" 2>/dev/null || true)
  if [[ -n "$MCP" ]] && ! echo "$MCP" | grep -qi 'spec'; then
    echo "MISSING: README MCP section doesn't mention combining MCP with specs"
    ((ISSUES++))
  fi
fi

# ── 36. README Karpathy section should mention spec extension ────
if [[ -f "$ROOT/skills/autoresearch/references/spec-driven-workflow.md" ]]; then
  KARPATHY=$(sed -n '/## About Karpathy/,/^---/p' "$ROOT/README.md" 2>/dev/null || true)
  if [[ -n "$KARPATHY" ]] && ! echo "$KARPATHY" | grep -qi 'spec'; then
    echo "MISSING: README Karpathy section doesn't mention spec as an extension of the original approach"
    ((ISSUES++))
  fi
fi

# ── 37. All reference docs should cross-reference related docs ───
# autonomous-loop-protocol.md should reference spec-driven-workflow.md
if [[ -f "$ROOT/skills/autoresearch/references/spec-driven-workflow.md" ]]; then
  if ! grep -q 'spec-driven-workflow' "$ROOT/skills/autoresearch/references/autonomous-loop-protocol.md" 2>/dev/null; then
    echo "MISSING: autonomous-loop-protocol.md doesn't cross-reference spec-driven-workflow.md"
    ((ISSUES++))
  fi
fi

# ── 38. README loop description should show spec_status in TSV ───
if [[ -f "$ROOT/skills/autoresearch/references/spec-driven-workflow.md" ]]; then
  # The top-level "The loop:" summary should mention spec
  TOPLEVEL_LOOP=$(sed -n '/\*\*The loop:\*\*/,/^---/p' "$ROOT/README.md" 2>/dev/null || true)
  if [[ -n "$TOPLEVEL_LOOP" ]] && ! echo "$TOPLEVEL_LOOP" | grep -qi 'spec'; then
    echo "MISSING: README top-level 'The loop' summary doesn't mention spec gate"
    ((ISSUES++))
  fi
fi

# ── 40. SKILL.md critical rules count matches ───────────────────
# Rules section specifically
SKILL_RULES_SECTION=$(sed -n '/## Critical Rules/,/## Principles/p' "$ROOT/skills/autoresearch/SKILL.md" 2>/dev/null || true)
SKILL_RULES_IN_SECTION=$(echo "$SKILL_RULES_SECTION" | grep -cP '^\d+\. \*\*' 2>/dev/null || echo "0")
# README rules header count should match SKILL.md rules count
README_RULES_IN_HEADER=$(grep -oP '\d+(?= Critical Rules)' "$ROOT/README.md" 2>/dev/null || echo "0")
if [[ "$README_RULES_IN_HEADER" != "0" && "$README_RULES_IN_HEADER" != "$SKILL_RULES_IN_SECTION" ]]; then
  echo "INCONSISTENCY: README says $README_RULES_IN_HEADER Critical Rules but SKILL.md has $SKILL_RULES_IN_SECTION"
  ((ISSUES++))
fi

# ── 41. README rules table row count should match header ─────────
README_RULE_ROWS=$(grep -cP '^\| \d+ \|' "$ROOT/README.md" 2>/dev/null || echo "0")
if [[ "$README_RULES_IN_HEADER" != "0" && "$README_RULES_IN_HEADER" != "$README_RULE_ROWS" ]]; then
  echo "INCONSISTENCY: README header says $README_RULES_IN_HEADER rules but table has $README_RULE_ROWS rows"
  ((ISSUES++))
fi

# ── 42. Spec-driven-workflow examples should all have valid check commands ─
if [[ -f "$ROOT/skills/autoresearch/references/spec-driven-workflow.md" ]]; then
  # Count spec items that have a check command (colon followed by backtick)
  SPEC_ITEMS=$(grep -cP '^\- \[ \]' "$ROOT/skills/autoresearch/references/spec-driven-workflow.md" 2>/dev/null || echo "0")
  SPEC_WITH_CMD=$(grep -cP '^\- \[ \].*`' "$ROOT/skills/autoresearch/references/spec-driven-workflow.md" 2>/dev/null || echo "0")
  SPEC_WITHOUT_CMD=$((SPEC_ITEMS - SPEC_WITH_CMD))
  if [[ "$SPEC_WITHOUT_CMD" -gt 0 ]]; then
    echo "QUALITY: spec-driven-workflow.md has $SPEC_WITHOUT_CMD spec items without check commands"
    ((ISSUES++))
  fi
fi

# ── 43. README version sections should be in descending order ────
VERSIONS=$(grep -oP '\(v\K[0-9.]+(?=\))' "$ROOT/README.md" 2>/dev/null | head -5)
PREV_MAJOR=999
PREV_MINOR=999
ORDERED=true
while IFS= read -r ver; do
  [[ -z "$ver" ]] && continue
  MAJOR=$(echo "$ver" | cut -d. -f1)
  MINOR=$(echo "$ver" | cut -d. -f2)
  if [[ "$MAJOR" -gt "$PREV_MAJOR" ]] || [[ "$MAJOR" -eq "$PREV_MAJOR" && "$MINOR" -gt "$PREV_MINOR" ]]; then
    ORDERED=false
    break
  fi
  PREV_MAJOR=$MAJOR
  PREV_MINOR=$MINOR
done <<< "$VERSIONS"
if [[ "$ORDERED" == "false" ]]; then
  echo "ORDERING: README version sections are not in descending order"
  ((ISSUES++))
fi

echo ""
echo "SCORE: $ISSUES"

if [[ "$ISSUES" -gt 0 ]]; then
  echo ""
  echo "FAILED: $ISSUES doc quality issue(s) found."
  exit 1
else
  echo ""
  echo "PASSED: All doc quality checks passed."
  exit 0
fi
