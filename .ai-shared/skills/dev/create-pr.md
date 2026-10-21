# /create-pr — Publish a Reviewed Stack

Publish a `reviewed` plan, with every plan stacked on it, one PR per plan, draft unless the user asks for ready. Pass the stack's root ([plan.md — Stacks](plan.md#stacks)); the gate checks the plans above it. [dev-publish.sh](../../bin/dev-publish.sh) does the mechanical checks; [dev-stack.sh](../../bin/dev-stack.sh) `stack <root>` lists the stack's plans, parents before children. Run each step on every plan, parents first except where a step says otherwise, and finish it for all of them before the next step. No PR merges until every PR in the stack is published. When a step blocks, fix what it names and rerun that step; a changed branch returns its plan to review-code.

1. `dev-publish.sh check <plan>` — the Branch is at its Green, contains its parent's Branch, and has no open PR on another base; it prints the PR target as `base=`.
2. `git push -u origin <Branch>` (never force), then `gh pr create --base <target> --head <Branch> --title <plan title> --body-file <file> [--draft]`. On a rerun, push again but skip `gh pr create` when the plan's PR is already open on its target.
3. `dev-publish.sh verify <plan>` — one open PR on the target; its head, `origin`, and the local Branch at Green; a body linking the PR of each plan below.
4. Once every plan verifies, `dev-publish.sh cleanup <plan>`, children before parents — it hands a shared worktree back to the parent's Branch or removes the one the plan created, deletes the local Branch when it matches `origin`, and sets `Status: published`. If it lists ignored files, check them for unrelated work, then rerun with `--ignored-checked`. If it stops partway, rerun it on the unpublished plans.

PR bodies follow the project template and [plan.md](plan.md#artifact)'s language rule: the change, why, how it was verified, and limitations. Add `Refs #N` when an issue is linked, never a closing keyword. List the PRs below this one in the stack, in order. The plan stays out of the PR; the body carries what a reader needs.

Return the PR URLs.
