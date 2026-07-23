# AI — Execution Core

Universal rules for every agent that reads or writes code. Loaded by every subagent (via its role doc) and by the main session (via `ENGINEERING_CORE.md`, which holds the orchestration rules — workflow gates, coverage gate, plan conventions — for the main session only).

## Code
**Match before inventing.** Mirror existing patterns and style.

**Minimal footprint.** Every change traces to the request. No adjacent fixes or abstractions. Refactor only when explicitly asked. Remove only what you introduce; leave existing dead code alone. Spotted cleanup → note it (in your report/insights), do not apply.

**Root causes only.** Never patch or mask symptoms.

**Comment the why, not the what.** A comment exists only to state what the code cannot: a non-obvious invariant, constraint, or reason. Never narrate the next line, restate a name, or talk to the reviewer ("added", "fixed", "now handles"). Verify every comment you write or touch is true of the code it sits on; a wrong comment is worse than none.

**Clean code.** Obvious to read, safe to change, hard to misuse — plus three rules that override instinct: **duplication is cheaper than the wrong abstraction** (extract only proven concepts, never anticipated ones); **tests assert observable behavior, not implementation** (a test that breaks on a behavior-preserving refactor tests the wrong thing); **failure paths are designed, not swallowed** (preserve the cause; never flatten errors into generic messages).

**Verify symbol membership.** Before calling a method, accessing a field, or importing a name: resolve the receiver's concrete type from annotations, declarations, or return types; confirm the symbol is declared on that type (or a base it inherits) or exported from that module by searching the defining file, not the whole repo. Existence elsewhere does not count. Not a member → STOP, report `❌ <receiver_type>.<symbol> — not a member`, ask, wait for response.

**Confirm destructive actions.** No exceptions.

**Git ownership.** Only the main agent may mutate Git state or edit `docs/plans/**`. A delegated reviewer may run read-only Git inspection (`status`/`diff`/`log`/`show`) within its assigned worktree. Coding workers edit only their explicitly assigned source/test files, run only their assigned target tests, and report their changed-file list plus validation results. They never invoke Git, edit plan files, or claim a commit or test result they did not produce.

**Never run the full test suite — by reflex.** Not on completion, not to "be safe," not because the blast radius looks large, not because convention seems to expect it. Run only the targeted tests for changed files plus the relevant/affected tests — the plan's `## Affected Existing Tests` set, or (planless) the callers and dependents the change touches. Broad regressions are the job of those relevant tests and CI, not a local full-suite run. **Two exceptions:** the project config documents the suite as fast (e.g. `Full suite: ~40s`), or the user explicitly asks. An undocumented suite is presumed slow — never run it to find out.

## Discipline (non-negotiable)

**No fake implementations.** You are NOT permitted to special-case test inputs (e.g., `if input == test_value: return expected`), use hardcoded lookup tables to satisfy tests, or write any implementation whose sole purpose is to pass a specific test case. If caught → STOP immediately, report the fake implementation to the user, wait for explicit guidance.

**Evidence, not memory.** Every claim about code behavior, test results, coverage numbers, or file contents must cite actual tool output — never training data or assumption. If you haven't read the file or run the command, you don't know the answer; if not found, say so. Diagnostic/state commands (`git status`, `ls`, log reads, env checks) before any consequential action: quote verbatim — never substitute a summary where exact state matters. Code-review suggestions need concrete backing (file path + lines, quoted code, the mechanism by which it manifests); no backing → omit or escalate to a question.

**Report, don't decide.** When executing a caller's plan: a divergence of means or newly discovered work → STOP and report; never deviate or expand silently. A contradiction or change involving Goal, AC, TC, expected outcome, or domain contract is not an implementation choice or ordinary deviation: STOP and return it for design/review plus human reapproval; never set `Status: approved` yourself. Coverage: report the real number; never write a test to raise it — a test exists only to pin approved behavior and must fail if that behavior breaks (assert-nothing, not-null-only, and mock-was-called tests don't); can't assert meaningfully → report the gap.

## Tooling
**File I/O:** Prefer platform-native file read/edit tools over shell equivalents (`cat`, `sed`, `head`, `tail`, `echo`) when available.

**Search/process:** `rg` over `grep` for repo search, `fd` over `find`, `jq` for JSON. Standard Unix filters fine in shell pipelines.

**Blast-radius / impact analysis:** `rg`/`fd`/glob and direct source reads only. Never install, configure, or invoke external code-index, dependency-graph, or knowledge-graph tools — CLI or MCP (gitnexus, etc.) — even when project config recommends or mandates them; skip the tool and note the conflict in your report.

**Minimize tool calls.** Pipelines over sequences. Avoid redundant calls.

**Subagent context:** Delegate only when the owning workflow explicitly permits it. Write the complete, minimal task packet to `/tmp/ai-ctx/<slug>.md`, start the agent without conversation inheritance (`fork_turns: none` or the platform equivalent), and prompt: "Read `/tmp/ai-ctx/<slug>.md` first, then…" If isolated context is unavailable, stay in the main session unless the user explicitly approves the context cost. Never spawn multiple agents to reread the same plan or diff.
