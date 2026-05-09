# /review-code — Code Change Review

If `skip approval` context — auto-fix blocking issues without asking.

Find active plan in `docs/plans/`. Read plan + project config file (CLAUDE.md/CODEX.md/GEMINI.md/AGENTS.md). If no plan found, ask for scope before proceeding.

Resolve `<base>` per GUIDELINES. Run: `git diff <base> --stat`, `git diff <base>`, `git log <base>..HEAD --oneline`.

Review in three sequential phases. For each phase: note positives, flag blocking issues, classify non-blocking items.

**Phase A — Correctness + TDD**: matches plan; edge cases handled; no silent exceptions; failure paths covered; tests exist for new logic

**Phase B — Architecture + Data**: project config layering respected; no framework leaks; parameterized queries; transactions and concurrency correct

**Phase C — Scope + Hygiene**: no out-of-plan changes; no debug logs, stray TODOs, or secrets

Blocking item format: `File:Line — issue — why it matters — required fix`

Non-blocking item format — classify each:
- **Should fix**: style drift, minor correctness risk, maintainability debt — include suggested fix
- **Skip**: negligible impact, intentional trade-off, or out of scope — include reason

Verdict rules:
- **REWORK REQUIRED**: any blocking items exist
- **PASS WITH NOTES**: no blocking items, but has one or more "Should Fix" items
- **PASS**: no blocking items, no "Should Fix" items

## Output

```
## Code Review Report
### Summary
(2–3 sentences: what changed, overall quality signal, verdict rationale)
### ✅ What's Good
### ❌ Blocking (fix before PR)
### ⚠️ Non-blocking
#### Should Fix
#### Skip
### Verdict: PASS | PASS WITH NOTES | REWORK REQUIRED
```

## Post-report actions

- **REWORK**: offer inline fixes for blocking items; wait for approval before applying.
- **PASS WITH NOTES**: present each "Should Fix" item; ask which to fix and which to skip; wait for approval before touching any.
- **PASS**: update plan status to `reviewed`.
