# /execute-feature — Implement the Approved Plan

Resolve the active plan per CORE. Entry status is `approved` or `in-progress`; `gate-check` owns plan/issue/status. Read the Goal, every AC and TC, the plan, and project AI config. `$ARGUMENTS`: `<plan> [from N|N]`; partial execution must preserve dependency order. No TODO placeholders.

## Setup

Use `worktree.md` exactly. Bind `<slug>` from the plan filename; single branch `<type>/<slug>`, chain branches `<type>/<slug>-k`; first parent `<base>`, later chain parent the preceding branch. Never commit to `<base>` or edit the main-tree locator after copying it.

Once the worktree copy exists, set `Status: in-progress` and commit `docs(<scope>): start plan execution` before proof. Plan edits are separate from proof commits and otherwise accompany the code they describe.

## Strategy

Execute inline by default. Delegate only when more than three steps are genuinely independent with exclusive source/test files. Route by step, not by convenience: critical steps → `senior-engineer`; simple, well-patterned steps → `junior-engineer`. Workers receive the Goal, owning ACs, TCs, steps, critical invariants, file ownership, and off-limits paths, and may neither edit plans nor run Git. The main agent verifies the resulting file union, reruns the union of targeted tests and coverage, and alone commits.

Security, concurrency, or data-integrity steps are critical: state invariants and failure modes before editing, whether inline or delegated.

## RED → GREEN → BLUE

Read and follow `tdd.md` (single source). The approved Goal → AC → TC spec is the oracle; TDD consumes it and may not invent or reinterpret behavior. For a single PR, execute all TCs as one proof/GREEN unit. For a chain, process slices sequentially in PR-Pattern order; each slice gets its own branch and proof/GREEN pair scoped to the TCs wholly owned by that slice.

Before each GREEN:

1. Verify each new call, field access, and import against its target type/module per EXECUTION_CORE.
2. Run `dev-check proof <commit> [--test <in-source-test-path>] [--stub <throwing-stub-path>]`.
3. Commit implementation separately after its targeted tests pass. Any test-input special case or hardcoded expected-value table is a fake implementation → STOP and report.

After all GREEN work, perform BLUE as defined in `tdd.md`: inspect for worthwhile simplification and refactor only when beneficial. If BLUE changed any file, rerun its targeted tests and coverage and have `code-quality-auditor` verify behavior is unchanged; "no refactor needed" is a valid outcome and needs no dispatch.

## Verification

For every changed file, derive targeted tests using project conventions, semantic references, then filename/import search. No test found → log a Coverage Gap and STOP: return through design/review and re-approval for a new TC, accept a stated gap, or split. Never add unapproved behavior and never run the full suite unless EXECUTION_CORE permits it.

At first scoring read `coverage.md`. Measure touched/changed files, run `dev-check coverage <percent> [uncovered-critical]`, and apply CORE #6 judgment. Log every ⚠️/❌ in `## Coverage Gaps`; ❌ → STOP and ask. Coverage-driven new behavior must enter through a reviewed, re-approved plan TC.

After GREEN/BLUE, follow `dependents.md` for every changed externally reachable symbol. Breakage or unresolved reachability → log `## Discovered Scope`, STOP, and ask: re-plan/re-review, separate, or narrow via a recorded CORE #5 deviation. Never ship a known-broken caller.

Run lint, build, the TC tests, and `## Affected Existing Tests`. Root-cause failures: regression → fix implementation; incomplete implementation → finish its step. A conflict among Goal, AC, TC, domain contract, or observed intended behavior is not a free deviation: STOP and go back through `approval.md`. Run `dev-check artifacts <base> HEAD`.

Scope discovered beyond the approved plan follows CORE #7. Including it requires design-feature, review-feature, and `approval.md`'s pause again. Divergence of means within unchanged behavior follows CORE #5; any behavior change goes back through `approval.md`.

## Self-Check (BLOCKING)

- [ ] **Behavior:** every TC is implemented, its parent AC and the Goal are satisfied, and targeted/affected tests, lint, and build pass; failures were root-caused.
- [ ] **Symbols and implementation:** all new symbols resolve; no fake implementation or hollow test. Issues: __.
- [ ] **Coverage:** each changed file is ✅ or ⚠️ logged; no unresolved ❌; BLUE-touched files remeasured. Gaps: __.
- [ ] **Dependents:** evidence blocks complete; breakage/unknowns were STOP-asked. Open: __.
- [ ] **Scope:** all deviations have four CORE #5 fields; discoveries follow CORE #7. Open: __.
- [ ] **Delegation, if used:** exclusive ownership held; main agent verified file union and reran combined tests/coverage. Violations: __.

All checked → set the worktree plan to `implemented`, commit `docs(<scope>): mark plan implemented`, and print: `Implementation complete. Run review-code for independent AC verification.` Surface non-empty Coverage Gaps and Deviations.
