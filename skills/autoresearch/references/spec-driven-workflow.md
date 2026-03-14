# Spec-Driven Workflow — /autoresearch:spec

Generate a behavioral specification before running the autonomous loop. The spec acts as a **second verification gate** — changes must improve the metric AND satisfy the spec.

**Related:** This workflow integrates with the autonomous loop defined in `references/autonomous-loop-protocol.md` (Phases 5-7).

## Quick Reference

| Step | Action |
|------|--------|
| 1. Generate | Run `/autoresearch:spec` → scans codebase → creates `autoresearch-spec.md` |
| 2. Review | Select which invariants, behaviors, and constraints to enforce |
| 3. Validate | Dry-run all spec checks — all must pass before loop starts |
| 4. Commit | `git commit autoresearch-spec.md` — spec is version-controlled |
| 5. Loop | Spec validates automatically each iteration (tiered: T0/T1/T2) |

**Decision matrix with spec:**

```
metric improved + spec passes  → KEEP
metric improved + spec fails   → DISCARD (metric gaming)
metric same/worse              → DISCARD
```

## Why Specs Matter

Metrics tell you if things got *numerically* better. Specs tell you if things still *behave correctly*.

Without a spec, the loop can game metrics:
- Coverage increases via trivial tests that assert nothing
- Bundle size drops by removing features
- Response time improves by skipping validation
- LOC decreases by deleting error handling

A spec prevents this by defining **invariants that must hold across all iterations**.

## Trigger

- User invokes `/autoresearch:spec`
- User says "create a spec", "define invariants", "spec first", "what should be preserved"
- Automatically suggested during `/autoresearch:plan` Phase 3 (after scope is defined)

## Spec Structure

A spec is a markdown file (`autoresearch-spec.md`) with three sections:

```markdown
# Autoresearch Spec

## Invariants
Things that must ALWAYS be true, regardless of changes.

- [ ] All tests pass: `npm test`
- [ ] No new lint errors: `npm run lint | grep -c error`
- [ ] API returns JSON for all endpoints: `curl -s /api/health | jq .`

## Behaviors
Observable behaviors that must be preserved.

- [ ] Login returns 401 for wrong password
- [ ] Rate limiter blocks after 100 requests/min
- [ ] WebSocket reconnects within 5 seconds

## Constraints
Hard limits the loop must respect.

- [ ] No new runtime dependencies
- [ ] Public API signatures unchanged
- [ ] Bundle size stays under 500KB
```

### Spec Item Rules

Every spec item MUST have:

| Property | Required | Description |
|----------|----------|-------------|
| Description | Yes | Plain-language statement of what must hold |
| Check command | Yes* | Shell command that exits 0 if satisfied |
| Tolerance | No | Acceptable deviation (e.g., "±5%") |

*Behaviors without a direct command check are validated by the existing test suite. If no tests cover the behavior, the spec workflow prompts you to add one.

## Workflow

### Phase 1: Analyze Current State

Read the codebase and identify:

1. **Existing tests** — what behaviors are already covered?
2. **Public interfaces** — API routes, exported functions, CLI commands
3. **Configuration** — env vars, feature flags, config files
4. **Dependencies** — runtime and dev dependencies
5. **Build artifacts** — output files, bundle structure

### Phase 2: Generate Spec Draft

Create `autoresearch-spec.md` with auto-detected items:

**Invariants (auto-detected):**
- Test suite passes (from detected test runner)
- Linter passes (from detected linter)
- Build succeeds (from detected build command)
- Type check passes (if TypeScript/typed language)

**Behaviors (auto-detected from tests):**
- Extract `describe`/`it`/`test` blocks from test files
- Group by module/feature
- Present top behaviors as spec items

**Constraints (auto-detected):**
- Current dependency count (lock file)
- Current bundle size (if build exists)
- Current API surface (exported symbols)

### Phase 3: User Review

Present the draft spec:

```
AskUserQuestion:
  question: "Here's the generated spec. Which items should be enforced during the autoresearch loop?"
  header: "Spec Review"
  multiSelect: true
  options:
    - label: "All invariants"
      description: "{N} invariants — tests pass, lint clean, build succeeds"
    - label: "All behaviors"
      description: "{N} key behaviors extracted from test suite"
    - label: "All constraints"
      description: "{N} constraints — deps, bundle size, API surface"
    - label: "Let me edit the spec"
      description: "I'll modify autoresearch-spec.md manually before starting"
```

### Phase 4: Validate Spec

Run every spec check command against the current codebase:

```
Spec Validation:
  ✓ All tests pass (exit 0)
  ✓ No lint errors (0 errors)
  ✓ Build succeeds (exit 0)
  ✗ Bundle under 500KB (currently 523KB)
    → Adjust constraint or fix before starting?
```

**Rules:**
- ALL spec items must pass before the loop starts
- If a spec item fails on the current codebase, it's either a bug to fix or a constraint to relax
- Do not start the loop with a failing spec — the loop can't improve what's already broken

### Phase 5: Commit Spec

```bash
git add autoresearch-spec.md
git commit -m "spec: add autoresearch behavioral spec"
```

The spec is version-controlled so the loop can reference it and humans can review it.

## Integration with the Autonomous Loop

### Modified Phase 5 (Verify) — Dual Gate

After the mechanical metric check, run the spec check:

```
1. Run metric verification (existing)
2. IF metric improved OR metric same:
     Run spec validation (ALL check commands)
     IF any spec item fails:
       STATUS = "spec_violation"
       git reset --hard HEAD~1
       Log: "discard (spec violation: {which item})"
```

### Modified Phase 6 (Decide) — Extended Decision Matrix

```
IF metric_improved AND spec_passes:
    STATUS = "keep"
ELIF metric_improved AND spec_fails:
    STATUS = "discard"  # Metric gaming detected
    Log reason: "spec violation: {item}"
ELIF metric_same AND spec_passes AND simpler:
    STATUS = "keep"  # Simplification win
ELIF metric_same_or_worse:
    STATUS = "discard"
ELIF crashed:
    # Existing crash recovery
```

### Modified Phase 7 (Log) — Extended TSV

Add `spec_status` column:

```tsv
iteration	commit	metric	delta	status	spec_status	description
0	a1b2c3d	85.2	0.0	baseline	pass	initial state
1	b2c3d4e	87.1	+1.9	keep	pass	add auth middleware tests
2	-	89.0	+1.9	discard	FAIL:invariant:lint	add tests but introduce lint errors
3	c3d4e5f	88.3	+1.2	keep	pass	add API route error handling tests
```

## Spec Evolution

The spec is NOT frozen forever. It can evolve:

- **Tighten:** After improvements, update constraints (e.g., bundle was 500KB, now 400KB → tighten to 420KB)
- **Expand:** Add new invariants discovered during the loop
- **Relax:** If a constraint blocks all progress, discuss with user before relaxing

**Rule:** Spec changes require a dedicated commit and are logged:
```
spec_change	-	-	0.0	spec_update	-	tighten bundle constraint from 500KB to 420KB
```

## Speed Considerations

Spec validation adds overhead per iteration. Mitigate this:

1. **Fast checks only** — each spec item should complete in <5 seconds
2. **Parallel execution** — run independent checks concurrently
3. **Skip redundant checks** — if metric verification already runs tests, don't re-run for invariant
4. **Tiered validation** — run invariants every iteration, behaviors every 5th iteration, constraints every 10th

### Tiered Validation Schedule

| Tier | Frequency | Items | Rationale |
|------|-----------|-------|-----------|
| T0: Invariants | Every iteration | Tests pass, lint clean, build works | Catch breakage immediately |
| T1: Behaviors | Every 5th iteration | Key user-facing behaviors | Behavioral drift is slower |
| T2: Constraints | Every 10th iteration | Dep count, bundle size, API surface | These change rarely per-iteration |

## Anti-Patterns

- **Spec too strict** — every spec item should allow the loop room to experiment. Don't spec implementation details, spec outcomes
- **Spec too loose** — a spec with only "tests pass" adds no value beyond the existing metric. Add behavioral and constraint checks
- **Subjective spec items** — "code should be readable" is not checkable. Use "cyclomatic complexity < 10" instead
- **Slow spec checks** — a spec that adds 2 minutes per iteration kills the loop. Keep total spec validation under 10 seconds
- **Spec without commands** — every item needs a mechanical check. No exceptions

## Examples

### Example: API Performance Optimization

```markdown
# Autoresearch Spec

## Invariants
- [ ] All tests pass: `npm test`
- [ ] TypeScript compiles: `npx tsc --noEmit`

## Behaviors
- [ ] GET /api/users returns paginated results: `curl -s localhost:3000/api/users | jq '.pagination'`
- [ ] POST /api/auth returns JWT: `curl -s -X POST localhost:3000/api/auth -d '{"user":"test"}' | jq '.token'`
- [ ] Rate limiter active: `for i in $(seq 1 101); do curl -s -o /dev/null -w '%{http_code}' localhost:3000/api/health; done | tail -1` → expects 429

## Constraints
- [ ] No new dependencies: `jq '.dependencies | length' package.json` → currently 12
- [ ] API response schema unchanged: `npm run test:contract`
```

### Example: Test Coverage Improvement

```markdown
# Autoresearch Spec

## Invariants
- [ ] Existing tests still pass: `npm test`
- [ ] No `any` type annotations added: `grep -r ': any' src/ --include='*.ts' | wc -l` → must not increase from baseline (currently 3)

## Behaviors
- [ ] Auth flow works end-to-end: `npm run test:e2e -- --grep "auth"`
- [ ] Database migrations reversible: `npm run migrate:up && npm run migrate:down`

## Constraints
- [ ] Test files follow naming convention: `find src -name '*.test.*' | wc -l` vs `find src -name '*.spec.*' | wc -l` → all should be .test.*
- [ ] No snapshot tests added: `grep -r 'toMatchSnapshot' src/ | wc -l` → must stay at 0
```

### Example: Content/SEO Improvement

```markdown
# Autoresearch Spec

## Invariants
- [ ] All pages build: `npm run build`
- [ ] No broken links: `npx linkinator ./dist --recurse | grep -c 'BROKEN'` → must be 0

## Behaviors
- [ ] Homepage loads in <3s: `npx lighthouse http://localhost:3000 --output json | jq '.audits["first-contentful-paint"].numericValue'` → <3000
- [ ] All images have alt text: `grep -r '<img' dist/ | grep -vc 'alt='` → must be 0

## Constraints
- [ ] Page count unchanged: `find dist -name '*.html' | wc -l` → currently 24
- [ ] No external scripts added: `grep -r '<script src="http' dist/ | wc -l` → must be 0
```
