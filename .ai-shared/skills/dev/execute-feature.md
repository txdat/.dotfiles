# /execute-feature — Implement the Approved Plan

Find plan from $ARGUMENTS or status `approved`/`in-progress`. Set `in-progress`. Read project config file (CLAUDE.md/CODEX.md/GEMINI.md/AGENTS.md).
Partial: `<name> from <N>` → start at N; `<name> <N>` → run only N. No `// TODO` — if blocked, say so.

## Execution Strategy

Independent (different files, no shared state) → parallel. Sequential (shared files/deps) → ordered.
Agent: `rapid-engineer` if pattern exists, no edge cases, no security; else `dedicated-engineer`.

## TDD Execution

Phases in order: RED 🔴 → GREEN 🟢 → BLUE 🔵.

**RED** (sequential, selected agent):
- Feature/fix: translate each `## Test Cases` entry from the plan into test code — Given→setup, When→call, Then→assertion, function name from TC's `<test_fn_name>`. Do NOT redesign, merge, split, or invent cases. Ambiguous or missing field → STOP and ask. Then confirm each FAILS `🔴`.
- Refactor: translate each TC into test code the same way, then confirm all PASS first (baseline).
- Failure must come from absent or wrong implementation — not a malformed assertion. If a companion stub is needed, it must not return the expected value; panic, throw, or raise a not-implemented error for the language — or leave the body empty.

**GREEN** (selected agent): Before writing implementation, verify every call, field access, and import is a member of its target type/module per GUIDELINES `Verify symbol membership`. Unresolved → STOP, ask, wait.

Implementation must be correct for all valid inputs. Never special-case test inputs (`if input == test_value: return expected`, hardcoded lookup tables). Violation → STOP immediately, report the fake impl to the user, wait for explicit guidance.

≤3 steps or all sequential → run inline. Otherwise write `/tmp/ai-ctx-<slug>.md`:
```
Plan: <path> | Stack: <detected>
Constraints: ONLY assigned steps. No TODO. Run ONLY assigned tests. Scope creep → STOP.
```
Spawn per batch: "Read /tmp/ai-ctx-<slug>.md. Steps: N,M. Files: <list>. Off-limits: <others>. TCs: TC-N,TC-M. Report: completed, TCs passing, coverage%, blockers." → `🟢 Step N: <done> (TC-N,TC-M ✅, coverage: X%)`

**Coverage** (per GREEN/BLUE step):
- `≥ 95%` → `✅ pass`
- `90%–94%` → `⚠️` — log uncovered lines in `## Coverage Gaps`, continue
- `< 90%` → `❌` — log in `## Coverage Gaps` with reason (untestable/generated code, unreachable branches, external deps), then STOP — ask: fix now / accept gap / split

**BLUE** (after all GREEN steps, inline): selected agent refactors → `code-quality-auditor` verifies no behavior changes `🔵` → re-run coverage on BLUE-touched files; same targets apply

### Per-step Test Scope (GREEN + BLUE)

Scope GREEN/BLUE verification to changed files only — never the full suite during individual steps.
Per changed file, derive `<stem>` (no extension): `fd -t f '<stem>' | rg 'test|spec'`; fallback: `rg -l '(import|require|#include).*<stem>'` in test dirs. If none found: log `❌ no test file — <file>` in `## Coverage Gaps`, then STOP — ask: add test now / accept gap / split.

| Stack | Command |
|---|---|
| Maven | `mvn test -pl <mod> -Dtest=<Class>` |
| Go | `go test -run <TestName> -coverprofile=c.out ./<pkg>/... && go tool cover -func=c.out \| grep <changed_file>` |
| Python | `pytest <test_files> -q --cov=<changed_module> --cov-report=term-missing` |
| TS/Jest | `npm test -- --testPathPattern=<test_file> --coverage --coverageReporters=text --collectCoverageFrom='["<changed_file>"]'` |
| C++ | `cmake -DCMAKE_CXX_FLAGS=--coverage .. && ctest --test-dir build -R <test>` then `gcov -n <changed_src>` (GCC) or `llvm-cov report <bin> --sources <changed_src>` (Clang) |

## Scope Creep

Discovered work → STOP. Log in `## Discovered Scope` with estimated effort. Ask: include / separate / skip?

## Dependents Check

After all GREEN + BLUE steps: for each modified symbol callable outside its own file (exported, public, non-private):
`rg -n '<symbol>' --type <lang> . | rg -v 'test|spec|_test'`
For each caller: signature-compatible? contract unchanged? Output:
```
Dependents: <symbol>
  ✅ <file:line> — compatible
  ❌ <file:line> — <what broke>
```
Any `❌` → STOP. Log in `## Discovered Scope`. Ask: fix inline / separate task / skip?

## Completion

All `[x]` → lint + build + targeted tests (full suite only if convention or blast radius warrants) → status `implemented` → suggest the review-code skill. Surface `## Coverage Gaps` if non-empty.
