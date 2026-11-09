# /split-pr-atomic — Split a PR into Atomic PRs

Split one open PR into a stack of smaller PRs that together carry exactly its diff, then close the original with a link to them. Run only on the user's explicit request; no phase starts or suggests it. Pass a PR number or URL, or a `published` plan path, whose PR is `gh pr list --head <Branch> --state open`. A published plan is frozen ([plan.md — Sequence](plan.md#sequence)): read it, never edit it or run `dev-stack.sh` or `dev-publish.sh` on it. Slices are PRs, not plans. Write PR bodies and comments under [plan.md](plan.md#artifact)'s language rule.

## 1. Resolve

Run `gh pr view <PR> --json number,url,state,title,body,author,isCrossRepository,baseRefName,headRefName,headRefOid`, then `git fetch origin`. Stop on a merged, closed, or cross-repository PR, or when `origin/<head>` is not `headRefOid`. `H` is that SHA, `M` is `git merge-base origin/<base> H`, and the diff is `git diff M H`. When `gh pr list --base <head> --state open` lists PRs stacked on it, they keep their diffs only if the last slice is merged into each of their branches: include that in the proposal or stop.

## 2. Rules

The project's atomic-PR rules, from its AGENTS.md, CLAUDE.md, or the docs they reference, decide what one PR holds. Without them:

- One PR delivers one independent behavior with its tests, docs, and version notes.
- These come apart, the prerequisite first: a behavior-preserving refactor from the change it enables; a flag, contract, schema, or generated code from its consumers; a data migration or dependency upgrade from the rest.
- Call-sites that must change together for one behavior to stay consistent stay together; say what splitting them would break.
- Each PR is correct and safe to merge after the PRs below it alone, with incomplete behavior unexposed.

## 3. Propose

Assign every hunk to exactly one slice, in dependency order; tests go with the behavior they prove. A rename, a binary file, or a mode change is one unit in one slice. Show the user, then wait:

| Slice | Branch | Base | Goal | Files/hunks | Tests | Why it stands alone; why not split further |
|---|---|---|---|---|---|---|

Add a column for each field the project's atomic-PR rules require of every PR, such as an atomic ID, acceptance criteria, or rollback. Branches follow the project's convention, else `<head>-s<k>`. Slice 1 targets the original base; each later slice targets the one before it. Also list any **glue** a slice needs to build that the diff lacks, with the later slice that removes it; any **per-PR artifact** the project requires in every PR, such as a version bump, with how it is handled and the lines it leaves in `git diff H <last slice>`; each stacked PR's merge of the last slice and retarget onto it; and the author when it is not the active `gh` user. If the diff is already one atomic unit, say so and stop. Approval authorizes the pushes, the draft PRs, the listed merges and retargets, and closing the original; any change to the slicing needs approval again.

## 4. Build

Create the worktree with [dev-worktree.sh](../../bin/dev-worktree.sh) `create <issue>_<slug>-split <slice 1 branch> M`, taking `<issue>_<slug>` from the plan directory, else `0_pr<number>`, and link dependencies with `link-deps` under [plan.md — Worktree](plan.md#worktree). Branch each later slice from the one before it with `git switch -c`. Take a unit whole with `git checkout H -- <path>` (with `git rm` for a deletion or a rename's old path) when all its remaining changes belong to this slice; otherwise cut `git diff --binary HEAD H -- <path>` to this slice's hunks under `/tmp` and `git apply --index` it. Add nothing beyond the approved glue and artifacts. Commit under the project's conventions, reusing the original messages where they fit. Never rebase or force-push, and never touch the original branch.

## 5. Verify

First run the project's local checks, with the tests affected by the whole PR under [CODING.md — Tests](../../CODING.md#tests), at `H` in `dev-worktree.sh scratch <name> H` as the baseline, then `scratch-remove` it; a check already failing there does not count against a slice. At each slice tip, run the project's local checks, the slice's tests, and affected tests. Run a behavior slice's new tests at the slice below in `dev-worktree.sh scratch <name> <slice below> <test patch>`, then `scratch-remove` it; report any that pass there, since it suggests misplaced hunks. A new failure means a wrong cut: stop and propose a revised slicing. To rebuild after approval, discard the uncommitted attempt in this run's worktree, `dev-worktree.sh remove` it, `git branch -D` this run's slice branches, none of them pushed yet, and start step 4 again; each rebuild counts against the attempt limit in [CORE.md — Work](../../CORE.md#work). Finally, `git diff H <last slice>` may show only the per-PR artifact lines approved in step 3; anything else blocks publication. That check proves the final tree, not each slice's contents, so read each slice's diff against its approved hunks.

## 6. Publish

Parents first: `git push -u origin <branch>` (never force), then `gh pr create --base <target> --head <branch> --title <title> --body-file <file> --draft`, ready only when the user asks; on a rerun, skip `gh pr create` for a slice whose PR is already open on its target. Titles and bodies follow the project's rules and [create-pr.md](create-pr.md)'s body rules, adding `Split from #<original>`. Once every slice PR is open, for each stacked PR: stop if a local branch of its head differs from `origin/<its head>`; in a worktree from `dev-worktree.sh create <name> <its head> origin/<its head>`, merge the last slice, stopping on a conflict, push, remove the worktree, and run `gh pr edit <PR> --base <last slice branch>`. Confirm `headRefOid` is still `H`, else stop, then run `gh pr close <original> --comment <chain in merge order>`, keeping its branch on origin.

## 7. Clean up and report

Run `dev-worktree.sh remove <worktree>`, then delete each other local slice branch whose tip matches `origin`. Report the PR URLs in merge order, the original's closure, each slice's check results against the baseline, noting they ran on the base at `M`, each PR's mergeable state, any glue and artifacts, and CI as unverified unless results are known ([CORE.md — Work](../../CORE.md#work)).
