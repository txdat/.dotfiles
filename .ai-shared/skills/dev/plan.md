# Plan and Worktree Lifecycle

Owns application plan identity, location, ownership, lifecycle, worktree operations, and archival. [design-feature.md](design-feature.md) owns schema; [approval.md](approval.md) owns consent and changes.

Use [language.md](language.md) for plan prose and subsequent updates.

## Live artifact

Every consumer names one exact `docs/plans/<file>.md`; design creates a new artifact. Do not select by slug, recency, or whichever plan happens to exist. Ask for an exact path when identity is missing or ambiguous.

Resolve the main working tree with [dev-utils.sh](../../bin/dev-utils.sh) `main-root`. The live file must be a direct child of that root's `docs/plans/`; nested paths, traversal, and cross-repository substitution are invalid. New plans are untracked; explicitly identified tracked, nonterminal legacy plans may continue in place. Inspect root HEAD, index, and working-tree state before editing or cleanup. All consumers read the authoritative root file; the only worktree copy is its [archive](#archive-and-cleanup).

The main agent alone edits the plan, serializing updates.

## Lifecycle

The live plan follows `planning → approved → in-progress → implemented → reviewed → published`. It becomes `published` when its first PR exists; only its archive copy receives `Status: archived`. Phase skills own nonterminal completion conditions; [approval.md](approval.md) owns amendments and abandonment. `published` and `abandoned` live plans and `archived` copies are terminal and cannot resume; revival or follow-up starts a new plan.

Keep the live root plan until publication and cleanup below succeed. Abandonment retains its root record. Archives are historical records and remain untouched once the publishing run ends. Recap may read an exact committed path/permalink or legacy issue-comment URL without recreating a live plan or worktree; identify the repository and plan from the source.

## Worktree operations

A single-PR plan uses one recorded worktree through execution, review, and publication. A chain gives every slice its own worktree, kept until publication cleanup, so each tip is reviewed and published without switching branches. `Worktree:` records the active slice's worktree, and the final slice's from review onward. For a chain, record every slice's worktree:

```text
## Publication Inventory
1 | <branch> | worktree: <path>
```

- Create with [dev-worktree.sh](../../bin/dev-worktree.sh) `create <slug> <branch> <parent> [directory]`. Record its stdout path as `Worktree:` immediately.
- Before tests, `link-deps <worktree> [dependency names...]` links missing installed dependencies from the main root. This is valid only while dependency versions agree.
- Before any command that can change a linked dependency directory, run `isolate-dep <worktree> <dependency-name>`, for example `isolate-dep <worktree> node_modules`. The dependency must be a direct-child directory name. Proceed only after isolation succeeds; installing through a symlink changes the main root's dependencies that other worktrees rely on.
- Resume the recorded path only after checking Git registration and branch ancestry against its Parent. Missing or mismatched state requires investigation, not a replacement plan.

Run code, tests, and branch Git operations in the worktree. Remove worktrees from the main root with normal `git worktree remove`, requiring clean status and checking untracked/ignored content for unrelated files. Preserve unpublished work and unrelated root/worktree changes; do not stash, reset, clean, or commit them to enable cleanup. Report removal refusals without forcing.

## Archive and cleanup

The final PR — the only PR of a single-PR plan, or a chain's last slice — archives the plan in its own worktree; do not add a separate archive PR. Keep the archive at the plan's `docs/plans/<file>.md` path. Preserve and link historical archives already in the chain; resolve path collisions before copying. Only archive copies created in the current run may receive metadata updates.

1. Before PR creation, in the clean archive worktree, copy the root plan, changing only its header to `Status: archived` and empty `Worktree:`. Confirm the identity of any tracked nonterminal copy before replacing it.
2. Inspect the copy for sensitive content, run required documentation checks, and stage only its path (`git add -f -- <path>` if ignored). Inspect the staged diff, commit `docs(plan): archive <plan-file-stem>`, and push. Archive-only commits are the sole permitted additions above the final reviewed code tip; code proof, green SHAs, and artifact scans end there.
3. During [create-pr.md](create-pr.md), record each PR URL in the live plan as it is created and set `Status: published` after the first. After all PRs exist, refresh the archive copy from the updated live plan with only the two header changes, repeating step 2.
4. Verify the archive at the published head: exact path, terminal headers, and byte-for-byte equality with the root plan except those two fields. Confirm the final PR's remote head equals the local head and every post-review commit touches only the archive path. Link the archive at an immutable commit in the final PR body and fetch it to verify the link.
5. Remove each slice worktree under the removal checks above after confirming its published branch tip; never remove the main root.
6. After worktree removal, recompare the root plan with its verified archive, then delete it. An untracked plan needs no commit. For a plan tracked in root HEAD, isolate its deletion in a local `docs(plan): remove archived live plan` commit and verify its path list; an index-only addition needs its index entry removed instead. Preserve distinct staged content and unrelated changes; if isolation is unsafe, retain the file and report the blocker.

Root cleanup commits stay local unless pushing that branch is explicitly authorized. Report their SHA, branch, and pushed state; an unpushed cleanup commit blocks completion only when its push is part of the task.

On publication verification or cleanup failure, stop: retain the live plan and remaining worktrees, and report per-item progress — root path, archive commit, PR URLs, branch tips, and worktrees — for manual handling. Completion requires verified publication, removal of the live plan and worktrees, and required cleanup commits.
