# /execute-feature — Implement an Approved Plan

Implement an `approved` plan test-first, slice by slice, under [plan.md](plan.md).

1. Without a recorded `Worktree:`, create it from PR-1's branch and Parent, passing `origin/<Parent>` when no local Parent exists, under [plan.md — Worktree](plan.md#worktree). With one, resume in it on the highest-numbered existing slice branch: finish that slice's RED then implementation commits and rerun its checks.
2. Work through the slices in PR Pattern order. Before each step, run its PC Checks; a failure stops that step and everything depending on it under [plan.md — Changes](plan.md#changes).
3. Follow [plan.md — Verification](plan.md#verification) for each slice: RED commit, then implementation. Fill each TC's `Test:` line.

If you delegate, the main agent owns the RED tests and their commit; workers never edit tests or the plan.

When every slice passes, set `Status: implemented` and hand off to [review-code.md](review-code.md).
