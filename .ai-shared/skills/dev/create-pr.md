# /create-pr — Publish Reviewed Work

Read [PROCESS.md](../../PROCESS.md) and resolve the named plan under [plan.md](plan.md). Entry is `reviewed` with a finalized PR Pattern. Publication runs in its [worktree](plan.md#worktree-operations). Default to draft unless `ready` is requested.

## Publish

1. Require a clean worktree before switching branches. For each PR row, verify its explicit Parent, nonempty diff, and `Slice N (<branch>): green at <sha>` record against the branch tip. Apply only [plan.md](plan.md)'s archive-commit exception. Changed code returns to review.
2. Run `~/.dotfiles/.ai-shared/bin/dev-check artifacts <parent> <reviewed-code-tip>` for each slice.
3. In pattern order, check out each row's Branch and verify it is current. Before pushing, query existing PRs for this repository and head; verify their base, state, and remote head against the reviewed slice, allowing step 1's archive exception. Conflicting, ambiguous, stale-head, or closed-unmerged matches require resolution before publication continues. Then push the branch and reuse a matching open PR, or create one in step 5.
4. Describe the actual change, rationale, verification, and relevant limitations using the project template. Include `Refs #N` initially. For a chain, include the ordered branch/parent/PR table and fill all links once the PRs exist.
5. Write multiline bodies to files. Create through [dev-github.sh](../../bin/dev-github.sh) `pr-create <title> <body-file> <parent> [--ready]`; update existing PRs with `gh pr edit --body-file`. Record all PR numbers and URLs in the live plan before archival.

## Issue closure

For a shared parent issue, mark this goal's checklist item complete and attach its PR numbers only after all its PRs exist. Preserve other goals. Partial publication leaves the item unchecked; retries reuse existing PRs.

Fetch the issue again. Use `Closes #N` only when [dev-utils.sh](../../bin/dev-utils.sh) `issue-claimants <number>` identifies this plan as the sole active claimant and no deferred goal remains unchecked. Otherwise retain `Refs #N`. Only the final chain PR may close the issue. Verify the updated bodies and chain links; an ambiguous goal entry requires clarification before editing.

## Complete

Follow [plan.md](plan.md)'s archive and cleanup procedure. Return PR URLs and state publication/cleanup completion only after it succeeds; publication does not mean merged or deployed. Follow-up work uses a new plan and the parent-selection rules in [design-feature.md](design-feature.md).
