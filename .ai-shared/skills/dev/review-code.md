# /review-code — Code Change Review

**Scope (locked):** Design is FIXED. Review only whether the code faithfully implements the approved plan, plus code-level correctness, security, and quality. Do NOT re-evaluate requirements, scope, or design decisions — those are owned by review-feature. A genuine plan defect the code surfaces → record under `### ⚠️ Plan Defect (out of band)` and recommend re-running review-feature; never block code review on design grounds.

Resolve the session's active plan (expects status `implemented`): an explicit `docs/plans/<file>.md` (or its slug) in $ARGUMENTS pins it; otherwise the session's pinned plan, else the lone active plan. 0 or 2+ active and none named → STOP, ask which (or run `design-feature`/`fix-bug` first). Read plan + project config file (CLAUDE.md/CODEX.md/GEMINI.md/AGENTS.md).

Resolve `<base>` and `<worktree>` per CORE. Run inside `<worktree>`: `git -C <worktree> diff <base> --stat`, `git -C <worktree> diff <base>`, `git -C <worktree> log <base>..HEAD --oneline`.

Review in three sequential phases. For each phase: note positives, flag blocking issues, classify non-blocking items.

**Phase A — Correctness + TDD**: code faithfully implements the plan; edge cases handled; no silent exceptions; failure paths covered. If plan has `## Test Cases`: every TC has a corresponding test (matched by `<test_fn_name>`); each test's setup/call/assertion aligns with the TC's Given/When/Then; no additional behavioral test cases beyond plan TCs unless logged in `## Discovered Scope`. Each test meets coverage.md's quality bar — it would fail if its named behavior broke; hollow tests (assert-nothing, trivial asserts, mock-call-only, implementation-mirroring expectation) → `❌ hollow test — <file:line>` (blocking). Every call, field access, and import resolves to a member of its target type/module per EXEC_CORE `Verify symbol membership`; unresolved → `❌ <file:line> — <receiver_type>.<symbol> not a member`. **TDD proof** (verify CORE #4 from history): `git -C <worktree> log <base>..HEAD --oneline` must show, per slice, the proof commit preceding that slice's impl commit(s) — `test(red)` with a tests-only diff (feature/fix; single PR is one pair, chain one per slice) or passing `test: baseline` (refactor). Absent, out of order, or containing implementation → `❌ RED/baseline skipped — no valid proof commit precedes impl` (blocking).

**Phase B — Architecture + Data**: project config layering respected; no framework leaks; context boundaries respected (no domain concepts leaking across); parameterized queries; transactions and concurrency correct; non-functional commitments met per plan's `### Non-functional` (authz/data exposure, observability hooks, statically-detectable performance regressions — N+1, unbounded queries, missing pagination — against the stated budget)

**Phase C — Scope + Hygiene**: no out-of-plan changes except those recapped in `## Deviations` (verify each carries Plan said / Doing instead / Why / Tradeoff — unlogged divergence → `❌`); no debug logs, stray TODOs, or secrets

Blocking item format: `File:Line — issue — why it matters — required fix`

Non-blocking item format — classify each:
- **Should fix**: style drift, minor correctness risk, maintainability debt — include suggested fix
- **Skip**: negligible impact, intentional trade-off, or out of scope — include reason

Verdict rules:
- **REWORK REQUIRED**: any blocking items exist
- **PASS WITH NOTES**: no blocking items, but has one or more "Should Fix" items
- **PASS**: no blocking items, no "Should Fix" items

## Self-Check (BLOCKING — do NOT emit verdict until every item is ✅)

Run this audit before the final output. If ANY blocking item is unchecked → verdict is REWORK REQUIRED.

- [ ] **Phase A — TDD proof** (Phase A): per slice, `test(red)` (feature/fix) or `test: baseline` (refactor) precedes that slice's impl commit(s), diff tests-only. Missing: __.
- [ ] **Phase A — TC coverage** (Phase A): every plan TC has an aligned test (`<test_fn_name>`, Given/When/Then). Missing/misaligned: __.
- [ ] **Phase A — No extra TC** (Phase A): no behavioral tests beyond plan TCs unless in `## Discovered Scope`. Extras: __.
- [ ] **Phase A — Test quality** (Phase A, coverage.md quality bar): every test fails if its named behavior breaks. Hollow: __.
- [ ] **Phase A — Symbol membership** (Phase A, EXEC_CORE `Verify symbol membership`): every call/field/import resolves. Unresolved: __.
- [ ] **Phase B — Architecture + Data** (Phase B): layering, boundaries, parameterized queries, transactions/concurrency, non-functional commitments. Violations: __.
- [ ] **Phase C — Scope** (Phase C): no out-of-plan changes except those in `## Deviations` (Plan said / Doing instead / Why / Tradeoff). Unlogged: __.
- [ ] **Phase C — Hygiene** (Phase C): no debug logs, stray TODOs, or secrets. Issues: __.
- [ ] **PR Pattern finalization** (Post-report PASS): diff compared against `## PR Pattern (provisional)`; slices match → `(provisional)` removed, else revised slices proposed; missing → REWORK. Status: __.

If ANY ❌ → verdict REWORK REQUIRED. If zero ❌ but has Should Fix items → PASS WITH NOTES. If zero ❌ and zero Should Fix → PASS.

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
### ⚠️ Plan Defect (out of band)
(design issues the code surfaced — does not affect verdict; recommend re-running review-feature)
### Verdict: PASS | PASS WITH NOTES | REWORK REQUIRED
```

## Post-report actions

- **REWORK**: offer inline fixes for blocking items; wait for approval before applying.
- **PASS WITH NOTES**: present each "Should Fix" item; ask which to fix and which to skip; wait for approval before touching any. Once every "Should Fix" item is fixed or explicitly skipped (only "Skip" suggestions remain) → proceed as PASS.
- **PASS**: finalize PR Pattern *first* — compare the diff against `## PR Pattern (provisional)` in the plan: slices match → remove `(provisional)` and save; scope drifted → propose revised slices, wait for approval, update and save; missing PR Pattern → REWORK REQUIRED. Only once finalization is complete → set status `reviewed` in the worktree's plan copy (with the finalized PR Pattern) and commit it: `git -C <worktree> add docs/plans/<file>.md && git -C <worktree> commit -m "docs(<scope>): review passed"`. Print: "Review passed. Run the recap skill."
