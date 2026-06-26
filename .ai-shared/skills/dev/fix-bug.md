# /fix-bug — Structured Bug Fix

Modes: `<symptom>` full fix; `diagnose <symptom>` stops before code.

Collect: symptom, expected, repro steps. Resolve `<base>` per CORE. Run `git log --oneline -20` and `git diff <base> --stat`.

## Hypothesis Investigation

Generate 3–5 hypotheses ranked by likelihood. ≤2 → investigate sequentially.

Otherwise write `/tmp/ai-ctx/<slug>.md`:
```
Symptom: <description> | Expected: <behavior>
Stack trace: <if any>
Recent changes: <git log + diff summary>
```

Spawn `code-explorer` per hypothesis — prompt: "Read /tmp/ai-ctx/<slug>.md. Investigate: `<hypothesis>`. Return: Verdict (CONFIRMED|ELIMINATED|INCONCLUSIVE), Confidence (high|med|low), Evidence ([+] supports / [-] contradicts, each file:line), Reasoning (1 sentence)."

Select: highest-confidence CONFIRMED. None CONFIRMED → re-investigate top INCONCLUSIVE with deeper scope. All ELIMINATED → regenerate hypotheses.

```
Selected: <hypothesis> | Verdict: <V> | Confidence: <C>
Evidence: <top [+] clues>
Rejected: <H> — <reason file:line>
```

## Root Cause

```
Root Cause: <file:line — condition>
Why: <mechanism>
Gap: <why missed>
```

`diagnose` mode → stop, ask "Proceed with fix?"

## Fix

**Approval Gate (BLOCKING):** resolve the session's active plan — an explicit `docs/plans/<file>.md` path in $ARGUMENTS pins it (slug matching is NOT used here, since the symptom is free text); otherwise the session's pinned plan, else the lone active plan. If a plan is active and its `Status:` is `planning`/`blocked-by-architecture`, STOP — ask the user to approve it manually (set `Status: approved`) before the fix appends to it, or to drop the stale plan to run planless. If the active plan is already `reviewed`/`recapped`/`archived`, STOP — do not append a fix after review or shipping; either resume with a different active plan or run planless. No active plan → planless, proceed (fix-bug creates its own plan at the end).

Bugs are single-PR. Branch first from `<base>` (never commit to `<base>` itself): `git checkout -b fix/<slug> <base> 2>/dev/null || git checkout fix/<slug>`; on resume, if it exists, verify `git merge-base --is-ancestor <base> fix/<slug>` — non-zero → STOP `❌ fix/<slug> not based on <base>`.

0. **Symbol check** — every call, field access, and import in the patch must be a member of its target type/module per CORE `Verify symbol membership`. Unresolved → STOP, ask, wait.
1. **Regression test first (RED)** — write the failing test that reproduces the bug. Active plan → append a new TC (Given: trigger conditions; When: action; Then: expected non-buggy behavior; Verifies: invariant the bug violated) and implement it using the TC's `<test_fn_name>`; otherwise name it `should_not_<bug>_when_<trigger>`. Confirm `🔴`: failure must come from the bug itself, not a bad assertion. Commit before the fix: `git add <test-files> && git commit -m "test(red): <bug>"` (skip if it already exists — resume).
2. **Minimal fix (GREEN)** — root cause only; remove any `// DEBUG` temp logs before committing. Confirm `🟢`: correct for all valid inputs — no hardcoded returns or special-casing of test input; violation → STOP, report fake impl, wait for explicit guidance. Stage + commit: `git add <impl-files> && git commit -m "fix(<scope>): <summary>"`.
3. **Verify** — repro + module tests pass. Coverage on changed files (see the execute-feature skill for stack commands):
   - `≥ 95%` → `✅ pass`
   - `90%–94%` → `⚠️` — log uncovered lines in `## Coverage Gaps` (plan) or the fix report (planless), continue
   - `< 90%` → `❌` — log in `## Coverage Gaps` (plan) or the fix report (planless) with reason (untestable/generated code, unreachable branches, external deps), then STOP — ask: fix now / accept gap / split
4. **Dependents** — for each changed symbol: `rg -n '<symbol>' --type <lang> . | rg -v 'test|spec|_test'`; confirm no caller depends on old signature or behavior; output `✅ <file:line>` or `❌ <file:line> — <what broke>`; any `❌` → fix inline before proceeding; record affected callers in the Fix block (Callers field)

Plan exists → append the Fix block and set status `implemented` (so review-code picks it up):
```
### Fix: <date> — <symptom>
Cause: <file:line> | Change: <what> | Test: <name> | Callers: <count> checked, <count> fixed
```
No active plan → create `docs/plans/<basename>_<date>_fix_<slug>.md` with status `implemented`, the Root Cause/Fix summary, the regression TC, affected tests, and the finalized PR Pattern. If the plan has no `## PR Pattern`, append a finalized one (`Type: single`, branch `fix/<slug>`) so create-pr targets the existing branch instead of deriving a new one.

## Self-Check (BLOCKING — do NOT emit completion until every item is ✅)

Run this audit before the final output. If ANY item is unchecked → STOP, fix, re-check.

- [ ] **RED gate** (Fix step 1): a `test(red): <bug>` commit holds the failing regression test only. Present: yes/no.
- [ ] **Symbol membership** (Fix step 0, CORE `Verify symbol membership`): ran on every call/field/import in the patch. Unresolved: __.
- [ ] **No fake fix** (Fix step 2): re-read the fix — correct for all valid inputs, no hardcoded returns or test-input special-casing. Offenders: __.
- [ ] **Coverage** (Fix step 3 thresholds): changed files ✅ / ⚠️ logged / ❌ resolved. Result: __%.
- [ ] **Dependents** (Fix step 4): every changed symbol checked against callers; each ❌ resolved. Open: __.
- [ ] **Branch ancestry** (`## Fix`): `git merge-base --is-ancestor <base> fix/<slug>` returns 0. Verified: yes/no.
- [ ] **No debug artifacts** (Fix step 2): no `// DEBUG`, `console.log`, `print(` temp logs in the fix diff. Found: __.
- [ ] **Plan handoff**: fix plan exists, status `implemented`, Fix block present, PR Pattern finalized.

If ALL checked → emit "Bug fix complete. Run the review-code skill."
