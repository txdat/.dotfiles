# Development Verification

Owns test-first proof, coverage measurement, and verification gaps for approved application plans. [approval.md](approval.md) handles contradictions or changed test intent.

## Test-first proof

1. **RED:** translate each approved TC's fixture, action, and expected result into executable setup and assertions. Resolve shared fixture references and overrides; preserve every fixture property that distinguishes the approved scenario, including relationships and event order where relevant. Assert the approved results, side effects, and prohibited mutations, including contract-defined tolerances or allowed outcomes. Run against the unchanged production parent. Each new feature/fix test must fail for its intended missing behavior; fixture, import, and syntax failures are not proof. For a new API, a throwing stub may establish invocation, but inspect the later assertion to ensure it distinguishes correct behavior. Refactors start with passing behavior tests.
2. Commit tests before implementation: `test(red): <scope>` for features/fixes, `test: baseline <scope>` for refactors. Only tests and necessary throwing stubs belong in that commit. Record per-test results, failure reasons, proof SHA, and `Test: path::name` references in the plan.
3. **GREEN:** implement the approved behavior and run the tests. If behavioral sensitivity remains uncertain, make a focused check that the assertion fails when its required behavior is broken. Restore any temporary mutation and rerun tests. Once the checks pass, commit implementation separately.
4. **BLUE:** inspect for worthwhile simplification; no refactor is required. Verify any changes preserve behavior and rerun affected tests and coverage.

A targeted batch is sufficient when its output identifies each test and result. Inspect evidence on resume; commit titles alone prove nothing. If a fixture cannot be constructed or its expectation requires inventing semantics, stop the affected work and resolve it through [approval.md](approval.md); do not substitute an easier scenario or derive the expectation from production output.

Before GREEN and during review, run `~/.dotfiles/.ai-shared/bin/dev-check proof <commit> [--test <in-source-test-path>] [--stub <throwing-stub-path>]`. The helper checks paths and obvious stub violations. Read the diff too: a recognized test path can still hide implementation, and a tool pass does not prove assertion quality.

## Coverage

Coverage measures exercise, not correctness. Required AC/TC behavior, critical paths, and project/CI checks must be verified regardless of percentage. Add tests for meaningful behavior, never to inflate a score.

### Measure

Use project coverage tooling on changed code. Compare each slice with its Parent; whole-plan review uses the first slice's Parent. With coverage XML, `diff-cover coverage.xml --compare-branch=<parent>` measures touched-line coverage. Otherwise report changed-file coverage and inspect uncovered lines against the diff; label the scope accurately.

Inspect branch coverage for decision logic where supported. If unavailable, name untested branches alongside line coverage. Mocked adapter coverage does not prove real query, transaction, or dependency behavior; use integration evidence for those obligations. Exclude demonstrably untestable/generated code with a stated denominator; no testable lines is justified N/A, not an invented percentage.

Record revision, command, metric, scope, exclusions, and result. Missing or failed measurement is not a numerical shortfall.

### Interpret

Run `~/.dotfiles/.ai-shared/bin/dev-check coverage <percent> [uncovered-critical]`. The reporting bands are ≥90% PASS, 80–89% WARN, and <80% WARN below target. Uncovered critical behavior blocks. Separate project thresholds still apply.

For a shortfall, record uncovered lines, their behavior, and the reason in `## Coverage Gaps`. An explained percentage alone does not block or require approval. Missing required behavior does: repair its existing TC, or use [approval.md](approval.md) when the obligation itself must change.

Assertions must distinguish the required result from a plausible incorrect one. Snapshots, mock calls, and type/no-error checks are useful only when they prove the actual contract.
