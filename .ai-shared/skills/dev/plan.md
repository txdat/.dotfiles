# Plan and Worktree Lifecycle

Owns application plan identity, location, ownership, lifecycle, worktree operations, and archival. [design-feature.md](design-feature.md) owns schema; [approval.md](approval.md) owns consent and changes.

## Live artifact

Every consumer names one exact `docs/plans/<file>.md`; design creates a new artifact. Do not select by slug, recency, or whichever plan happens to exist. Ask for an exact path when identity is missing or ambiguous.

Resolve the main working tree with [dev-utils.sh](../../bin/dev-utils.sh) `main-root`. The live file must be an untracked direct child of that root's `docs/plans/`, including when supplied by absolute path. No nested paths, traversal, or cross-repository substitution. All consumers read this authoritative file; do not copy or symlink it into worktrees during execution.

The main agent alone edits the plan, serializing updates and preserving unrelated work. Review-only requests do not authorize artifact edits.

## Lifecycle

`planning → approved → in-progress → implemented → reviewed → archived`. Phase skills own nonterminal completion conditions; approval.md owns amendments and abandonment. `archived` and `abandoned` are terminal and cannot resume. Revival or follow-up starts a new plan.

Keep the live root plan until publication and cleanup below succeed. Abandonment retains its root record. Existing tracked archives are historical records and remain untouched. Recap may read an exact committed path/permalink or legacy issue-comment URL without recreating a live plan or worktree; identify the repository and plan from the source.

## Worktree operations

Use one recorded worktree through execution, review, and publication; leave unrelated root work untouched.

- Create with [dev-worktree.sh](../../bin/dev-worktree.sh) `create <slug> <branch> <parent> [directory]`. Record its stdout path as `Worktree:` immediately.
- Before tests, `link-deps <worktree> [dependency names...]` links missing installed dependencies from the main root. This is valid only while dependency versions agree.
- Before any command that can change a linked dependency directory, run `isolate-dep <worktree> <dependency-directory>`. Proceed only after isolation succeeds; never install through a symlink into the main root's dependencies.
- Resume the recorded path only after checking Git registration and branch ancestry against its Parent. Missing or mismatched state requires investigation, not a replacement plan.

Run code, tests, and branch Git operations in the worktree. For removal, run from the main root, require a clean worktree, and use normal `git worktree remove`. Report refusals rather than force removal. Publication requires the archive checks below; [approval.md](approval.md) owns abandonment.

## Archive and cleanup

After all PRs and their links are verified, archive the live `reviewed` plan in the final PR (the only PR for a single-slice plan).

1. In the clean worktree on the final branch, copy the root plan to its same `docs/plans/<file>.md` path. Change only the copy's header to `Status: archived` and empty `Worktree:`; leave the live plan unchanged.
2. Inspect the copy for sensitive content and run required documentation checks. Stage only that file (`git add -f -- <path>` if ignored), then commit `docs(plan): archive <basename>`. The commit adds only that file directly above the reviewed code tip; retain the original proof and green SHAs.
3. Push and verify the final PR contains the archive commit. Compare the committed file with the root plan allowing only the two header differences, and link the committed file in the final PR body.
4. Remove the clean worktree using the checks above. Recheck the exact untracked root file against the committed copy with the same permitted differences, then delete only that root file.

A verified archive-only commit is the sole allowed addition above the final reviewed tip during publication. Code artifact scans end at the reviewed code tip; the archive uses step 2's documentation checks. If the identical archive commit already exists, reuse it and continue at step 3.

On failure, retain the live plan and any remaining worktree, report the failure and remaining cleanup for the user, and stop. Completion requires verified publication and successful cleanup.
