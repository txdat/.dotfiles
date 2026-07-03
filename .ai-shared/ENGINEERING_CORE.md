# AI — Engineering Core

Universal engineering rules. Loaded by the main session (via `GUIDELINES.md`) and by every subagent (via its role doc). Role/communication/workflow rules live in `GUIDELINES.md` and apply to the main session only.

## Code
**Match before inventing.** Mirror existing patterns and style.

**Minimal footprint.** Every change traces to the request. No adjacent fixes or abstractions. Refactor only when explicitly asked. Remove only what you introduce; leave existing dead code alone. Spotted cleanup → note it (in your report/insights), do not apply.

**Root causes only.** Never patch or mask symptoms.

**Clean code principles.** Prefer code that is obvious to read, safe to change, and hard to misuse.

- **Name by intent.** Choose names that reveal purpose, domain, and units. Avoid abbreviations and overloaded terms that hide intent.
- **Keep units focused.** Functions, classes, and modules have one responsibility and one reason to change. Needing "and" to describe it means split it.
- **Make control flow boring.** Prefer guard clauses, early returns, and a linear happy path. Avoid nesting that makes readers track state across branches.
- **Abstract only after proof.** Duplication is cheaper than the wrong abstraction. Extract only when the concept and its change pattern are proven, not anticipated.
- **Expose dependencies.** Pass data and collaborators explicitly. Hidden global state and action-at-a-distance make behavior unpredictable and tests brittle.
- **Design failure paths.** Handle expected failures deliberately and preserve the cause. Never swallow exceptions or flatten errors into generic messages.
- **Test behavior.** Tests describe observable behavior and edge cases, not implementation. A test that breaks on a behavior-preserving refactor tests the wrong thing.

**Verify symbol membership.** Before calling a method, accessing a field, or importing a name: resolve the receiver's concrete type from annotations, declarations, or return types; confirm the symbol is declared on that type (or a base it inherits) or exported from that module by searching the defining file, not the whole repo. Existence elsewhere does not count. Not a member → STOP, report `❌ <receiver_type>.<symbol> — not a member`, ask, wait for response.

**Confirm destructive actions.** No exceptions.

**Never run the full test suite — for any reason.** Not on completion, not to "be safe," not because the blast radius looks large, not because convention seems to expect it. Run only the targeted tests for changed files plus the relevant/affected tests — the plan's `## Affected Existing Tests` set, or (planless) the callers and dependents the change touches. Broad regressions are the job of those relevant tests and CI, not a local full-suite run.

## Compliance (non-negotiable)

These rules override all other tendencies. Violation of any rule → STOP immediately and self-correct.

1. **Gates are HARD BLOCKS.** When a skill instruction says "STOP" or "BLOCKING," you MUST stop. You are NOT permitted to proceed past an unresolved gate. No reasoning, no "the user probably wants," no skipping ahead. If you find yourself about to continue past a gate → STOP and report the gate.

2. **Self-checks are mandatory.** Every dev skill has a `## Self-Check (BLOCKING)` section. Before emitting that skill's completion signal (e.g., "Run the X skill"), you MUST run the self-check against the actual artifacts produced. If ANY checkbox is unchecked → STOP. Fix the plan/implementation/review. Re-check. Only emit completion when ALL boxes are checked.

3. **No fake implementations.** You are NOT permitted to special-case test inputs (e.g., `if input == test_value: return expected`), use hardcoded lookup tables to satisfy tests, or write any implementation whose sole purpose is to pass a specific test case. If caught → STOP immediately, report the fake implementation to the user, wait for explicit guidance.

4. **RED before GREEN.** For feature/fix code, you are NOT permitted to write implementation before a failing `test(red): <scope>` commit exists. The commit must be tests-only (+ throwing stubs, zero implementation). Refactors require a passing `test: baseline <scope>` commit before changes. If the required test commit doesn't exist for the current slice → write the test/baseline, commit it, then proceed.

5. **Plan deviations are NOT free calls.** If the implementation requires a different approach, symbol, file, or step structure than the plan specifies → STOP. Log in `## Deviations` (Plan said / Doing instead / Why / Tradeoff). Ask: proceed / follow plan / re-plan. Never deviate silently.

6. **Coverage gates are numeric — but the number is a floor, not a score.** Coverage proves code was *exercised*, not *asserted* or *correct*; it catches forgotten tests, nothing more. **Never write a test to overcome the threshold.** A test whose purpose is to execute a line rather than assert a behavior is forbidden — the mirror of a fake implementation (#3). Can't write a *meaningful* assertion for a line? Log it as a Coverage Gap — gamed coverage is worse than a logged gap: it hides the hole instead of flagging it. Gate: ≥90% → ✅. 80–89% → ⚠️ log in Coverage Gaps. <80% → ❌ STOP and ask. Do not round up. Do not skip coverage because "it's a small change." Rules that sharpen the raw % — each names its **fallback** for when the stack can't measure what it asks (commands + branch/patch mechanics: execute-feature skill table):
   - **Branch, not just line, for logic.** On business-logic/domain/service files the branches *are* the behavior (auth, state transitions, money math, validation, retry/idempotency); a red branch is an untested error path, i.e. a future incident. Gate on branch coverage where the tool reports it (enable it — `--cov-branch`, `gcov -b`, JS *Branch* column, `cargo llvm-cov --branch`). *Fallback where it can't (Go is statement-only):* gate line-% and flag each untested branch by name in the Coverage Gap.
   - **Gate the diff, not the repo.** The threshold applies to every *changed* file. Prefer touched-line (patch) granularity via `diff-cover` against the coverage XML where available. *Fallback:* whole changed-file %. Never the repo-global number.
   - **Curate the denominator.** Exclude generated code, DTOs, serialization boilerplate, migrations, config, and `main`/wiring via the project's coverage config (omit/exclude globs), not by padding with hollow tests (no-gaming rule above). *Fallback where editing that config is out of the step's scope:* don't exclude silently — note the boilerplate lines as excluded-by-reason in the Coverage Gap and score the rest. A meaningful 82% beats a hollow 92%.
   - **Line coverage lies under mocks.** For DB/adapter/repository code, a mocked call shows green while the real query/isolation/constraint is wrong. Cover that layer with integration tests against real dependencies (testcontainers). *Fallback where real deps aren't wired into the step:* treat the mocked line-% as unverified — flag it, do not report it as ✅.
   - **The reason governs the digit — downward only.** In every ⚠️/❌ Coverage Gap, name *which* lines are uncovered. An uncovered critical path (auth / money / rollback / data-integrity) is ❌ **even when the raw % is ✅ (≥90)**; an unreachable defensive default or generated branch may be accepted one band lower. Reason can push a score *down* a band, never up — it never rescues a `<80`.

7. **Scope creep → STOP.** Work discovered beyond the plan is NOT a bonus. Log it in `## Discovered Scope` with estimated effort. Ask: include / separate / skip. Never silently expand scope.

8. **Evidence, not memory.** Every claim about code behavior, test results, coverage numbers, or file contents must cite actual tool output. Never answer from training data or assumption. If you haven't read the file or run the command, you don't know the answer.

9. **Open Questions are a hard gate.** If a plan's `## Assumptions & Open Questions` → `Open Questions:` field contains any real unresolved item, the plan is NOT ready for review. Empty markers such as `none` or `n/a` are allowed; placeholders or bullets are not. If a review finds unresolved Open Questions → verdict is NEEDS CHANGES, route back to design. Never proceed past an open question.

10. **No skipped phases for plan-backed work.** The workflow is: explore → design-feature → review-feature → execute → review-code → recap → PR. Phases cannot be skipped or reordered. Each phase's output is the next phase's input. Entry-point utilities (`explore`, `create-issue`, `fix-bug diagnose`, `simplify-code`, `write-rca`) follow their own skill flow; once they create or update a plan, the plan-backed workflow resumes from that status.

**Two enforcement layers.** Sequencing and coarse proof-commit gating are enforced *deterministically* by the `bin/gate-check` PreToolUse hook — it reads the active plan's status and git history and **blocks the skill invocation** when a state-machine prerequisite is unmet (wrong status for the skill, missing/out-of-sequence `test(red)`/`test: baseline` commits, unfinalized PR Pattern, unresolved Open Questions). A hook block is not negotiable: STOP and satisfy the prerequisite — do not rephrase to evade it. Quality gates (coverage %, symbol membership, no fake implementations, deviations/scope logged, and the exact content of proof commits) are NOT mechanically checkable and remain your responsibility via each skill's `## Self-Check (BLOCKING)`. The hook guarantees the *right skill ran at the right time with the expected proof-commit sequence*; the self-check guarantees the *work is correct*. Neither substitutes for the other.

## Evidence
Cite file contents, output, or test results. Never memory. If not found, say so.

**Raw output.** For diagnostic/state commands (`git status`, `ls`, log reads, `pip list`, env checks) before any consequential action: quote verbatim. Never substitute a summary where exact state matters.

**Code review suggestions.** Every non-blocking/suggestion finding needs concrete backing: file path + line numbers, quoted code, and the mechanism by which it manifests or the gain is measurable. No backing → omit or escalate to a question.

## Tooling
**File I/O:** Prefer platform-native file read/edit tools over shell equivalents (`cat`, `sed`, `head`, `tail`, `echo`) when available.

**Search/process:** `rg` over `grep` for repo search, `fd` over `find`, `jq` for JSON. Standard Unix filters fine in shell pipelines.

**Minimize tool calls.** Pipelines over sequences. Avoid redundant calls.

**Subagent context:** Write to `/tmp/ai-ctx/<slug>.md` before spawning. Prompt: "Read `/tmp/ai-ctx/<slug>.md` first, then…"

## Conventions
**Git credentials.** All git/GitHub actions run under the personal token from `gh auth login` (account `txdat`). Route GitHub ops through `gh`; rely on its stored credential. Never hardcode a token, inject `GITHUB_TOKEN`/`GH_TOKEN`, or use any other account. `gh auth status` not showing `txdat` active → STOP, report, wait.

**Base branch (`<base>`):** `BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|.*/||' || echo main)`. Skill docs use `<base>` to refer to this.

**Plan worktree (`<worktree>`):** every plan gets one git worktree, created by execute-feature/fix-bug and reused by every later skill (review-code, recap, create-pr) until create-pr removes it. Resolve by reading the active plan's `Worktree:` field — absent when a worktree is expected → STOP `❌ no Worktree recorded — run execute-feature/fix-bug first`. All git/gh commands for that plan run inside `<worktree>` (`cd <worktree>` or `git -C <worktree>`), never the main working tree — the plan's branches are checked out there, not in the main repo, and the plan file itself (`docs/plans/<file>.md`) is edited and committed from inside it. Convention: `<worktree>` = `/tmp/ai-worktrees/<repo-basename>-<slug>` (`<repo-basename>` = `$(basename "$(git rev-parse --show-toplevel)")`) — outside the repo tree, nothing to gitignore.

Once `Worktree:` is set, the worktree copy is the plan's **single source of truth**: read `Status:` and every section from it, and every skill that changes the plan (status flips, PR-Pattern finalization, Fix/Deviation/recap-status edits) edits **and commits** that change inside `<worktree>` — an edit left uncommitted at teardown is lost and makes `git worktree remove` refuse. *Resolution* still scans `$MAIN_ROOT/docs/plans/` (the worktree path isn't discoverable otherwise): match the plan file and read its `Worktree:` field there, then read live `Status:` from the worktree copy. create-pr copies the final plan back to `$MAIN_ROOT` and marks it `archived` before removing the worktree, so the main tree ends holding the archived plan.

`$MAIN_ROOT` (the main working tree) is never checked out or committed to by any skill — only `git worktree add`/`remove` touch it. It stays on whatever branch it was on (default or otherwise) for the whole plan lifecycle, so it's safe to leave it shared across concurrent agents/plans working the same repo; each plan's isolation comes entirely from its own `<worktree>` + branch. The one shared-mutable-state exception is symlinked dependency directories (`node_modules` etc.) — they point back into `$MAIN_ROOT`, so installing a *new* dependency must happen in `$MAIN_ROOT` itself, never inside a `<worktree>`, or it mutates the shared target underneath every other concurrent worktree.
