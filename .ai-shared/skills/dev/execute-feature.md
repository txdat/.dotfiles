# /execute-feature — Implement an Approved Plan

Read [PROCESS.md](../../PROCESS.md), [plan.md](plan.md), and the named plan. Entry is `approved`. Without a recorded `Worktree:`, create the first implementation slice's worktree under [plan.md — Worktree operations](plan.md#worktree-operations) from its explicit branch and Parent, first creating the local Parent from `origin/<Parent>` if only that exists, and record it; with one, resume from the current slice in that worktree. Create each later slice's branch and worktree as it begins, after its parent slice passes verification, and update `Worktree:` to the active slice. A plan with `After:` starts only once the earlier plan's last slice branch holds its code ([related plans — Order](reference/related-plans.md#order)).

Execute dependency-ordered slices. Before starting a step, run each of its `PC-n` checks in the slice worktree and append `— Result: <pass/fail> at <sha>` to that PC line. A failed check stops that step and its dependents under [plan.md — Changes](plan.md#changes). Follow [verification.md — Test-first proof](verification.md#test-first-proof) for proof, implementation, and BLUE; fill each TC's test reference and record proof/results.

Apply [CODING.md — Critical work](../../CODING.md#critical-work) to critical steps and [frontend-design.md](frontend-design.md) to UI work.

Delegation follows [CODING.md](../../CODING.md): the main agent owns RED tests and commits; implementation workers receive those tests and exclusive source ownership. Workers do not edit tests or plans or spawn agents. Missing approved scope or tests, conflicting requirements, or work beyond the assignment stops the affected implementation: report it to the main agent, which applies [plan.md — Changes](plan.md#changes). A task assigned to follow an existing pattern returns for a decision if no suitable pattern exists.

Workers return changed files, implemented ST/TC/AC IDs, verification results, and unresolved concerns. Critical work also reports invariant/failure-path evidence and residual risks under CODING.md's critical-work procedure.

Run [verification.md — Local checks](verification.md#local-checks), TC tests, and affected existing tests at each slice's tip before starting a dependent slice. Apply [verification.md — Coverage](verification.md#coverage) and [CODING.md — Impact](../../CODING.md#impact). Resolve Open Risks through their approved TCs.

Run `~/.dotfiles/.ai-shared/bin/dev-check artifacts <first-slice-parent> HEAD`. Once required behavior and checks pass, evidence is recorded, and no required verification gap remains, set `implemented` and hand off to [review-code.md](review-code.md).

## Chain execution

When the invocation names several plans of one `After:` chain, follow [related plans — Chain runs](reference/related-plans.md#chain-runs). Every named plan must be `approved`, or past execution and skipped; one still in `planning` blocks the whole run. Set each plan `implemented` before the next starts, so the later plan's PR-1 Parent, the earlier plan's last slice branch, already holds the code it builds on. Hand the chain to [review-code](review-code.md#chain-code-review) as one run.
