---
model: sonnet
effort: high
---

# /execute-feature — Implement the Approved Plan

Find plan from $ARGUMENTS or by status `approved`/`in-progress`. Set `in-progress`. Read `CLAUDE.md`.

Partial: `<name> from <N>` starts at N; `<name> <N>` runs only N. No `// TODO` — if blocked, say so.

## Dependency Analysis

Independent (different files, no shared state) → parallel batch. Sequential (shared files/deps) → ordered.

Agent: `rapid-coder` if pattern exists, no edge cases, no security. Otherwise `dedicated-coder`.

## TDD Execution

**RED** (sequential): feature/fix → write test, confirm FAILS `🔴`; refactor → confirm existing PASS `🔴`

**GREEN**: ≤3 steps or all sequential → main agent. Otherwise write `/tmp/claude-ctx-<slug>.md`:
```
Plan: <path> | Stack: <detected> | Standards: <CLAUDE.md>
Constraints: ONLY assigned steps. No TODO. Run ONLY assigned tests. Scope creep → STOP.
```
Spawn per batch: "Read /tmp/claude-ctx-<slug>.md. Steps: N,M. Files: <list>. Off-limits: <others>. Tests: <names>. Report: completed, passing, blockers." → `🟢 Step N: <done>`

**BLUE**: remove duplication, simplify — no behavior changes `🔵`

Test commands: Maven `mvn test -pl <mod> -Dtest=<Class>` · Go `go test ./<pkg>/...` · Python `pytest <path> -q` · TS `npm test -- --testPathPattern=<file>`

## Scope Creep

Discovered work → STOP. Log in `## Discovered Scope` with size. Ask: include / separate / skip?

## Completion

All `[x]` → lint + build + tests → status `implemented` → suggest `/dev:review-code`.
