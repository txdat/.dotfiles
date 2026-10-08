# /create-pr — Publish Reviewed Work

Read [PROCESS.md](../../PROCESS.md) and resolve the named plan under [plan.md](plan.md). Entry is `reviewed` with a finalized PR Pattern. Publication runs in the recorded [worktrees](plan.md#worktree-operations). Default to draft unless `ready` is requested.

## Publish

1. For each slice, resolve its explicit Parent to a commit before checking ancestry or diffs. Fetch origin as needed; when the branch exists only there, use `refs/remotes/origin/<parent>` for Git checks and `<parent>` for the GitHub base. Record the resolved SHA and confirm local/remote refs and ancestry agree with the reviewed scope; resolve drift before proceeding.
2. Verify each slice's nonempty diff and `Slice N (<branch>): green at <sha>` against its branch tip, allowing only [plan.md](plan.md#archive-and-cleanup)'s archive-only exception; changed code returns to review. Verify both endpoints and a successful `git diff <parent-sha> <reviewed-code-tip>`, then run `~/.dotfiles/.ai-shared/bin/dev-check artifacts <parent-sha> <reviewed-code-tip>`. The helper rejects unresolvable refs but cannot tell whether they are the reviewed endpoints.
3. Check for existing PRs under the PR operations below, prepare the archive under [plan.md — Archive and cleanup](plan.md#archive-and-cleanup), and push verified branches in dependency order so every GitHub base exists before PR creation.
4. Create PRs from the first slice to the last, using the reviewed Parents as bases, recording each under plan.md's step 3. Apply the body and merge-handoff rules below at creation, then finish archive verification and cleanup under plan.md.

## Merge handoff

PR bodies give the maintainer merge context: the intended integration branch, external parent PR dependencies, dependency order, and any repository-prescribed merge strategy. Identify the integration branch from project configuration, check live merge/protection settings for constraints, and record it separately from publication Parents, which may be unmerged dependency branches. Resolve ambiguity before publication.

For dependent PRs, note that downstream bases must be reconciled as parents merge, and that squash or rebase merges can alter a replayed diff, so the maintainer re-verifies it against the reviewed slice. When the final PR uses `Closes #N` but targets a non-default base, note that GitHub closes the issue only when the change reaches the default branch. These are maintainer notes; the workflow never merges, retargets, or rewrites branches.

## PR operations

Before the run's first push, query PRs in every state for each head branch. Stop and report if any is open or has a head commit between the branch's resolved Parent and its verified tip; publication never reuses, replaces, or re-publishes this work's PRs. Closed or merged PRs from unrelated earlier work on a reused branch name do not block. Retry a failed push or PR creation only after confirming it produced no PR.

Use [language.md](language.md) for PR titles and bodies. Describe the change, rationale, verification, and limitations using the project template. Create every PR with `Refs #N` and no issue-closing keywords. Write multiline bodies to files. Push the verified branch and create through [dev-github.sh](../../bin/dev-github.sh) `pr-create <title> <body-file> <parent> [--ready]`; edit existing bodies with `gh pr edit --body-file`.

## Synchronize bodies and issue links

At creation, include the ordered branch/parent table, linking every earlier PR; later entries use branch names only, without predicted numbers or placeholders. Do not backfill later links into created bodies. After publication, fetch all PR titles and bodies to verify language, bases, chain order, earlier-PR links, and the merge handoff; fix mismatches with targeted edits.

For each represented issue, mark only the delivered goal's checklist items complete and attach their PR numbers after all its PRs exist. Preserve other goals; resolve an ambiguous goal entry before editing.

After all PRs exist and issue checklists and links are verified, fetch the issue again and run [dev-utils.sh](../../bin/dev-utils.sh) `issue-claimants <number>` before deleting the live plan. Only when the output lists no other active plan (this plan, already `published`, is excluded), all its goals have published PRs, and no deferred goal remains unchecked, edit the final PR to use `Closes #N`; every other PR keeps `Refs #N`. Fetch the edited body to verify it.

## Complete

After PR creation, finish [plan.md](plan.md#archive-and-cleanup)'s publication verification and cleanup, return the PR URLs, and end the turn. Claim completion only after they succeed; otherwise report what remains for manual handling. Either way the workflow ends and is never re-entered. Publication does not establish CI success, merge, or deployment. Follow-up changes use a new plan whose Parent follows [design-feature.md — PR slicing](design-feature.md#pr-slicing).
