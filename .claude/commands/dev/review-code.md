---
model: sonnet
effort: medium
---

# /review-code — Code Change Review

If `skip approval` context — auto-fix blocking issues without asking.

Find active plan in `docs/plans/`. Read plan + `CLAUDE.md`. If none, ask for scope.

Run: `git diff main --stat`, `git diff main`, `git log main..HEAD --oneline`.

Review sequentially in three phases:

**Phase A — Correctness + TDD**: matches plan, edge cases, no silent exceptions; tests before impl, failure paths covered

**Phase B — Architecture + Data**: CLAUDE.md layering, no framework leaks; parameterized queries, transactions, concurrency

**Phase C — Scope + Hygiene**: out-of-plan changes; debug logs, TODOs, secrets

For each phase report: blocking (File:Line — issue — why — fix), non-blocking, positives.

## Output

```
## Code Review Report
### Summary
### ✅ What's Good
### ❌ Blocking (fix before PR)
### ⚠️ Non-blocking
### 🧪 TDD Check
### 🔍 Scope Check
### Verdict: PASS | PASS WITH NOTES | REWORK REQUIRED
```

REWORK → offer inline fixes. PASS → update plan to `reviewed`.
