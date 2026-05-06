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

**Coverage** (per GREEN/BLUE step):
- `≥ 95%` → `✅ pass`
- `90%–94%` → `⚠️` — log uncovered lines in `## Coverage Gaps`, continue
- `< 90%` → `❌` — log in `## Coverage Gaps` with reason (untestable/generated code, unreachable branches, external deps), continue

**BLUE** (after all GREEN steps, inline): selected agent refactors → `code-quality-auditor` verifies no behavior changes `🔵` → re-run coverage on BLUE-touched files; same targets apply

### Per-step Test Scope (GREEN + BLUE)

Scope to changed files only — never the full suite.
Per changed file, derive `<stem>` (no extension): `fd -t f '<stem>' | rg 'test|spec'`; fallback: `rg -l '(import|require|#include).*<stem>'` in test dirs. If none found: log `❌ no test file — <file>` in `## Coverage Gaps`, continue.

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

All `[x]` → lint + build + tests → status `implemented` → suggest `/dev:review-code`. Surface `## Coverage Gaps` in the summary if non-empty.
