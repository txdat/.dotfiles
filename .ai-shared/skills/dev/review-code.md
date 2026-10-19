# /review-code — Verify the Implementation

Review an `implemented` plan's code independently under [plan.md — Review](plan.md#review), in the plan's worktree, which the main agent leaves on the final slice tip. The review base is where the work leaves PR-1's Parent: for Base, the merge-base with `origin/<Base>` (or local Base without one); for a branch, its tip (local or `origin/<Parent>`), or the merge-base when the Parent is ahead of the work only by plan files, such as the parent plan's archive commit.

## Behavior

- Derive the required outcome from the Goal and contracts before treating the tests as the oracle. Run the TC tests and affected tests yourself at the final tip.
- Trace each AC to assertions at the production boundary. A helper-level test cannot prove authorization, routing, or transaction behavior.
- Compare each test with its approved TC: fixture, distinguishing conditions, action, and expected result, which you check against the contract yourself. Apply the assertion rules in [plan.md — Verification](plan.md#verification), and check each slice's RED commit with `dev-check proof` and each TC's filled `Test:` line.
- Passing tests do not override a violated obligation. Code that departs from an AC, TC, step, or DD blocks; a needed spec change follows [plan.md — Changes](plan.md#changes).

## Affected paths

- Security, data integrity, concurrency, compatibility, and failure paths, under [CODING.md — Impact](../../CODING.md#impact).
- Unnecessary queries, repeated or unbounded work, reimplemented concepts, and shared code bent with flags. Report concrete impact.
- Secrets and debug or conflict artifacts: run `~/.dotfiles/.ai-shared/bin/dev-check artifacts <review base> HEAD`, judge each line it lists for review, and read the diff.

Report your conclusion on each AC and the Goal, the decisive evidence, and located findings split into blocking and notes. The review passes when nothing blocks.

## Finalize

On a passing review, the main agent checks out each slice branch in the worktree, from first to last, runs its local checks and tests, and records `Green: PR-n (<branch>) at <sha>` under the PR Pattern. Leave the worktree on the final slice, set `Status: reviewed`, and hand off to [create-pr.md](create-pr.md). A later change to any slice voids its Green line: return to `implemented` and review again.
