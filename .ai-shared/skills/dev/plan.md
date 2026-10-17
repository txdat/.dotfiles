# Plan and Worktree Lifecycle

Owns application plan identity, location, ownership, lifecycle, worktree operations, and archival. [design-feature.md](design-feature.md) owns schema; [ids.md](ids.md) owns the IDs inside it; [approval.md](approval.md) owns consent and changes.

Use [language.md](language.md) for plan prose and subsequent updates.

## Live artifact

Every consumer names one exact `docs/plans/<file>.md`; design creates a new artifact. Do not select by slug, recency, or whichever plan happens to exist. Ask for an exact path when identity is missing or ambiguous.

Resolve the main working tree with [dev-utils.sh](../../bin/dev-utils.sh) `main-root`. The live file must be a direct child of that root's `docs/plans/`; nested paths, traversal, and cross-repository substitution are invalid. New plans are untracked; explicitly identified tracked, nonterminal legacy plans may continue in place. Inspect root HEAD, index, and working-tree state before editing or cleanup. All consumers read the authoritative root file; the only worktree copy is its [archive](#archive-and-cleanup).

The main agent alone edits the plan, serializing updates.

## Lifecycle

The plan follows `planning → approved → implemented → reviewed → archived`, and each phase sets at most one status:

| Phase | Sets |
|---|---|
| [design-feature](design-feature.md) | `planning` |
| [review-feature](review-feature.md) | none; records its verdict |
| [approval](approval.md#approve) | `approved` |
| [execute-feature](execute-feature.md) | `implemented` |
| [review-code](review-code.md) | `reviewed` |
| [create-pr](create-pr.md) | `archived` |
| [abandonment](approval.md#abandon) | `abandoned` |

An `approved` plan with a recorded `Worktree:` is mid-execution and resumes there. Phase skills own completion conditions; [approval.md](approval.md) owns amendments, which may return a plan to an earlier status, and abandonment. `archived` and `abandoned` are terminal and cannot resume; revival or follow-up starts a new plan.

Keep the live root plan until publication and cleanup below succeed. Abandonment retains its root record. Archives are historical records; never edit one after its commit. Recap may read an exact committed path/permalink or legacy issue-comment URL without recreating a live plan or worktree; identify the repository and plan from the source.

## Worktree operations

A single-PR plan uses one recorded worktree through execution, review, and publication. A chain gives every slice its own worktree, kept until publication cleanup, so each tip is reviewed and published without switching branches. `Worktree:` records the active slice's worktree, and the final slice's from review onward. For a chain, record every slice's worktree:

```text
## Publication Inventory
Worktree: PR-1 (<branch>) at <path>
```

- Create with [dev-worktree.sh](../../bin/dev-worktree.sh) `create <slug> <branch> <parent> [directory]`. Record its stdout path as `Worktree:` immediately.
- Before tests, `link-deps <worktree> [dependency names...]` links missing installed dependencies from the main root. This is valid only while dependency versions agree.
- Before any command that can change a linked dependency directory, run `isolate-dep <worktree> <dependency-name>`, for example `isolate-dep <worktree> node_modules`. The dependency must be a direct-child directory name. Proceed only after isolation succeeds; installing through a symlink changes the main root's dependencies that other worktrees rely on.
- Resume the recorded path only after checking Git registration and branch ancestry against its Parent. Missing or mismatched state requires investigation, not a replacement plan.
- Remove with `remove <worktree>`, for publication cleanup and [abandonment](approval.md#abandon) alike. It refuses the main root, an unregistered path, and a dirty or detached worktree; otherwise it removes the worktree, then deletes the local branch only when a fresh fetch shows `origin/<branch>` at the same tip. It prints `deleted <branch>` or `kept <branch>`, with the reason on stderr: unpushed commits, no origin counterpart, or origin unreachable. First check ignored content for unrelated files; removal deletes it without inspection, except that linked dependencies go as symlinks and their main-root targets remain.

Run code, tests, and branch Git operations in the worktree. Preserve unpublished work and unrelated root/worktree changes; do not stash, reset, clean, or commit them to enable cleanup. Report removal refusals without forcing.

## Archive and cleanup

The final PR — the only PR of a single-PR plan, or a chain's last slice — archives the plan in its own worktree; do not add a separate archive PR. Keep the archive at the plan's `docs/plans/<file>.md` path. Preserve and link historical archives already in the chain; resolve path collisions before copying.

1. Before PR creation, in the final slice's clean worktree, copy the root plan, changing only its header to `Status: archived` and empty `Worktree:`. Confirm the identity of any tracked nonterminal copy before replacing it.
2. Inspect the copy for sensitive content, run required documentation checks, and stage only its path (`git add -f -- <path>` if ignored). Inspect the staged diff, commit `docs(plan): archive <plan-file-stem>`, and push. Archive-only commits are the sole permitted additions above the final reviewed code tip; code proof, green SHAs, and artifact scans end there.
3. Once the first PR exists, set the live plan to `Status: archived`, so a failed cleanup cannot re-enter publication. PR URLs go in the final report, not the plan.
4. Verify the archive at the final PR's remote head, which must equal the local head: exact path, `archived` header, and every post-review commit touching only the archive path. Link the archive at an immutable commit in the final PR body and fetch it to verify the link.
5. Remove each slice's worktree with `remove <worktree>` under the rules above. Publication verified every slice branch on origin, so each must report `deleted`; a `kept` branch blocks completion until its mismatch with origin is resolved.
6. After worktree removal, delete the root plan. An untracked plan needs no commit. For a plan tracked in root HEAD, isolate its deletion in a local `docs(plan): remove archived live plan` commit and verify its path list; an index-only addition needs its index entry removed instead. Preserve distinct staged content and unrelated changes; if isolation is unsafe, retain the file and report the blocker.

Root cleanup commits stay local unless pushing that branch is explicitly authorized. Report their SHA, branch, and pushed state; an unpushed cleanup commit blocks completion only when its push is part of the task.

On publication verification or cleanup failure, stop: retain the live plan, remaining worktrees, and local branches, and report per-item progress — root path, archive commit, PR URLs, branch tips, and worktrees — for manual handling. Completion requires verified publication, removal of the live plan, worktrees, and local slice branches, and required cleanup commits.
