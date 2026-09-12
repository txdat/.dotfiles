# /create-pr — Publish Reviewed Work

Read [PROCESS.md](../../PROCESS.md) and resolve the named plan under [plan.md](plan.md). Entry is `reviewed` with a finalized PR Pattern. Publication runs in the recorded [worktrees](plan.md#worktree-operations). Default to draft unless `ready` is requested. If publication is already verified and only cleanup remains, use [cleanup-only resume](plan.md#cleanup-only-resume).

## Publish

1. Resolve the publication inventory under [plan.md](plan.md). For each code slice, resolve its explicit Parent to a commit before checking ancestry or diffs. Fetch origin as needed; when the branch exists only there, use `refs/remotes/origin/<parent>` for Git checks and `<parent>` for the GitHub base. Record the resolved SHA and confirm the local/remote refs and ancestry agree with the reviewed scope; resolve drift before proceeding.
2. Verify each code slice's nonempty diff and `Slice N (<branch>): green at <sha>` against its branch tip, allowing only [plan.md](plan.md)'s archive-only exception. Changed code returns to review. Verify both endpoints and a successful `git diff <parent-sha> <reviewed-code-tip>`, then run `~/.dotfiles/.ai-shared/bin/dev-check artifacts <parent-sha> <reviewed-code-tip>`. The helper can report PASS for invalid refs; its result alone is insufficient. For the leading docs entry, verify its Parent, snapshot commit, owned-path-only diff, approved contents, and documentation checks under [plan.md](plan.md#approved-snapshots); it requires no code-green claim.
3. Resolve existing PRs using the PR operations below, prepare the archive under [plan.md — Archive and cleanup](plan.md#archive-and-cleanup), and push verified branches in dependency order so every GitHub base exists before PR creation. Require a clean worktree before switching branches; preserve unrelated dirty root files.
4. Create PRs in dependency order: `docs (approved plans) → code 1 → code 2 → code 3`. Creation and merge order follow the same chain and reviewed Parents; the final code PR owns archival. Record each PR number/URL in every affected live plan immediately so subsequent PR bodies can link to it. Apply the body rules below at creation, then finish archive verification and cleanup under plan.md.

## PR operations

Before pushing, query all PR states for the repository and head. Reuse a matching open PR after checking its base and remote head against the reviewed branch and permitted archive commits. Allow expected fast-forward updates; resolve ambiguous matches or unexpected divergence.

For closed-unmerged work still required by the authorized scope, create a replacement after checking for an existing replacement on retries. Preserve the old PR and record its number/URL as `Supersedes` history in the replacement body and live plans. Active chain entries use the replacement. For merged PRs, verify what is already delivered before deciding further publication. If a replacement changes branches, reconcile downstream Parents under [review-code.md](review-code.md) before continuing.

Describe the change, rationale, verification, and limitations using the project template. Create every PR with `Refs #N` and no issue-closing keywords. Issue closure is a separate post-publication edit under the rules below. Write multiline bodies to files. Push the verified branch and create through [dev-github.sh](../../bin/dev-github.sh) `pr-create <title> <body-file> <parent> [--ready]`; edit existing bodies with `gh pr edit --body-file`.

## Synchronize bodies and issue links

At creation, include the ordered branch/parent table with PR links for entries that already exist, including every earlier PR in dependency order. Later entries without PRs use branch names only; do not predict PR numbers or add placeholders. Thus code PR 1 links to the docs PR, code PR 2 links to docs and code PR 1, and code PR 3 links to docs and code PRs 1 and 2. Keep superseded links separately.

Do not backfill later PR links into already-created bodies or run a blanket body-update pass. Fetch all bodies after publication to verify bases, chain order, and required earlier-PR links. Edit reused or replacement-affected bodies only to correct stale or missing required links; archive permalinks and issue-closing corrections below may still require a targeted edit.

For each represented issue, mark only the delivered goals' checklist items complete and attach their PR numbers after all their PRs exist. Preserve other goals; partial publication leaves the affected item unchecked. Resolve an ambiguous goal entry before editing.

After every inventoried PR exists, including the leading docs PR, and issue checklists and PR links are verified, fetch the issue again and run [dev-utils.sh](../../bin/dev-utils.sh) `issue-claimants <number>` before deleting live plans. Only when every active claimant belongs to this explicitly inventoried publication, all its goals have published PRs, and no deferred goal remains unchecked, edit the final code PR in dependency order to use `Closes #N`. Otherwise retain `Refs #N`; on partial publication or retries, remove any closing keywords whose prerequisites no longer hold. The leading docs PR and earlier code PRs use `Refs #N`; remove any closing keywords from them. Fetch the edited bodies to verify the result. This targeted closure edit is required even though routine chain-link backfilling is skipped.

## Complete

Return PR URLs and any remaining cleanup. Claim completion only after [plan.md](plan.md)'s verification and cleanup succeed; publication does not mean merged or deployed. Follow-up work uses a new plan and [design-feature.md](design-feature.md)'s parent-selection rules.
