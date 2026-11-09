# /review-code — Verify the Implementation

Review an `implemented` plan's code independently under [plan.md — Review](plan.md#review). Run every command in the round's scratch ([plan.md — Review rounds](plan.md#review-rounds)), which holds the plan's Branch tip with the open findings' repros applied. A review-only request has no scratch: read the plan's worktree and run only commands that leave its `git status` unchanged. The review base is defined in [plan.md — Verification](plan.md#verification).

## Behavior

A re-review covers only what [plan.md — Review](plan.md#review) lists for a delta review.

- Derive the required outcome from the Goal and contracts before treating the tests as the oracle. Run the TC tests and affected tests yourself at the final tip.
- Trace each AC to assertions at the production boundary. A helper-level test cannot prove authorization, routing, or transaction behavior.
- Compare each test with its approved TC: fixture, distinguishing conditions, action, and expected result, which you check against the contract yourself. Apply the assertion rules in [plan.md — Verification](plan.md#verification), and check each proof and `test(update)` commit with `dev-check.sh proof`, reading the diff of each `--test` path for non-test changes; every TC has its test in one of them, except under plan.md — Verification's `Type: config` rule. Check that the reported result of each TC's test was taken where plan.md — Verification requires it; without a report, report each such TC as an `asserted` finding that names the run at that commit which would settle it.
- Passing tests do not override a violated obligation. Code that departs from an AC, TC, step, or DD blocks; a needed spec change follows [plan.md — Changes](plan.md#changes).
- Try to break the behavior, not only confirm it. Prove each runtime-behavior finding, including an AC violation, with a run: in the round's scratch, or, for a review-only request, an existing command with crafted inputs that changes no file or shared state. Give the command, its output, the output the contract requires, and the repro. Label each finding `ran`, `traced` (failure walked through cited code), `located` (cited `file:line`), or `asserted`; an `asserted` finding names the run that would settle it and never blocks. A step, DD, or TC departure visible in the plan or diff is `located`.

## Affected paths

- Security, data integrity, concurrency, compatibility, and failure paths, under [CODING.md — Impact](../../CODING.md#impact).
- Unnecessary queries, repeated or unbounded work, reimplemented concepts, and shared code bent with flags. Report concrete impact; unbounded or repeated work on a production path, with a location and evidence, blocks.
- Secrets and debug or conflict artifacts: run `~/.dotfiles/.ai-shared/bin/dev-check.sh artifacts <review base> HEAD`, judge each line it lists for review, and read the diff.

Report your conclusion on each AC and the Goal, the decisive evidence, and findings with their label, location, and proof, split into blocking and notes. The review passes when nothing blocks.

## Finalize

Unless the request is review-only, the main agent records each round's verdict with `~/.dotfiles/.ai-shared/bin/dev-stack.sh code-review <plan> pass|needs-changes` before repairing or finalizing; [plan.md — Review rounds](plan.md#review-rounds) owns the round limit.

After a logged pass, the main agent runs the local checks, TC tests, and affected tests at the Branch tip, leaves the worktree on the Branch, sets `Status: reviewed` and `Tip: <tip SHA>` to the SHA the pass names, and hands off to [create-pr.md](create-pr.md). A later change to the Branch returns the plan to `implemented` for another review.
