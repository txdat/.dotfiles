# /execute-feature — Implement an Approved or Auto-Approved Plan

Implement an `approved` or `auto-approved` plan test-first under [plan.md](plan.md).

1. Without the plan's worktree, create it under [plan.md — Worktree](plan.md#worktree). With one, resume in it on the plan's Branch: finish the RED then implementation commits, or for `Type: config` the change, and rerun the checks. When the Branch already holds commits of an earlier revision of the plan, update its tests under the revised-plan rule in [plan.md — Verification](plan.md#verification) before implementing.
2. Before each step, run its PC Checks; a failure stops that step and everything depending on it under [plan.md — Changes](plan.md#changes).
3. Follow [plan.md — Verification](plan.md#verification): RED commit, then implementation, or for `Type: config`, the change and its TC checks.

To delegate chunks, use [dev-executor](../../agents/dev-executor.md) where installed. Whoever runs this skill owns the RED tests, their commit, and the plan; chunk workers never edit them.

When the plan passes its checks, set `Status: implemented`, report each TC's test with its result where [plan.md — Verification](plan.md#verification) requires it, or for `Type: config` its check result. Then hand off to [review-code.md](review-code.md).
