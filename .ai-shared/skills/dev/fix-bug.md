# /fix-bug — Structured Bug Fix

Modes: `<symptom>` full fix; `diagnose <symptom>` stops before code.

Collect: symptom, expected, repro steps. Resolve `<base>` per CORE. Run `git log --oneline -20` and `git diff <base> --stat`.

## Hypothesis Investigation

Generate 3–5 hypotheses ranked by likelihood. ≤2 → investigate sequentially.

Otherwise write `/tmp/ai-ctx-<slug>.md`:
```
Symptom: <description> | Expected: <behavior>
Stack trace: <if any>
Recent changes: <git log + diff summary>
```

Spawn `code-explorer` per hypothesis — prompt: "Read /tmp/ai-ctx-<slug>.md. Investigate: `<hypothesis>`. Return: Verdict (CONFIRMED|ELIMINATED|INCONCLUSIVE), Confidence (high|med|low), Evidence ([+] supports / [-] contradicts, each file:line), Reasoning (1 sentence)."

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

Bugs are single-PR. Branch first from `<base>` (never commit to `<base>` itself): `git checkout -b fix/<slug> <base> 2>/dev/null || git checkout fix/<slug>`; on resume, if it exists, verify `git merge-base --is-ancestor <base> fix/<slug>` — non-zero → STOP `❌ fix/<slug> not based on <base>`.

0. **Symbol check** — every call, field access, and import in the patch must be a member of its target type/module per CORE `Verify symbol membership`. Unresolved → STOP, ask, wait.
1. **Regression test first (RED)** — write the failing test that reproduces the bug. Active plan → append a new TC (Given: trigger conditions; When: action; Then: expected non-buggy behavior; Verifies: invariant the bug violated) and implement it using the TC's `<test_fn_name>`; otherwise name it `should_not_<bug>_when_<trigger>`. Confirm `🔴`: failure must come from the bug itself, not a bad assertion. Commit before the fix: `git add <test-files> && git commit -m "test(red): <bug>"` (skip if it already exists — resume).
2. **Minimal fix (GREEN)** — root cause only; remove any `// DEBUG` temp logs before committing. Confirm `🟢`: correct for all valid inputs — no hardcoded returns or special-casing of test input; violation → STOP, report fake impl, wait for explicit guidance. Stage + commit: `git add <impl-files> && git commit -m "fix(<scope>): <summary>"`.
3. **Verify** — repro + module tests pass. Coverage on changed files (see the execute-feature skill for stack commands):
   - `≥ 95%` → `✅ pass`
   - `90%–94%` → `⚠️` — log uncovered lines in fix log, continue
   - `< 90%` → `❌` — log in fix log with reason (untestable/generated code, unreachable branches, external deps), then STOP — ask: fix now / accept gap / split
4. **Dependents** — for each changed symbol: `rg -n '<symbol>' --type <lang> . | rg -v 'test|spec|_test'`; confirm no caller depends on old signature or behavior; output `✅ <file:line>` or `❌ <file:line> — <what broke>`; any `❌` → fix inline before proceeding; append affected callers to fix log entry

Plan exists → append the Fix block and set status `implemented` (so review-code picks it up):
```
### Fix: <date> — <symptom>
Cause: <file:line> | Change: <what> | Test: <name> | Callers: <count> checked, <count> fixed
```

Output: "Bug fix complete. Run the review-code skill."
