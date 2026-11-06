# /execute-feature — Implement an Approved or Auto-Approved Plan

Implement an `approved` or `auto-approved` plan test-first under [plan.md](plan.md).

1. Without a worktree ([plan.md — Worktree](plan.md#worktree)), set one up: share the parent's when this plan is its only child, otherwise create one on the plan's Branch from its PR target. With one, resume in it on the plan's Branch: finish the RED then implementation commits, or for `Type: config` the change, and rerun the checks.
2. Before each step, run its PC Checks; a failure stops that step and everything depending on it under [plan.md — Changes](plan.md#changes).
3. Follow [plan.md — Verification](plan.md#verification): RED commit, then implementation, or for `Type: config`, the change and its TC checks.

To delegate chunks, use [dev-executor](../../agents/dev-executor.md) where installed. Whoever runs this skill owns the RED tests, their commit, and the plan; chunk workers never edit them.

When the plan passes its checks, set `Status: implemented`, report each TC's test with its RED failure or baseline result, or for `Type: config` its check result, and hand off to [review-code.md](review-code.md).
