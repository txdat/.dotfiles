# /review-code — Verify the Implementation

Review an `implemented` plan's code independently under [plan.md — Review](plan.md#review), in the plan's worktree, which the main agent leaves on the plan's Branch. The review base is where the work leaves its PR target: for Base, the merge-base with `origin/<Base>` (or local Base without one); for the parent plan's Branch, its tip (local, or `origin/<branch>`), which the work must contain.

## Behavior

- Derive the required outcome from the Goal and contracts before treating the tests as the oracle. Run the TC tests and affected tests yourself at the final tip.
- Trace each AC to assertions at the production boundary. A helper-level test cannot prove authorization, routing, or transaction behavior.
- Compare each test with its approved TC: fixture, distinguishing conditions, action, and expected result, which you check against the contract yourself. Apply the assertion rules in [plan.md — Verification](plan.md#verification), and check each RED commit with `dev-check.sh proof`; every TC has its test there.
- Passing tests do not override a violated obligation. Code that departs from an AC, TC, step, or DD blocks; a needed spec change follows [plan.md — Changes](plan.md#changes).

## Affected paths

- Security, data integrity, concurrency, compatibility, and failure paths, under [CODING.md — Impact](../../CODING.md#impact).
- Unnecessary queries, repeated or unbounded work, reimplemented concepts, and shared code bent with flags. Report concrete impact.
- Secrets and debug or conflict artifacts: run `~/.dotfiles/.ai-shared/bin/dev-check.sh artifacts <review base> HEAD`, judge each line it lists for review, and read the diff.

Report your conclusion on each AC and the Goal, the decisive evidence, and located findings split into blocking and notes. The review passes when nothing blocks.

## Finalize

On a passing review, the main agent runs the local checks and tests at the Branch tip, leaves the worktree on the Branch, sets `Status: reviewed <tip SHA>`, and hands off to [create-pr.md](create-pr.md). A later change to the Branch returns the plan to `implemented` for another review.
