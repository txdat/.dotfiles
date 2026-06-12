# /execute-feature — Implement the Approved Plan

Find plan from $ARGUMENTS or status `approved`/`in-progress`. Set `in-progress`. Read project config file (CLAUDE.md/CODEX.md/GEMINI.md/AGENTS.md).
Partial: `<name> from <N>` → start at N; `<name> <N>` → run only N. No `// TODO` — if blocked, say so.

## Execution Strategy

Assign each GREEN step two axes from the plan:

- **Tier** (capability): from `## Risk Flags`, `### Non-functional` Security, and Affected Components — security / concurrency / data-integrity → `principal-se`; edge-case-heavy or moderately complex → `senior-se`; pure pattern, no edge cases or security → `junior-se`.
- **Independence**: different files, no shared state → parallelizable; shared files/deps → sequential (dependency-ordered).

Route:
- Any **principal-tier** step → `principal-se`; still obey Independence — shared files/deps run sequentially, only independent principal steps may run in parallel.
- Junior/senior work that is sequential or small (`≤3` steps) → inline on the main agent (it is already full-capability; spawning buys nothing).
- Independent junior/senior steps (`>3`) → fan out in **tier-homogeneous batches** — one batch per tier, never mix tiers in a batch.

## TDD Execution

Phases in order: RED 🔴 → GREEN 🟢 → BLUE 🔵.

**Branch & commit model.** Derive names from the plan's `## PR Pattern`; never commit to `<base>`. Always create from an **explicit** `<parent>` start point (never implicit HEAD); on resume, if the branch already exists, verify ancestry — `git merge-base --is-ancestor <parent> <branch>` non-zero → STOP `❌ <branch> not based on <parent>`. RED/GREEN commits land on the slice branch — create-pr reuses these branches.
- **Single / ad-hoc** (`Type: single`): `<parent>` = `<base>`. `git checkout -b <type>/<slug> <base> 2>/dev/null || git checkout <type>/<slug>`. Run RED→GREEN once over all `## Test Cases`.
- **Chain** (`Type: chain`): execute slices in PR-Pattern order. Per slice k, `<parent>` = `<base>` (k=1) else `<type>/<slug>-(k-1)`: `git checkout -b <type>/<slug>-k <parent> 2>/dev/null || git checkout <type>/<slug>-k`, then run RED→GREEN **scoped to that slice's `Steps` → TCs** — its `test(red): <slug>-k` commit precedes its implementation commit(s). Each slice branch is a self-contained RED→GREEN pair.

**RED** (sequential, inline):
- Feature/fix: translate each `## Test Cases` entry from the plan into test code — Given→setup, When→call, Then→assertion, function name from TC's `<test_fn_name>`. Do NOT redesign, merge, split, or invent cases. Ambiguous or missing field → STOP and ask. Then confirm each FAILS `🔴`.
- Refactor: translate each TC into test code the same way, then confirm all PASS first (baseline).
- Failure must come from absent or wrong implementation — not a malformed assertion. If a companion stub is needed, it must not return the expected value; panic, throw, or raise a not-implemented error for the language — or leave the body empty.
- **RED gate — commit before any implementation:** feature/fix → `git add <test-files> [<stub-files>] && git commit -m "test(red): <scope>"` (chain: `<scope>` = `<slug>-k`), tests + throwing stubs only (no implementation); skip if a `test(red)` commit already exists (resume). Refactor → `git add <test-files> && git commit -m "test: baseline <scope>"` (passing baseline). GREEN must not begin until this commit exists — it is the verifiable proof RED ran.

**GREEN**: Before writing implementation, verify every call, field access, and import is a member of its target type/module per CORE `Verify symbol membership`. Unresolved → STOP, ask, wait.

Implementation must be correct for all valid inputs. Never special-case test inputs (`if input == test_value: return expected`, hardcoded lookup tables). Violation → STOP immediately, report the fake impl to the user, wait for explicit guidance.

When a step's tests pass, stage and commit the implementation separately from RED: `git add <impl-files> && git commit -m "<type>(<scope>): <summary>"`. Keeps the `test(red)` commit as a standalone, verifiable artifact preceding the implementation.

Delegating per Execution Strategy (a principal-tier step, or an independent junior/senior batch) → write `/tmp/ai-ctx/<slug>.md`:
```
Plan: <path> | Stack: <detected>
Constraints: ONLY assigned steps. No TODO. Run ONLY assigned tests. Scope creep → STOP. Plan divergence → STOP and report.
```
Spawn each batch on its tier's agent: "Read /tmp/ai-ctx/<slug>.md. Steps: N,M. Files: <list>. Off-limits: <others>. TCs: TC-N,TC-M. Report: completed, TCs passing, coverage%, blockers." → `🟢 Step N: <done> (TC-N,TC-M ✅, coverage: X%)`

**Coverage** (per GREEN/BLUE step):
- `≥ 95%` → `✅ pass`
- `90%–94%` → `⚠️` — log uncovered lines in `## Coverage Gaps`, continue
- `< 90%` → `❌` — log in `## Coverage Gaps` with reason (untestable/generated code, unreachable branches, external deps), then STOP — ask: fix now / accept gap / split

**BLUE** (after all GREEN steps, inline): main agent refactors → `code-quality-auditor` verifies no behavior changes `🔵` → re-run coverage on BLUE-touched files; same targets apply

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
| Rust | `cargo llvm-cov -- <TestName> \| rg <changed_file>` |

## Scope Creep

Discovered work → STOP. Log in `## Discovered Scope` with estimated effort. Ask: include / separate / skip?

## Plan Deviation

The plan is approved and locked. Same goal, different means than it specifies — a different approach or Design Decision, a substituted symbol/signature, a changed step structure, a different file/module than planned — is a deviation, not a free call. (Distinct from Scope Creep, which is *new* work.)

Before implementing the divergence → STOP. Recap it in `## Deviations` (in the plan):
- Plan said: <what the plan specified>
- Doing instead: <the divergence>
- Why: <what forced or motivated it — planned symbol absent, approach unworkable, …>
- Tradeoff: <gained vs lost; risk introduced>

Ask: proceed with deviation / follow plan as written / re-plan. Never deviate silently.

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

All `[x]` → lint + build + targeted tests (full suite only if convention or blast radius warrants) → status `implemented`. Print: "Implementation complete. Run the review-code skill." Surface `## Coverage Gaps` and `## Deviations` if non-empty.
