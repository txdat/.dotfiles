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

## Compliance (non-negotiable)

These rules override all other tendencies. Violation of any rule → STOP immediately and self-correct.

1. **Gates are HARD BLOCKS.** When a skill instruction says "STOP" or "BLOCKING," you MUST stop. You are NOT permitted to proceed past an unresolved gate. No reasoning, no "the user probably wants," no skipping ahead. If you find yourself about to continue past a gate → STOP and report the gate.

2. **Self-checks are mandatory.** Every dev skill has a `## Self-Check (BLOCKING)` section. Before emitting that skill's completion signal (e.g., "Run the X skill"), you MUST run the self-check against the actual artifacts produced. If ANY checkbox is unchecked → STOP. Fix the plan/implementation/review. Re-check. Only emit completion when ALL boxes are checked.

3. **No fake implementations.** You are NOT permitted to special-case test inputs (e.g., `if input == test_value: return expected`), use hardcoded lookup tables to satisfy tests, or write any implementation whose sole purpose is to pass a specific test case. If caught → STOP immediately, report the fake implementation to the user, wait for explicit guidance.

4. **RED before GREEN.** For feature/fix code, you are NOT permitted to write implementation before a failing `test(red): <scope>` commit exists. The commit must be tests-only (+ throwing stubs, zero implementation). Refactors require a passing `test: baseline <scope>` commit before changes. If the required test commit doesn't exist for the current slice → write the test/baseline, commit it, then proceed.

5. **Plan deviations are NOT free calls.** If the implementation requires a different approach, symbol, file, or step structure than the plan specifies → STOP. Log in `## Deviations` (Plan said / Doing instead / Why / Tradeoff). Ask: proceed / follow plan / re-plan. Never deviate silently.

6. **Coverage gates are numeric.** ≥95% → ✅. 90–94% → ⚠️ log in Coverage Gaps. <90% → ❌ STOP and ask. Do not round up. Do not skip coverage because "it's a small change." The threshold applies to every changed file.

7. **Scope creep → STOP.** Work discovered beyond the plan is NOT a bonus. Log it in `## Discovered Scope` with estimated effort. Ask: include / separate / skip. Never silently expand scope.

8. **Evidence, not memory.** Every claim about code behavior, test results, coverage numbers, or file contents must cite actual tool output. Never answer from training data or assumption. If you haven't read the file or run the command, you don't know the answer.

9. **Open Questions are a hard gate.** If a plan's `## Assumptions & Open Questions` → `Open Questions:` field contains any real unresolved item, the plan is NOT ready for review. Empty markers such as `none` or `n/a` are allowed; placeholders or bullets are not. If a review finds unresolved Open Questions → verdict is NEEDS CHANGES, route back to design. Never proceed past an open question.

10. **No skipped phases for plan-backed work.** The workflow is: explore → design-feature → review-feature → execute → review-code → recap → PR. Phases cannot be skipped or reordered. Each phase's output is the next phase's input. Entry-point utilities (`explore`, `create-issue`, `fix-bug diagnose`, `simplify-code`, `write-rca`) follow their own skill flow; once they create or update a plan, the plan-backed workflow resumes from that status.

**Two enforcement layers.** Sequencing and TDD-proof are enforced *deterministically* by the `bin/gate-check` PreToolUse hook — it reads the active plan's status and git history and **blocks the skill invocation** when a state-machine prerequisite is unmet (wrong status for the skill, no `test(red)`/`test: baseline` proof, unfinalized PR Pattern, unresolved Open Questions). A hook block is not negotiable: STOP and satisfy the prerequisite — do not rephrase to evade it. Quality gates (coverage %, symbol membership, no fake implementations, deviations/scope logged) are NOT mechanically checkable and remain your responsibility via each skill's `## Self-Check (BLOCKING)`. The hook guarantees the *right skill ran at the right time with TDD proof*; the self-check guarantees the *work is correct*. Neither substitutes for the other.

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
