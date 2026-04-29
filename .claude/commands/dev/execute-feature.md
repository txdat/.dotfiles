---
model: sonnet
effort: medium
---

# /execute-feature — Implement the Approved Plan

Find plan from $ARGUMENTS or status `approved`/`in-progress`. Set `in-progress`. Read `CLAUDE.md`.
Partial: `<name> from <N>` → start at N; `<name> <N>` → run only N. No `// TODO` — if blocked, say so.

## Dependency Analysis

Independent (different files, no shared state) → parallel. Sequential (shared files/deps) → ordered.
Agent: `rapid-coder` if pattern exists, no edge cases, no security; else `dedicated-coder`.

## TDD Execution

Phases in order: RED → GREEN → BLUE.

**RED** (sequential, selected agent): feature/fix → write test, confirm FAILS `🔴`; refactor → confirm existing tests PASS first.

**GREEN** (selected agent): ≤3 steps or all sequential → run inline. Otherwise write `/tmp/claude-ctx-<slug>.md`:
```
Plan: <path> | Stack: <detected> | Standards: <CLAUDE.md>
Constraints: ONLY assigned steps. No TODO. Run ONLY assigned tests. Scope creep → STOP.
```
Spawn per batch: "Read /tmp/claude-ctx-<slug>.md. Steps: N,M. Files: <list>. Off-limits: <others>. Tests: <names>. Report: completed, passing, coverage%, blockers." → `🟢 Step N: <done> (coverage: X%)`

**BLUE** (after all GREEN steps, inline): selected agent refactors → `code-quality-auditor` verifies no behavior changes `🔵`

### Per-step Test Scope (GREEN + BLUE)

Scope tests and coverage to changed files only — never the full suite.
For each file in the current step, derive `<stem>` (filename without extension): `fd -t f '<stem>' | rg 'test|spec'` to find by name; fallback: `rg -l '(import|require|#include).*<stem>'` in test dirs. If none found, skip coverage for that file.

| Stack | Command |
|---|---|
| Maven | `mvn test -pl <mod> -Dtest=<Class>` |
| Go | `go test -run <TestName> -coverprofile=c.out ./<pkg>/... && go tool cover -func=c.out \| grep <changed_file>` |
| Python | `pytest <test_files> -q --cov=<changed_module> --cov-report=term-missing` |
| TS/Jest | `npm test -- --testPathPattern=<test_file> --coverage --coverageReporters=text --collectCoverageFrom='["<changed_file>"]'` |
| C++ | `cmake -DCMAKE_CXX_FLAGS=--coverage .. && ctest --test-dir build -R <test>` then `gcov -n <changed_src>` (GCC) or `llvm-cov report <bin> --sources <changed_src>` (Clang) |

## Scope Creep

Discovered work → STOP. Log in `## Discovered Scope` with estimated effort. Ask: include / separate / skip?

## Completion

All `[x]` → lint + build + tests → status `implemented` → suggest `/dev:review-code`.
