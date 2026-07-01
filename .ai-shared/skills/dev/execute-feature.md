# /execute-feature — Implement the Approved Plan

Resolve the session's active plan: an explicit `docs/plans/<file>.md` (or its slug) in $ARGUMENTS pins it; otherwise the session's pinned plan, else the lone active plan. 0 or 2+ active and none named → STOP, ask which.

**Approval Gate (BLOCKING):** the plan's `Status:` MUST be `approved` (or `in-progress` on resume). `planning`/`blocked-by-architecture` → STOP; ask the user to approve it manually (set `Status: approved`). Never self-approve — only ship-feature may auto-approve. Then set `in-progress`. Read project config file (CLAUDE.md/CODEX.md/GEMINI.md/AGENTS.md).
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

**Worktree & branch model.** Derive names from the plan's `## PR Pattern`; never commit to `<base>`. One worktree per plan, reused across all its slices, created from an **explicit** `<parent>` start point (never implicit HEAD). `<worktree>` per CORE (`/tmp/ai-worktrees/<repo-basename>-<slug>`, outside the repo tree). `$MAIN_ROOT` itself is never checked out or committed to by any skill — only `git worktree add`/`remove` touch it — so it stays on whatever branch it was on (default branch or otherwise), safe to leave shared across concurrent agents/plans.

**Create (first run):**
```bash
MAIN_ROOT=$(git rev-parse --show-toplevel)
WORKTREE="/tmp/ai-worktrees/$(basename "$MAIN_ROOT")-<slug>"
git worktree add "$WORKTREE" -b <type>/<slug> <base>   # single, or chain slice 1
```
Record `Worktree: <path>` (the resolved `$WORKTREE`) in the plan's frontmatter immediately — every downstream skill (review-code, recap, create-pr) resolves `<worktree>` from this field (CORE `Plan worktree`), not the main working tree.

**Plan file copy (once, right after create).** design-feature/review-feature only ever write `docs/plans/<file>.md` into `$MAIN_ROOT`'s working tree — it is never committed there, so `<base>`'s history doesn't contain it and the fresh worktree checkout won't either. Copy it over explicitly: `cp "$MAIN_ROOT/docs/plans/<file>.md" "$WORKTREE/docs/plans/<file>.md"`. From this point on, edit and commit the plan *inside* `<worktree>`, not the main working tree — every commit below that touches Status/`## Deviations`/`## Coverage Gaps`/`## Discovered Scope` stages the plan file alongside the code it describes. Never leave plan edits uncommitted when the worktree is later removed.

**Dependency linking (once, right after the plan-file copy, before any test run):** for each dependency directory present at `$MAIN_ROOT` and absent in `<worktree>` (`node_modules`, `vendor`, `.venv`, `venv`, `Pods`, or project convention) — symlink, never reinstall or copy: `ln -s "$MAIN_ROOT/<dep>" "<worktree>/<dep>"`. The symlink target is shared with every other worktree off this repo. Plan needs a **new** dependency → install it in `$MAIN_ROOT` first (`npm install <pkg>` etc., run there, never inside `<worktree>`), then symlink as usual — installing inside a worktree would mutate the shared target underneath any other agent's concurrent worktree. Lockfile differs from `<base>` → warn and still symlink; do not auto-reinstall. (These dep dirs are normally gitignored; a project that doesn't ignore one leaves its symlink untracked, so create-pr's `git worktree remove` will need confirmed `--force` at teardown.)

**Resume:** `Worktree:` set → reuse it, `git worktree list` must show it (missing → STOP `❌ worktree <path> missing — recreate or ask`); verify ancestry — `git -C <worktree> merge-base --is-ancestor <parent> <branch>` non-zero → STOP `❌ <branch> not based on <parent>`.

All commands below run inside `<worktree>` (`cd <worktree>` or `git -C <worktree>`).

- **Single** (`Type: single`): `<parent>` = `<base>`. Run RED→GREEN once over all `## Test Cases`.
- **Chain** (`Type: chain`): execute slices in PR-Pattern order, sequentially, each on its own branch inside the same worktree. Per slice k, `<parent>` = `<base>` (k=1) else `<type>/<slug>-(k-1)`: `git checkout -b <type>/<slug>-k <parent>`, then run RED→GREEN **scoped to that slice's `Steps` → TCs** — its `test(red): <slug>-k` commit precedes its implementation commit(s). Each slice branch is a self-contained RED→GREEN pair.

**RED** (sequential, inline):
- Feature/fix: translate each `## Test Cases` entry from the plan into test code — Given→setup, When→call, Then→assertion, function name from TC's `<test_fn_name>`. Do NOT redesign, merge, split, or invent cases. Ambiguous or missing field → STOP and ask. Then confirm each FAILS `🔴`.
- Refactor: translate each TC into test code the same way, then confirm all PASS first (baseline).
- Failure must come from absent or wrong implementation — not a malformed assertion. If a companion stub is needed, it must not return the expected value; panic, throw, or raise a not-implemented error for the language — or leave the body empty.
- **RED gate — commit before any implementation:** feature/fix → `git add <test-files> [<stub-files>] [docs/plans/<file>.md if changed] && git commit -m "test(red): <scope>"` (chain: `<scope>` = `<slug>-k`), tests + throwing stubs only (no implementation); skip if a `test(red)` commit already exists (resume). Refactor → `git add <test-files> [docs/plans/<file>.md if changed] && git commit -m "test: baseline <scope>"` (passing baseline). GREEN must not begin until this commit exists — it is the verifiable proof RED ran.

**GREEN**: Before writing implementation, verify every call, field access, and import is a member of its target type/module per CORE `Verify symbol membership`. Unresolved → STOP, ask, wait.

Implementation must be correct for all valid inputs. Never special-case test inputs (`if input == test_value: return expected`, hardcoded lookup tables). Violation → STOP immediately, report the fake impl to the user, wait for explicit guidance.

When a step's tests pass, stage and commit the implementation separately from RED: `git add <impl-files> [docs/plans/<file>.md if changed] && git commit -m "<type>(<scope>): <summary>"`. Keeps the `test(red)` commit as a standalone, verifiable artifact preceding the implementation.

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

After all GREEN + BLUE steps: for each modified symbol callable outside its own file (exported, public, non-private), find its callers. Prefer LSP find-references (semantic — avoids name false-matches and aliased-import misses); fall back to `rg -n '<symbol>' --type <lang> . | rg -v 'test|spec|_test'` when no language server is available. Exclude test files either way.
For each caller: signature-compatible? contract unchanged? Output:
```
Dependents: <symbol>
  ✅ <file:line> — compatible
  ❌ <file:line> — <what broke>
```
Any `❌` → STOP. Log in `## Discovered Scope`. Ask: fix inline / separate task / skip?

## Completion

All implementation items checked → lint + build + targeted tests — including the plan's `## Affected Existing Tests` set; a failing existing test → root-cause before forcing green (**regression** → fix impl / **stale test**: a `needs update` test the Impl step never updated → finish that step / **intended change** → log `## Deviations`). Full suite only if convention or blast radius warrants. Then run the Self-Check below.

## Self-Check (BLOCKING — do NOT emit completion until every item is ✅)

Run this audit before marking the plan `implemented`. If ANY item is unchecked → STOP, fix, re-check.

- [ ] **Build + suite gate**: lint + build pass; targeted tests green (full suite if convention/blast radius warrants); no test force-greened over a failure.
- [ ] **RED/baseline gate** (`## TDD Execution`): per slice the proof commit — `test(red)` feature/fix, `test: baseline` refactor — precedes that slice's impl commit(s). Proof commits: __ / slices: __ — match?
- [ ] **Symbol membership** (CORE `Verify symbol membership`): ran on every new call, field access, import. Unresolved: __.
- [ ] **No fake implementations** (`## TDD Execution` → GREEN): re-read the impl — no test-input special-casing, no lookup tables. Offenders: __.
- [ ] **GREEN coverage** (`## TDD Execution` thresholds): every changed file ✅ / ⚠️ logged in `## Coverage Gaps` / ❌ resolved. Gaps: __.
- [ ] **BLUE refactor**: all GREEN done → refactor → `code-quality-auditor` confirmed no behavior change → coverage re-run on BLUE-touched files, targets met.
- [ ] **Dependents** (`## Dependents Check`): ran; every ❌ resolved. Open: __.
- [ ] **Affected Existing Tests**: plan's set all pass OR each failure root-caused (regression fixed / stale test finished / intended change in `## Deviations`). Failing: __.
- [ ] **Deviations logged** (`## Plan Deviation`): every divergence in `## Deviations` with Plan said / Doing instead / Why / Tradeoff. Unlogged: __.
- [ ] **Scope Creep logged** (`## Scope Creep`): every discovery in `## Discovered Scope`. Unlogged: __.
- [ ] **Worktree clean** (`## TDD Execution` → Worktree & branch model): `<worktree>` matches plan's `Worktree:` field; `git -C <worktree> status --porcelain` shows no uncommitted plan-file changes. Dirty: __.

If ALL checked → set status `implemented` in the worktree's plan copy and commit it: `git add docs/plans/<file>.md && git commit -m "docs(<scope>): mark plan implemented"` (skip if nothing to commit). Print: "Implementation complete. Run the review-code skill." Surface `## Coverage Gaps` and `## Deviations` if non-empty.
