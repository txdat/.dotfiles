# /fix-bug — Structured Bug Diagnosis and Approved Fix Execution

Modes: `diagnose <symptom>` is read-only and stops after root-cause evidence; `execute docs/plans/<fix-plan>.md` implements an already reviewed and human-approved fix plan. There is no diagnose-and-mutate or request-as-approval mode.

## Diagnose

Collect symptom, expected behavior, reproduction, approximate onset, and relevant issue if one exists. Resolve `<base>` and inspect recent commits plus `git diff <base> --stat`; do not create branches, plans, tests, or code.

Generate 3–5 ranked hypotheses. Investigate sequentially when ≤2; otherwise delegate independent evidence collection to parallel `code-explorer` agents, one per hypothesis — explorers return file:line evidence, never verdicts. The main agent rules each hypothesis CONFIRMED/ELIMINATED/INCONCLUSIVE with confidence and its supporting evidence.

Select the highest-confidence confirmed cause; none confirmed → deepen the best inconclusive; all eliminated → regenerate. Report:

```text
Root Cause: <file:line — condition>
Mechanism: <why it produces the symptom>
Gap: <why existing safeguards missed it>
Expected outcome source: <goal, contract, domain rule, or explicit unknown>
Rejected: <hypothesis> — <evidence>
```

Stop here. Offer to pass the diagnosis into design-feature. The fix plan must preserve the user's Goal, derive ACs/TCs, pass review-feature, and clear `approval.md`'s pause.

## Execution Gate

`execute` requires a `Type: fix` plan in `approved` or `in-progress` state. `gate-check` owns issue, worktree, and status. A missing or unapproved plan, or one whose Goal/Scope does not match the diagnosis → STOP.

Use `worktree.md` with branch `fix/<slug>` from `<base>`. Record the worktree, copy the plan, and set `Status: in-progress`.

## Execute Fix

Read `tdd.md`. Delegation, if any, follows execute-feature's `## Strategy` — a root-cause fix is a critical step (`senior-engineer`). Apply these bug-specific steps:

1. Use the approved regression TC; do not add, edit, merge, or weaken behavior during execution.
2. Implement its Given/When/Then test, prove failure comes from the diagnosed bug, commit `test(red): <bug>`, and run `dev-check proof <commit>` before implementation.
3. Verify symbols against target types/modules. Apply the smallest root-cause fix that satisfies the parent AC for all valid inputs; commit separately and verify reproduction plus targeted module tests.
4. Read `coverage.md`, measure changed files, and run `dev-check coverage <percent> [uncovered-critical]`. The regression test must assert the buggy branch; otherwise coverage is ❌ regardless of percentage.
5. Follow `dependents.md` for changed externally reachable symbols. Breakage or unresolved reachability → STOP and re-plan.
6. Run `dev-check artifacts <base> HEAD`. Confirm the executed test still matches its approved TC and parent AC.

If diagnosis, RED evidence, or implementation exposes a conflict among Goal, AC, TC, another TC, or a domain contract: STOP and go back through `approval.md`. Never correct approved behavior silently.

Append execution evidence without changing approved semantics:

```text
### Fix: <date> — <symptom>
Cause: <file:line> | AC: <AC-N> | TC: <TC-N/test> | Change: <what> | Callers: <checked/fixed>
```

## Self-Check (BLOCKING)

- [ ] **Diagnosis/regression:** root cause is evidence-backed; the test asserts the actual buggy branch and exactly implements an approved TC and its AC.
- [ ] **Correctness:** fix satisfies Goal and parent AC for all valid inputs; symbols resolve; no fake implementation, hollow test, or debug artifact.
- [ ] **Coverage/dependents:** changed files satisfy CORE #6 or have accepted logged gaps; dependent evidence is complete and open breakage was STOP-asked.
- [ ] **Approval/scope:** no behavior changed during execution; contradictions went back through `approval.md`; evidence and PR Pattern are complete.

All checked → set the worktree plan to `implemented`, commit `docs(<scope>): mark plan implemented`, and emit: `Bug fix implementation complete. Run review-code for independent AC verification.`
