# /execute-feature — Implement an Approved Plan

Read [PROCESS.md](../../PROCESS.md), [plan.md](plan.md), and the named plan. Entry is `approved` or `in-progress`. For a chain, prepare or verify the [approved snapshots](plan.md#approved-snapshots) before creating implementation branches. Create or reuse the first implementation slice's worktree under [plan.md — Worktree operations](plan.md#worktree-operations), using its explicit branch and Parent, then set `in-progress`. Prepare later branches and create or reuse worktrees as their slices begin, after their parent slices pass verification. On resume, continue from the current slice and its recorded worktree.

Execute dependency-ordered slices. Follow [verification.md — Test-first proof](verification.md#test-first-proof) for proof, implementation, and BLUE; fill each TC's test reference and record proof/results. On resume, inspect commits and evidence to find unfinished work. A requested starting step does not waive its prerequisites.

Apply [CODING.md — Critical work](../../CODING.md#critical-work) to critical steps and [frontend-design.md](frontend-design.md) to UI work.

Delegation follows [CODING.md](../../CODING.md): the main agent owns RED tests and commits; implementation workers receive those tests and exclusive source ownership. Workers do not edit tests or plans, mutate Git, or spawn agents. Missing approved scope or tests, conflicting requirements, or work beyond the assignment stops the affected implementation: report the missing input or decision to the main agent rather than silently deviating. A task assigned to follow an existing pattern returns for a decision if no suitable pattern exists.

Workers return changed files, implemented TC/AC IDs, verification results, and unresolved concerns. Critical work also reports invariant/failure-path evidence and residual risks under CODING.md's critical-work procedure.

Run required lint/build, TC tests, and affected existing tests at each slice's tip before starting a dependent slice. Apply [verification.md — Coverage](verification.md#coverage) and [CODING.md — Impact](../../CODING.md#impact). Resolve Open Risks through their approved TCs. Use [approval.md](approval.md) for spec changes, deviations, or new scope.

Run `~/.dotfiles/.ai-shared/bin/dev-check artifacts <first-slice-parent> HEAD`. Once required behavior and checks pass, evidence is recorded, and no required verification gap remains, set `implemented` and hand off to [review-code.md](review-code.md).
