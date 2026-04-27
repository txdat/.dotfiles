---
model: sonnet
effort: high
---

# /fix-bug — Structured Bug Fix

Modes: `<symptom>` full fix; `diagnose <symptom>` stops before code.

Collect: symptom, expected, repro steps. Run `git log --oneline -20` and `git diff main --stat`.

## Hypothesis Investigation

Generate 3–5 hypotheses ranked by likelihood. ≤2 → investigate sequentially.

Otherwise write `/tmp/claude-ctx-<slug>.md`:
```
Symptom: <description> | Expected: <behavior>
Stack trace: <if any>
Recent changes: <git log + diff summary>
```

Spawn `code-explorer` per hypothesis — prompt: "Read /tmp/claude-ctx-<slug>.md. Investigate: `<hypothesis>`. Return: Verdict (CONFIRMED|ELIMINATED|INCONCLUSIVE), Confidence (high|med|low), Evidence ([+] supports / [-] contradicts / [?] unclear, each file:line), Reasoning (1 sentence)."

**Scoring**: `(2×[+] − 2×[-] + 0.5×[?]) × confidence` (high=1.5, med=1, low=0.5)

Select: CONFIRMED + score ≥4 → highest. No CONFIRMED → deeper on INCONCLUSIVE ≥2. All low → regenerate.

```
Selected: <hypothesis> | Score: <N> = <breakdown>
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

1. **Minimal** — root cause only
2. **Debug** — `// DEBUG` for temp logs; remove before commit
3. **Verify** — repro + module tests
4. **Regression** — `should_not_<bug>_when_<trigger>`; fails unfixed, passes fixed

Append to plan if exists:
```
### Fix: <date> — <symptom>
Cause: <file:line> | Change: <what> | Test: <name>
```

Output: "Bug fix complete. Run /dev:review-code."
