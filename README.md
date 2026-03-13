# Claude Autoresearch

> Turn [Claude Code](https://docs.anthropic.com/en/docs/claude-code) into a relentless improvement engine.

Based on [Karpathy's autoresearch](https://github.com/karpathy/autoresearch) — the principle that **constraint + mechanical metric + autonomous iteration = compounding gains**.

[![Claude Code Skill](https://img.shields.io/badge/Claude_Code-Skill-blue?logo=anthropic&logoColor=white)](https://docs.anthropic.com/en/docs/claude-code)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Based on](https://img.shields.io/badge/Based_on-Karpathy's_Autoresearch-orange)](https://github.com/karpathy/autoresearch)

---

## What Is This?

A [Claude Code skill](https://docs.anthropic.com/en/docs/claude-code/skills) that makes Claude iterate autonomously on ANY task with a measurable outcome — like Karpathy's autoresearch, but generalized beyond ML.

```
You set the GOAL → Claude runs the LOOP → You wake up to results
```

**The loop:**

```
LOOP FOREVER:
  1. Review current state + git history + results log
  2. Pick the next change (based on what worked, what failed, what's untried)
  3. Make ONE focused change
  4. Git commit (before verification)
  5. Run mechanical verification (tests, benchmarks, scores)
  6. If improved → keep. If worse → git revert. If crashed → fix or skip.
  7. Log the result
  8. Repeat. NEVER STOP. NEVER ASK "should I continue?"
```

Every improvement stacks. Every failure auto-reverts. Progress is logged in TSV format.

---

## Why This Exists

[Karpathy's autoresearch](https://github.com/karpathy/autoresearch) demonstrated that a 630-line Python script could autonomously improve ML models overnight — **100 experiments per night** — by following simple principles:

- **One metric** (validation loss)
- **Constrained scope** (one file)
- **Fast verification** (5-minute training runs)
- **Automatic rollback** on failure
- **Git as memory** for tracking what worked

**Claude Autoresearch generalizes these principles to ANY domain.** Not just ML — software engineering, content, sales, marketing, HR, operations, or anything with a number you can measure.

The insight: **autonomy scales when you constrain scope, clarify success, and mechanize verification.**

---

## Quick Start

### 1. Install the Skill

Clone this repo and copy the skill to your Claude Code skills directory:

```bash
# Clone
git clone https://github.com/uditgoenka/autoresearch.git

# Copy to your project's Claude Code skills
cp -r autoresearch/skills/autoresearch .claude/skills/autoresearch
```

Or copy directly into your global skills:

```bash
cp -r autoresearch/skills/autoresearch ~/.claude/skills/autoresearch
```

### 2. Invoke It

Open Claude Code in your project and run:

```
/autoresearch
Goal: Increase test coverage from 72% to 90%
Scope: src/**/*.test.ts, src/**/*.ts
Metric: coverage % (higher is better)
Verify: npm test -- --coverage | grep "All files"
```

Or use the namespaced trigger:

```
/ug:autoresearch
Goal: Reduce bundle size below 200KB
Scope: src/**/*.tsx, src/**/*.ts
Metric: bundle size in KB (lower is better)
Verify: npm run build 2>&1 | grep "First Load JS"
```

### 3. Walk Away

Claude will:
1. Read all in-scope files
2. Establish a baseline measurement
3. Start iterating — one change at a time
4. Keep improvements, auto-revert failures
5. Log every iteration in `autoresearch-results.tsv`
6. Print a summary every 10 iterations
7. **Never stop until you interrupt**

---

## How It Works

### The Setup Phase

Before looping, Claude performs a one-time setup:

| Step | What Happens |
|------|-------------|
| 1. Read context | Reads all in-scope files for full understanding |
| 2. Define goal | Extracts or asks for a mechanical metric |
| 3. Define scope | Identifies which files can be modified vs read-only |
| 4. Create results log | Initializes `autoresearch-results.tsv` |
| 5. Establish baseline | Runs verification on current state (iteration #0) |
| 6. Confirm and go | Shows setup to user, then begins the loop |

### The Autonomous Loop

Each iteration follows an 8-phase protocol:

```
┌─────────────────────────────────────────────────────┐
│                                                     │
│  Phase 1: REVIEW                                    │
│  Read current files + git log + results log         │
│                                                     │
│  Phase 2: IDEATE                                    │
│  Pick next change based on patterns and gaps        │
│                                                     │
│  Phase 3: MODIFY                                    │
│  Make ONE atomic change (explainable in 1 sentence) │
│                                                     │
│  Phase 4: COMMIT                                    │
│  Git commit BEFORE verification (clean rollback)    │
│                                                     │
│  Phase 5: VERIFY                                    │
│  Run mechanical metric command                      │
│                                                     │
│  Phase 6: DECIDE                                    │
│  Improved → keep | Worse → revert | Crash → fix    │
│                                                     │
│  Phase 7: LOG                                       │
│  Append result to autoresearch-results.tsv          │
│                                                     │
│  Phase 8: REPEAT                                    │
│  Go to Phase 1. NEVER STOP.                         │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### Results Tracking

Every iteration is logged in TSV format:

```tsv
iteration	commit	metric	delta	status	description
0	a1b2c3d	85.2	0.0	baseline	initial state — test coverage 85.2%
1	b2c3d4e	87.1	+1.9	keep	add tests for auth middleware edge cases
2	-	86.5	-0.6	discard	refactor test helpers (broke 2 tests)
3	-	0.0	0.0	crash	add integration tests (DB connection failed)
4	c3d4e5f	88.3	+1.2	keep	add tests for error handling in API routes
5	d4e5f6g	89.0	+0.7	keep	add boundary value tests for validators
```

Every 10 iterations, Claude prints a summary:

```
=== Autoresearch Progress (iteration 20) ===
Baseline: 85.2% → Current best: 92.1% (+6.9%)
Keeps: 8 | Discards: 10 | Crashes: 2
Last 5: keep, discard, discard, keep, keep
```

---

## Usage Examples

### Software Engineering

**Increase test coverage**
```
/autoresearch
Goal: Increase test coverage from 72% to 90%
Scope: src/**/*.test.ts, src/**/*.ts
Metric: coverage % (higher is better)
Verify: npm test -- --coverage | grep "All files"
```
Claude adds tests one-by-one. Each iteration: write test → run coverage → keep if % increased → discard if not → repeat.

**Reduce bundle size**
```
/autoresearch
Goal: Reduce production bundle size
Scope: src/**/*.tsx, src/**/*.ts
Metric: bundle size in KB (lower is better)
Verify: npm run build 2>&1 | grep "First Load JS"
```
Claude tries: tree-shaking unused imports, lazy-loading routes, replacing heavy libraries, code-splitting — one change at a time.

**Fix flaky tests**
```
/autoresearch
Goal: Zero flaky tests (all tests pass 5 consecutive runs)
Scope: src/**/*.test.ts
Metric: failure count across 5 runs (lower is better)
Verify: for i in {1..5}; do npm test 2>&1; done | grep -c "FAIL"
```

**Performance optimization**
```
/autoresearch
Goal: API response time under 100ms (p95)
Scope: src/api/**/*.ts, src/services/**/*.ts
Metric: p95 response time in ms (lower is better)
Verify: npm run bench:api | grep "p95"
```

**Eliminate TypeScript `any` types**
```
/autoresearch
Goal: Eliminate all TypeScript `any` types
Scope: src/**/*.ts
Metric: count of `any` occurrences (lower is better)
Verify: grep -r ":\s*any" src/ --include="*.ts" | wc -l
```

**Reduce lines of code**
```
/autoresearch
Goal: Reduce lines of code in src/services/ by 30% while keeping all tests green
Metric: LOC count (lower is better)
Verify: npm test && find src/services -name "*.ts" | xargs wc -l | tail -1
```

---

### Sales

**Cold email optimization**
```
/autoresearch
Goal: Improve cold email reply rate prediction score
Scope: content/email-templates/*.md
Metric: readability score + personalization token count (higher is better)
Verify: node scripts/score-email-template.js
```
Claude iterates on subject lines, opening hooks, CTAs, personalization variables — keeping changes that score higher.

**Sales deck refinement**
```
/autoresearch
Goal: Reduce slide count while maintaining all key points
Scope: content/sales-deck/*.md
Metric: slide count (lower is better), constraint: key-points-checklist.md must all be present
Verify: node scripts/check-deck-coverage.js && wc -l content/sales-deck/*.md
```

**Objection handling docs**
```
/autoresearch
Goal: Cover all 20 common objections with responses under 50 words each
Scope: content/objection-responses.md
Metric: objections covered + avg word count per response (more covered + fewer words = better)
Verify: node scripts/score-objections.js
```

---

### Marketing

**SEO content optimization**
```
/autoresearch
Goal: Maximize SEO score for target keywords
Scope: content/blog/*.md
Metric: SEO score from audit tool (higher is better)
Verify: node scripts/seo-score.js --file content/blog/target-post.md
```
Claude tweaks headings, keyword density, meta descriptions, internal links — one change per iteration.

**Landing page copy**
```
/autoresearch
Goal: Maximize Flesch readability + keyword density for "AI automation"
Scope: content/landing-pages/ai-automation.md
Metric: readability_score * 0.7 + keyword_density_score * 0.3 (higher is better)
Verify: node scripts/content-score.js content/landing-pages/ai-automation.md
```

**Email sequence optimization**
```
/autoresearch
Goal: Optimize 7-day nurture sequence for clarity and CTA strength
Scope: content/email-sequences/onboarding/*.md
Metric: avg readability + CTA score per email (higher is better)
Verify: node scripts/score-email-sequence.js onboarding
```

**Ad copy variants**
```
/autoresearch
Goal: Generate and refine 20 ad copy variants, each under 90 chars with power words
Scope: content/ads/facebook-q1.md
Metric: variants meeting criteria (higher is better)
Verify: node scripts/validate-ad-copy.js
```

---

### HR & People Ops

**Job description optimization**
```
/autoresearch
Goal: Improve job descriptions — bias-free language, clear requirements, inclusive tone
Scope: content/job-descriptions/*.md
Metric: inclusivity score from textio-style checker (higher is better)
Verify: node scripts/jd-inclusivity-score.js
```

**Policy document clarity**
```
/autoresearch
Goal: Reduce average reading level of HR policies to grade 8
Scope: content/policies/*.md
Metric: Flesch-Kincaid grade level (lower is better)
Verify: node scripts/readability.js content/policies/
```

**Interview question bank**
```
/autoresearch
Goal: Ensure all questions are behavioral (STAR format) + cover all competencies
Scope: content/interview-questions.md
Metric: STAR-format compliance % + competency coverage % (higher is better)
Verify: node scripts/interview-quality.js
```

---

### Operations

**Runbook optimization**
```
/autoresearch
Goal: Reduce average runbook steps while maintaining completeness
Scope: docs/runbooks/*.md
Metric: avg steps per runbook (lower is better), constraint: all checklist items preserved
Verify: node scripts/runbook-audit.js
```

**Process documentation**
```
/autoresearch
Goal: Standardize all SOPs to template format with <100 words per step
Scope: docs/sops/*.md
Metric: template compliance % + avg words per step (higher compliance + lower words = better)
Verify: node scripts/sop-score.js
```

**Incident response playbooks**
```
/autoresearch
Goal: Ensure all playbooks have decision trees, escalation paths, rollback steps
Scope: docs/incident-playbooks/*.md
Metric: completeness checklist score (higher is better)
Verify: node scripts/playbook-completeness.js
```

---

## Claude Code Patterns

### Pattern 1: "Run Overnight"

Tell Claude to iterate while you sleep. The loop never stops until you interrupt.

```
/autoresearch
Goal: Improve lighthouse score from 72 to 95+
I'm going to sleep — iterate all night. Don't ask me anything.
```

### Pattern 2: "Compound Improvements"

Stack small wins. Each kept commit builds on the last.

```
/autoresearch
Goal: Reduce TypeScript errors from 47 to 0
Start with the easiest fixes. Build momentum. Save hardest for last.
```

### Pattern 3: "Explore and Exploit"

Let Claude try bold experiments, auto-reverting failures.

```
/autoresearch
Goal: Reduce API response time
Try radical approaches too — different data structures, caching strategies, query rewrites.
If stuck after 5 discards, try something completely different.
```

### Pattern 4: "Refactor Without Breaking"

Safe refactoring with automatic rollback safety net.

```
/autoresearch
Goal: Reduce lines of code in src/services/ by 30% while keeping all tests green
Metric: LOC count (lower is better)
Verify: npm test && find src/services -name "*.ts" | xargs wc -l | tail -1
```

### Pattern 5: "Content Factory"

Batch-produce content that meets quality gates.

```
/autoresearch
Goal: Write 20 blog post outlines, each with 5+ sections, 3+ internal link opportunities
Scope: content/outlines/*.md
Metric: outlines meeting criteria (higher is better)
Verify: node scripts/outline-validator.js
```

### Pattern 6: "Progressive Hardening"

Start lenient, tighten criteria as baseline improves.

```
/autoresearch
Goal: Phase 1 — all tests pass. Phase 2 — coverage >80%. Phase 3 — zero linting errors.
Advance to next phase only when current is stable for 3 consecutive iterations.
```

---

## Writing Verification Scripts

The skill works best when verification is **fast and mechanical**. Here's a template:

```javascript
// scripts/score-example.js — Template for custom scoring
const fs = require('fs');
const file = process.argv[2];
const content = fs.readFileSync(file, 'utf-8');

// Your scoring logic here
const score = content.split('\n').filter(l => l.startsWith('- ')).length;

// Output MUST be a single number on its own line for easy parsing
console.log(`SCORE: ${score}`);
process.exit(score > 0 ? 0 : 1);
```

**Rules for good verification:**

| Rule | Why |
|------|-----|
| Runs in under 10 seconds | Fast = more iterations = more experiments |
| Outputs a single parseable number | Claude needs to extract the metric mechanically |
| Exit code 0 = success, non-zero = crash | Clean pass/fail signal |
| No human judgment required | Agent must decide autonomously |
| Deterministic (same input = same output) | Non-deterministic metrics break the feedback loop |

---

## Core Principles

These 7 principles are extracted from [Karpathy's autoresearch](https://github.com/karpathy/autoresearch) and generalized to any domain:

### 1. Constraint = Enabler

Autonomy succeeds through intentional constraint, not despite it.

| Autoresearch | Generalized |
|---|---|
| 630-line codebase | Bounded scope that fits agent context |
| 5-minute time budget | Fixed iteration cost |
| One metric (val_bpb) | Single mechanical success criterion |

### 2. Separate Strategy from Tactics

Humans set direction (**what** to improve). Agents execute iterations (**how** to improve it).

| Strategic (Human) | Tactical (Agent) |
|---|---|
| "Improve page load speed" | "Lazy-load images, code-split routes" |
| "Increase test coverage" | "Add tests for uncovered edge cases" |
| "Refactor auth module" | "Extract middleware, simplify handlers" |

### 3. Metrics Must Be Mechanical

If you can't verify with a command, you can't iterate autonomously.

**Good:** `npm test -- --coverage | grep "All files"` → outputs `87.3%`

**Bad:** "Looks better", "probably improved", "seems cleaner" → kills the loop.

### 4. Verification Must Be Fast

| Fast (enables iteration) | Slow (kills iteration) |
|---|---|
| Unit tests (seconds) | Full E2E suite (minutes) |
| Type check (seconds) | Manual QA (hours) |
| Lint check (instant) | Code review (async) |

### 5. Iteration Cost Shapes Behavior

- **Cheap iteration** → bold exploration, many experiments
- **Expensive iteration** → conservative, few experiments

Autoresearch: 5-minute cost → 100 experiments/night.
Software: 10-second test → 360 experiments/hour.

### 6. Git as Memory

Every successful change is committed. Failures are reverted. This enables causality tracking, stacking wins, pattern learning, and human review.

### 7. Honest Limitations

If the agent hits a wall (missing permissions, external dependency, needs human judgment), it says so clearly instead of guessing.

---

## 8 Critical Rules

These rules govern Claude's behavior during the autonomous loop:

| # | Rule | Why |
|---|------|-----|
| 1 | **NEVER STOP** | Loop until manually interrupted. User may be asleep. |
| 2 | **Read before write** | Always understand full context before modifying. |
| 3 | **One change per iteration** | Atomic changes — if it breaks, you know exactly why. |
| 4 | **Mechanical verification only** | No subjective "looks good." Use metrics. |
| 5 | **Automatic rollback** | Failed changes revert instantly. No debates. |
| 6 | **Simplicity wins** | Equal results + less code = KEEP. Tiny gain + ugly complexity = DISCARD. |
| 7 | **Git is memory** | Every kept change committed. Agent reads history to learn patterns. |
| 8 | **When stuck, think harder** | Re-read files, combine near-misses, try radical changes. |

---

## Crash Recovery

Claude handles failures automatically:

| Failure Type | Response |
|---|---|
| Syntax error | Fix immediately, don't count as separate iteration |
| Runtime error | Attempt fix (max 3 tries), then move on |
| Resource exhaustion (OOM) | Revert, try smaller variant |
| Infinite loop / hang | Kill after timeout, revert, avoid that approach |
| External dependency failure | Skip, log, try different approach |

---

## Repository Structure

```
autoresearch/
├── README.md                                          ← You are here
├── LICENSE                                            ← MIT License
└── skills/
    └── autoresearch/
        ├── SKILL.md                                   ← Main skill (loaded by Claude Code)
        └── references/
            ├── autonomous-loop-protocol.md            ← Detailed 8-phase loop protocol
            ├── core-principles.md                     ← 7 universal principles
            └── results-logging.md                     ← TSV tracking format + reporting
```

---

## About Karpathy's Autoresearch

[Autoresearch](https://github.com/karpathy/autoresearch) is Andrej Karpathy's framework for autonomous ML research. Key insights:

- **630 lines of Python** — intentionally small so an LLM can hold the entire codebase in context
- **One GPU, one file, one metric** — constraints enable autonomy
- **5-minute training runs** — cheap iterations mean bold experiments
- **100 experiments per night** — compound gains while humans sleep
- **Git as memory** — every experiment tracked, successes committed, failures reverted

**Claude Autoresearch takes these principles and generalizes them.** Instead of training ML models, Claude can autonomously iterate on:

- Code quality (tests, coverage, performance, bundle size)
- Content quality (readability, SEO, keyword density)
- Documentation (completeness, clarity, compliance)
- Any task where "better" = a number you can measure with a command

The meta-principle:

> Autonomy scales when you constrain scope, clarify success, mechanize verification, and let agents optimize tactics while humans optimize strategy.

---

## FAQ

**Q: Does this work with any Claude Code project?**
A: Yes. Copy the skill to `.claude/skills/autoresearch/` in any project. It works with any language, framework, or domain.

**Q: How do I stop the loop?**
A: Press `Ctrl+C` or close the terminal. Claude commits before verifying, so your last successful state is always preserved in git.

**Q: What if my verification takes too long?**
A: Aim for under 10 seconds. Longer verification = fewer experiments = slower progress. Use the fastest check that still catches real problems.

**Q: Can I use this for non-code tasks?**
A: Absolutely. Sales emails, marketing copy, HR policies, runbooks — anything with a measurable metric. See the examples above.

**Q: What happens if Claude gets stuck?**
A: After 5+ consecutive discards, Claude automatically: re-reads all files, reviews the results log for patterns, tries combining near-misses, attempts the opposite of what hasn't been working, and tries radical changes.

**Q: Is the results log committed to git?**
A: No. Add `autoresearch-results.tsv` to `.gitignore`. It's a working file for the agent, not part of your codebase.

**Q: Can I review what Claude did?**
A: Yes. Every kept change is a git commit with a descriptive message. Run `git log --oneline` to see the full history of experiments.

---

## Contributing

Contributions welcome! Open an issue or PR.

Areas of interest:
- New domain examples (data science, design, DevOps, etc.)
- Better verification script templates
- Integration with CI/CD pipelines
- Performance benchmarks from real-world usage

---

## License

MIT — see [LICENSE](LICENSE).

---

## Credits

- **[Andrej Karpathy](https://github.com/karpathy)** — for [autoresearch](https://github.com/karpathy/autoresearch) and the insight that constraint + metric + iteration = compounding gains
- **[Anthropic](https://anthropic.com)** — for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) and the skills system that makes this possible

---

## About the Author

<a href="https://udit.co">
  <img src="https://avatars.githubusercontent.com/uditgoenka" width="100" align="left" style="margin-right: 16px; border-radius: 50%;" alt="Udit Goenka" />
</a>

**[Udit Goenka](https://udit.co)** — AI Product Expert, Founder & Angel Investor

Self-taught builder who went from a slow internet connection in India to founding multiple companies and helping 700+ startups generate over ~$25m in revenue.

<br clear="left" />

### What I'm Building

- **[TinyCheque](https://tinycheque.com)** — India's first agentic AI venture studio, building [seoengine.ai](https://seoengine.ai), [autoposting.ai](https://autoposting.ai), [niyam.ai](https://niyam.ai), and [qcall.ai](https://qcall.ai)
- **[Firstsales.io](https://firstsales.io)** — Sales automation platform

### Angel Investing

38 startups backed, 6 exits. Focused on early-stage AI and SaaS founders.

### Connect

- **Website:** [udit.co](https://udit.co)
- **Twitter/X:** [@iuditg](https://x.com/iuditg)
- **GitHub:** [@uditgoenka](https://github.com/uditgoenka)
- **Newsletter:** [udit.co/blog](https://udit.co/blog) — AI news, product building, and startup insights

### Why I Built This

I use Claude Code daily to build products across all my ventures. When I saw Karpathy's autoresearch, I realized the same principles could make Claude Code dramatically more productive for **any** domain — not just ML research. Claude Autoresearch is how I let Claude work autonomously on tasks while I focus on strategy.

> *"Autonomy scales when you constrain scope, clarify success, mechanize verification, and let agents optimize tactics while humans optimize strategy."*
