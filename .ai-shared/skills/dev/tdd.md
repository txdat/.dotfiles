# TDD Proof — Single Source

Used by execute-feature and approved-plan fix-bug execution; independently verified by review-code. The approved spec owns the oracle (`Goal → AC → TC`); TDD owns implementation proof (`approved TC → RED → GREEN → BLUE`).

1. Implement each approved TC exactly: Given → setup, When → call, Then → assertion; confirm the assertion proves its named AC and observable Goal outcome. Do not invent, merge, split, or reinterpret behavior.
2. Feature/fix: run the test and confirm failure comes from absent/wrong behavior. Refactor: confirm the behavior test passes before change. A needed stub may only throw/panic/not-implemented; it must not return the expected value.
3. Before implementation, commit proof alone: `test(red): <scope>` for feature/fix or `test: baseline <scope>` for refactor. Tests plus explicitly named throwing stubs only; no plan or implementation files. On resume, reuse only an aligned valid proof.
4. Commit GREEN separately after targeted tests pass. Correct all valid inputs and satisfy the parent AC, not merely its examples; test-input special cases and hardcoded expected-value tables are fake implementations and block.
5. BLUE is a quality pass, not mandatory code churn: inspect the GREEN implementation, refactor only when it improves the design, and keep tests green. Rerun targeted tests and coverage for any BLUE-touched files; "no refactor needed" is valid.

Ambiguity or contradiction among Goal, AC, TC, another TC, observed contract, or domain source → STOP before changing test or implementation, and go back through `approval.md`. TDD never decides new behavior.

Run `~/.dotfiles/.ai-shared/bin/dev-check proof <commit> [--test <in-source-test-path>] [--stub <throwing-stub-path>]` before GREEN and during review. It validates paths and blocks obvious value-return stubs; inspect allowed paths and the test's behavioral assertion yourself.
