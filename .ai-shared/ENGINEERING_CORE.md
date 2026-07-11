# AI — Engineering Core

Orchestration rules for the main session, loaded via `GUIDELINES.md`. First read `~/.dotfiles/.ai-shared/EXECUTION_CORE.md` — the universal Code/Discipline/Tooling rules (single source, also loaded by every subagent). Role/communication/workflow rules live in `GUIDELINES.md`.

## Compliance (non-negotiable)

These rules override all other tendencies. Violation of any rule → STOP immediately and self-correct. (#3 and #8 live in EXECUTION_CORE as `No fake implementations` and `Evidence, not memory`; numbering is preserved so existing references stay valid.)

1. **Gates are HARD BLOCKS.** When a skill instruction says "STOP" or "BLOCKING," you MUST stop. You are NOT permitted to proceed past an unresolved gate. No reasoning, no "the user probably wants," no skipping ahead. If you find yourself about to continue past a gate → STOP and report the gate.

2. **Self-checks are mandatory.** Every dev skill has a `## Self-Check (BLOCKING)` section. Before emitting that skill's completion signal (e.g., "Run the X skill"), you MUST run the self-check against the actual artifacts produced. If ANY checkbox is unchecked → STOP. Fix the plan/implementation/review. Re-check. Only emit completion when ALL boxes are checked.

4. **RED before GREEN.** For feature/fix code, you are NOT permitted to write implementation before a failing `test(red): <scope>` commit exists. The commit must be tests-only (+ throwing stubs, zero implementation). Refactors require a passing `test: baseline <scope>` commit before changes. If the required test commit doesn't exist for the current slice → write the test/baseline, commit it, then proceed.

5. **Plan deviations are NOT free calls.** A deviation is same goal, different means than the plan specifies — a different approach or Design Decision, a substituted symbol/signature, a changed step structure, a different file/module. (Distinct from scope creep, which is *new* work — see #7.) Before implementing the divergence → STOP. Log in `## Deviations`: Plan said / Doing instead / Why (what forced it) / Tradeoff (gained vs lost, risk introduced). Ask: proceed / follow plan / re-plan. Never deviate silently.

6. **Coverage gates are numeric — but the number is a floor, not a score.** Coverage proves code was *exercised*, not *asserted* or *correct*. **Never write a test to overcome the threshold** — a test that executes a line without asserting behavior is the mirror of a fake implementation (EXECUTION_CORE `No fake implementations`); can't write a *meaningful* assertion → log it as a Coverage Gap (a logged gap beats gamed coverage: it flags the hole instead of hiding it). Gate every *changed* file — never the repo-global number: ≥90% → ✅ · 80–89% → ⚠️ log in Coverage Gaps · <80% → ❌ STOP and ask. No rounding up; no skipping because "it's a small change." **The reason governs the digit — downward only:** every ⚠️/❌ gap names *which* lines are uncovered; an uncovered critical path (auth / money / rollback / data-integrity) is ❌ even at ≥90%, an unreachable defensive default may be accepted one band lower — a reason pushes a score *down* a band, never up. Closing a gap goes through behavior, never lines — protocol in coverage.md `Closing a gap`. Measurement mechanics — branch-vs-line, patch (diff-cover) granularity, denominator curation, the mock caveat, per-stack commands and fallbacks — live in `~/.dotfiles/.ai-shared/skills/dev/coverage.md` (single source).

7. **Scope creep → STOP.** Work discovered beyond the plan is NOT a bonus. Log it in `## Discovered Scope` with estimated effort. Ask: include / separate / skip. Never silently expand scope.

9. **Open Questions are a hard gate.** If a plan's `## Assumptions & Open Questions` → `Open Questions:` field contains any real unresolved item, the plan is NOT ready for review. Empty markers such as `none` or `n/a` are allowed; placeholders or bullets are not. If a review finds unresolved Open Questions → verdict is NEEDS CHANGES, route back to design. Never proceed past an open question.

10. **No skipped phases for plan-backed work.** The workflow is: explore → design-feature → review-feature → execute → review-code → recap → PR. Phases cannot be skipped or reordered. Each phase's output is the next phase's input. Entry-point utilities (`explore`, `create-issue`, `fix-bug diagnose`, `simplify-code`, `write-rca`) follow their own skill flow; once they create or update a plan, the plan-backed workflow resumes from that status.

## Conventions
**Git credentials.** All git/GitHub actions run under the personal token from `gh auth login` (account `txdat`). Route GitHub ops through `gh`; rely on its stored credential. Never hardcode a token, inject `GITHUB_TOKEN`/`GH_TOKEN`, or use any other account. `gh auth status` not showing `txdat` active → STOP, report, wait.

**Base branch (`<base>`):** `BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|.*/||' || echo main)`. Skill docs use `<base>` to refer to this.

**Plan worktree (`<worktree>`):** every plan gets one git worktree at `/tmp/ai-worktrees/<repo-basename>-<slug>`, created by execute-feature/fix-bug and reused by every later skill (review-code, recap, create-pr) until create-pr removes it. **Resolve:** scan `$MAIN_ROOT/docs/plans/` for the plan file and read its `Worktree:` field — absent when a worktree is expected → STOP `❌ no Worktree recorded — run execute-feature/fix-bug first`. Once set, the worktree copy of the plan is its **single source of truth**: read `Status:` and every section from it, and every plan edit (status flips, PR-Pattern finalization, Deviations) is made **and committed** inside `<worktree>`. All git/gh commands for the plan run there (`cd <worktree>` or `git -C <worktree>`), never in the main working tree. Lifecycle mechanics — create, plan copy, dependency symlinks, resume/ancestry checks, `$MAIN_ROOT` sharing rules, teardown — live in `~/.dotfiles/.ai-shared/skills/dev/worktree.md` (single source).
