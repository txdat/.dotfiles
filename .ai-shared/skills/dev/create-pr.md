# /create-pr — Publish Reviewed Work

Read [PROCESS.md](../../PROCESS.md) and resolve the named plan under [plan.md](plan.md). Entry is `reviewed` with a finalized PR Pattern. Publication runs in the recorded [worktrees](plan.md#worktree-operations). Default to draft unless `ready` is requested. If publication is already verified and only cleanup remains, use [cleanup-only resume](plan.md#cleanup-only-resume).

## Publish

1. Resolve the publication inventory under [plan.md](plan.md). For each code slice, resolve its explicit Parent to a commit before checking ancestry or diffs. Fetch origin as needed; when the branch exists only there, use `refs/remotes/origin/<parent>` for Git checks and `<parent>` for the GitHub base. Record the resolved SHA and confirm the local/remote refs and ancestry agree with the reviewed scope; resolve drift before proceeding.
2. Verify each slice's nonempty diff and `Slice N (<branch>): green at <sha>` against its branch tip, allowing only [plan.md](plan.md)'s archive-only exception. Changed code returns to review. Verify both endpoints and a successful `git diff <parent-sha> <reviewed-code-tip>`, then run `~/.dotfiles/.ai-shared/bin/dev-check artifacts <parent-sha> <reviewed-code-tip>`. The helper can report PASS for invalid refs; its result alone is insufficient.
3. Publish each code row in pattern order using the PR operations below. Require a clean worktree before switching branches; preserve unrelated dirty root files. Record PR numbers/URLs in every affected live plan as they become available.
4. Follow [plan.md — Archive and cleanup](plan.md#archive-and-cleanup): prepare the archive, create its separate PR if used, synchronize all bodies, verify the final archives, then clean up. Use the PR operations below for the archive PR too; its diff and verification follow plan.md.

## PR operations

Before pushing, query all PR states for the repository and head. Reuse a matching open PR after checking its base and remote head against the reviewed branch and permitted archive commits. Allow expected fast-forward updates; resolve ambiguous matches or unexpected divergence.

For closed-unmerged work still required by the authorized scope, create a replacement after checking for an existing replacement on retries. Preserve the old PR and record its number/URL as `Supersedes` history in the replacement body and live plans. Active chain entries use the replacement. For merged PRs, verify what is already delivered before deciding further publication. If a replacement changes branches, reconcile downstream Parents under [review-code.md](review-code.md) before continuing.

Describe the change, rationale, verification, and limitations using the project template, initially with `Refs #N`. Write multiline bodies to files. Push the verified branch and create through [dev-github.sh](../../bin/dev-github.sh) `pr-create <title> <body-file> <parent> [--ready]`; edit existing bodies with `gh pr edit --body-file`.

## Synchronize bodies and issue links

After all PR numbers exist, update every active PR body, including earlier/reused PRs and the archive PR, with the complete ordered branch/parent/PR table. Keep superseded links separately. Repeat after any later creation or replacement, and fetch all bodies to verify bases, order, links, and absence of placeholders.

For each represented issue, mark only the delivered goals' checklist items complete and attach their PR numbers after all their PRs exist. Preserve other goals; partial publication leaves the affected item unchecked. Resolve an ambiguous goal entry before editing.

Fetch the issue again and run [dev-utils.sh](../../bin/dev-utils.sh) `issue-claimants <number>` before deleting live plans. Use `Closes #N` only when every active claimant belongs to this explicitly inventoried publication, all its goals have published PRs, and no deferred goal remains unchecked. Otherwise retain `Refs #N`. Only the final chain PR may close an issue; remove closing keywords from earlier active PRs and verify the updated bodies.

## Complete

Return PR URLs and any remaining cleanup. Claim completion only after [plan.md](plan.md)'s verification and cleanup succeed; publication does not mean merged or deployed. Follow-up work uses a new plan and [design-feature.md](design-feature.md)'s parent-selection rules.
