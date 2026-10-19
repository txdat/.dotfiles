# /create-pr — Publish a Reviewed Stack

Publish a `reviewed` plan, with every plan stacked on it, as one PR per slice, draft unless the user asks for ready. Pass the stack's root ([plan.md — Stacks](plan.md#stacks)); the gate checks the plans above it. [dev-publish.sh](../../bin/dev-publish.sh) does the mechanical checks; `dev-publish.sh stack <root>` lists the stack's plans, parents before children. Run each step on every plan in that order, and finish it for all of them before the next step. No PR merges until every PR in the stack is published. When a step blocks, fix what it names and rerun that step; a changed slice returns its plan to review-code.

1. `dev-publish.sh check <plan>` — each slice branch is at its `Green:` SHA, or plan archive commits above it on the final slice after an earlier run, and parents match the PR Pattern. A block here stops publication before anything is archived.
2. Read the live plan for sensitive content, then `dev-publish.sh archive <plan>` — it commits the plan copy, with an empty `Worktree:`, on the final slice branch. This archive-only commit is the one change allowed above the final Green SHA; a rerun after a repair refreshes the copy.
3. For each slice, first to last: `git push -u origin <branch>` (never force), then `gh pr create --base <Parent> --head <branch> --title <title> --body-file <file> [--draft]`, titled from the row's Summary. On a rerun, still push, but skip `gh pr create` for a slice whose open PR already targets its Parent; after a repair, edit the final PR body to link the refreshed plan copy.
4. `dev-publish.sh verify <plan>` — each slice has one open PR on its Parent, each pushed branch matches its reviewed tip, plus the archive commit on the last, and the final PR body links the archived plan.
5. Once every plan verifies, `dev-publish.sh cleanup <plan>`, children before parents (the stack list reversed) — removes the worktree, deletes local slice branches that match `origin`, and deletes the live plan. If it lists ignored files, check them for unrelated work, then rerun with `--ignored-checked`. If cleanup stops partway, rerun it on the plans whose live copy remains.

PR bodies follow the project template and [plan.md](plan.md#artifact)'s language rule: the change, why, how it was verified, and limitations. Add `Refs #N` when an issue is linked, never a closing keyword. List the PRs before this one in the stack, in order; each plan's final PR links its archived plan at its commit SHA.

Return the PR URLs.
