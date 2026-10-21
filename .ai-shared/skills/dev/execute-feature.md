# /execute-feature — Implement an Approved Plan

Implement an `approved` plan test-first under [plan.md](plan.md).

1. Without a recorded `Worktree:`, set it up under [plan.md — Worktree](plan.md#worktree): share the parent's when this plan is its only child, otherwise create one on the plan's Branch from its PR target. With one, resume in it on the plan's Branch: finish the RED then implementation commits and rerun the checks.
2. Before each step, run its PC Checks; a failure stops that step and everything depending on it under [plan.md — Changes](plan.md#changes).
3. Follow [plan.md — Verification](plan.md#verification): RED commit, then implementation. Fill each TC's `Test:` line.

If you delegate, the main agent owns the RED tests and their commit; workers never edit tests or the plan.

When the plan passes its checks, set `Status: implemented` and hand off to [review-code.md](review-code.md).
