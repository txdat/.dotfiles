# /create-pr — Publish Reviewed Work

Read [PROCESS.md](../../PROCESS.md) and resolve the named plan under [plan.md](plan.md). Entry is `reviewed` with a finalized PR Pattern. Publication runs in the recorded [worktrees](plan.md#worktree-operations). Default to draft unless `ready` is requested. Publication is a single run: once its first PR exists, the plan is terminal and this workflow is never re-entered.

## Publish

1. Resolve the publication inventory under [plan.md](plan.md). For each code slice, resolve its explicit Parent to a commit before checking ancestry or diffs. Fetch origin as needed; when the branch exists only there, use `refs/remotes/origin/<parent>` for Git checks and `<parent>` for the GitHub base. Record the resolved SHA and confirm the local/remote refs and ancestry agree with the reviewed scope; resolve drift before proceeding.
2. Verify each code slice's nonempty diff and `Slice N (<branch>): green at <sha>` against its branch tip, allowing only [plan.md](plan.md)'s archive-only exception. Changed code returns to review. Verify both endpoints and a successful `git diff <parent-sha> <reviewed-code-tip>`, then run `~/.dotfiles/.ai-shared/bin/dev-check artifacts <parent-sha> <reviewed-code-tip>`. The helper rejects unresolvable refs but cannot tell whether they are the reviewed endpoints. For the leading docs entry, verify its Parent, snapshot commit, owned-path-only diff, approved contents, and documentation checks under [plan.md](plan.md#approved-snapshots); it requires no code-green claim.
3. Check for existing PRs under the PR operations below, prepare the archive under [plan.md — Archive and cleanup](plan.md#archive-and-cleanup), and push verified branches in dependency order so every GitHub base exists before PR creation. Require a clean worktree before switching branches; preserve unrelated dirty root files.
4. Create PRs in dependency order: `docs (approved plans) → code 1 → code 2 → code 3`, using the reviewed Parents as publication bases; the final code PR owns archival. Record each PR number/URL in every affected live plan immediately so subsequent PR bodies can link to it, and mark the plans `published` after the first PR under [plan.md — Archive and cleanup](plan.md#archive-and-cleanup). Apply the body and merge-handoff rules below at creation, then finish archive verification and cleanup under plan.md.

## Merge handoff

PR bodies provide merge context for the maintainer: the intended integration branch, external parent PR dependencies, and dependency order. Record the integration branch separately from publication Parents, which may be unmerged dependency branches. Identify the intended integration branch from project configuration; check the repository's live merge/protection settings for applicable constraints. Resolve ambiguity before publication.

For dependent PRs, note that downstream bases must be reconciled as parents merge: retaining a parent branch does not deliver subsequent child merges to the integration branch. With squash or rebase merges, replaying undelivered changes can alter the delivered diff, so the maintainer re-verifies it and the required checks against the reviewed slice. Include a repository-prescribed merge strategy when one exists. When the final PR uses `Closes #N` but targets a non-default base, note that GitHub closes the issue only when that change merges into the default branch, so the maintainer confirms closure. These are maintainer notes, not an agent merge phase. The workflow ends with the publishing run; it never resumes to merge, retarget, rewrite branches, or finish cleanup.

## PR operations

Before the run's first push, query PRs in every state for each inventoried head branch. Stop and report if any is open or has a head commit between the branch's resolved Parent and its verified tip; publication never reuses, replaces, or re-publishes this work's PRs. Closed or merged PRs from unrelated earlier work on a reused branch name do not block. Within the run, retry a failed push or PR creation only after confirming it produced no PR.

Use [language.md](language.md) for PR titles and bodies. Describe the change, rationale, verification, and limitations using the project template. Create every PR with `Refs #N` and no issue-closing keywords. Issue closure is a separate post-publication edit under the rules below. Write multiline bodies to files. Push the verified branch and create through [dev-github.sh](../../bin/dev-github.sh) `pr-create <title> <body-file> <parent> [--ready]`; edit existing bodies with `gh pr edit --body-file`.

## Synchronize bodies and issue links

At creation, include the ordered branch/parent table with PR links for entries that already exist, including every earlier PR in dependency order. Later entries without PRs use branch names only; do not predict PR numbers or add placeholders. Thus code PR 1 links to the docs PR, code PR 2 links to docs and code PR 1, and code PR 3 links to docs and code PRs 1 and 2.

Do not backfill later PR links into already-created bodies or run a blanket body-update pass. Fetch all PR titles and bodies after publication to verify language, bases, chain order, required earlier-PR links, and the merge handoff; correct a mismatch with a targeted edit. Archive permalinks and the issue-closing edit below are also targeted edits.

For each represented issue, mark only the delivered goals' checklist items complete and attach their PR numbers after all their PRs exist. Preserve other goals; partial publication leaves the affected item unchecked. Resolve an ambiguous goal entry before editing.

After every inventoried PR exists, including the leading docs PR, and issue checklists and PR links are verified, fetch the issue again and run [dev-utils.sh](../../bin/dev-utils.sh) `issue-claimants <number>` before deleting live plans. Only when every active claimant belongs to this explicitly inventoried publication, all its goals have published PRs, and no deferred goal remains unchecked, edit the final code PR in dependency order to use `Closes #N`. Otherwise retain `Refs #N`. The leading docs PR and earlier code PRs always keep `Refs #N`. Fetch the edited bodies to verify the result. This targeted closure edit is required even though routine chain-link backfilling is skipped.

## Complete

After PR creation, agents must finish [plan.md](plan.md)'s publication verification and cleanup, return the PR URLs in the final response, and end the turn. CI and background jobs follow [AGENTS.md — Work](../../AGENTS.md#work).

Claim completion only after publication verification and safe cleanup succeed; otherwise report what remains for manual handling. Either way the workflow ends; a later invocation does not resume it. Publication does not establish CI success, merge, or deployment. Follow-up application changes use a new plan and [design-feature.md](design-feature.md)'s parent-selection rules.
