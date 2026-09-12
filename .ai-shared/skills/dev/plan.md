# Plan and Worktree Lifecycle

Owns application plan identity, location, ownership, lifecycle, worktree operations, and archival. [design-feature.md](design-feature.md) owns schema; [approval.md](approval.md) owns consent and changes.

## Live artifact

Every consumer names one exact `docs/plans/<file>.md`; design creates a new artifact. Do not select by slug, recency, or whichever plan happens to exist. Ask for an exact path when identity is missing or ambiguous.

Resolve the main working tree with [dev-utils.sh](../../bin/dev-utils.sh) `main-root`. The live file must be a direct child of that root's `docs/plans/`; nested paths, traversal, and cross-repository substitution are invalid. New plans are untracked; explicitly identified tracked, nonterminal legacy plans may continue in place. Inspect root HEAD, index, and working-tree state before editing or cleanup. All consumers read the authoritative root file; worktree copies are limited to the [approved snapshots](#approved-snapshots) and [archives](#archive-and-cleanup) below.

The main agent alone edits the plan, serializing updates and preserving unrelated work. Review-only requests do not authorize artifact edits.

## Lifecycle

`planning → approved → in-progress → implemented → reviewed → archived`. Phase skills own nonterminal completion conditions; approval.md owns amendments and abandonment. `archived` and `abandoned` are terminal and cannot resume. Revival or follow-up starts a new plan.

Keep the live root plan until publication and cleanup below succeed. Abandonment retains its root record. Archives from completed publications are historical records and remain untouched; copies from an incomplete publication follow the retry rules below. Recap may read an exact committed path/permalink or legacy issue-comment URL without recreating a live plan or worktree; identify the repository and plan from the source.

## Worktree operations

Default to one recorded worktree through execution, review, and publication. For a chain, record a publication inventory in the named plan: the leading docs branch, Parent, snapshot commit, plan paths, documentation checks, and worktree; each code slice's branch, reviewed tip, exact owning plan path, and worktree; and the final code worktree that owns archival. Each live plan retains its own root file and `Worktree:`; identify historical archives separately. Include only explicitly identified plans and reuse shared worktrees where practical.

- Create with [dev-worktree.sh](../../bin/dev-worktree.sh) `create <slug> <branch> <parent> [directory]`. Record its stdout path as `Worktree:` immediately.
- Before tests, `link-deps <worktree> [dependency names...]` links missing installed dependencies from the main root. This is valid only while dependency versions agree.
- Before any command that can change a linked dependency directory, run `isolate-dep <worktree> <dependency-directory>`. Proceed only after isolation succeeds; never install through a symlink into the main root's dependencies, because this can silently corrupt or change versions in the shared dependency tree other worktrees rely on.
- Resume the recorded path only after checking Git registration and branch ancestry against its Parent. Missing or mismatched state requires investigation, not a replacement plan.

Run code, tests, and branch Git operations in the worktree. Remove worktrees from the main root with normal `git worktree remove`, requiring clean status and checking untracked/ignored content for unrelated files. Preserve unrelated root/worktree changes and unpublished work; do not stash, reset, clean, or commit them to enable cleanup. Report removal refusals without forcing. Publication requires the checks below; [approval.md](approval.md) owns abandonment.

## Approved snapshots

For a chain, prepare the leading docs branch after spec approval and before implementation. In its recorded worktree, copy the approved root plans to their same `docs/plans/<file>.md` paths, preserving `Status: approved` and clearing only `Worktree:`. Inspect for sensitive content, run documentation checks, stage only the owned paths, and commit the snapshots. Record the commit and verification in the live publication inventory. This is local preparation; PR publication remains the create-pr phase.

Create the first code branch from that docs commit and each subsequent branch from its recorded Parent so every implementation branch inherits the plans. Keep the docs branch's approved snapshots stable; record later approved amendments and results in the live plans and include them in the final archive. On resume, verify the recorded snapshots and ancestry instead of recreating them. Never reconstruct an approved snapshot by relabeling an in-progress or reviewed plan; use preserved approval-time evidence. Adding a docs parent to existing implemented work requires parent reconciliation and re-review under [review-code.md](review-code.md).

## Archive and cleanup

Archive the inventoried live `reviewed` plans in the final code PR, updating its inherited approved snapshots. A single code PR owns its own archive. The leading docs PR retains the approved snapshots; do not add a trailing docs archive PR. The archive worktree below is the final code worktree. Code parent/ownership changes still follow [review-code.md](review-code.md).

Keep each plan at its own `docs/plans/<file>.md` path. Preserve and link historical archives already in the chain; resolve path collisions before copying. Only this incomplete publication's archive copies may receive metadata updates.

1. Before PR creation, record the chain and any already-known PR URLs in every affected live plan. In the clean archive worktree, copy each root file, changing only its header to `Status: archived` and empty `Worktree:`. Confirm the identity of any inherited approved snapshot or tracked nonterminal copy before replacing it.
2. Inspect every copy for sensitive content, run required documentation checks, and stage only these paths (`git add -f -- <path>` if ignored). Inspect the staged diff, commit `docs(plan): archive <basename>` (or a plural equivalent), and push. Archive-only commits touching these paths are the sole permitted additions above the final reviewed code tip. Retain code proof/green SHAs and end code artifact scans there.
3. Follow [create-pr.md](create-pr.md)'s dependency order: create the leading docs PR when present, then code PRs from first to last, recording each URL in all affected live plans. Apply its [body and issue-link rules](create-pr.md#synchronize-bodies-and-issue-links). After all PRs exist, refresh archive copies from the updated live sources with only the two header changes; repeat step 2 for necessary metadata follow-ups. Reuse verified commits on retries.
4. Verify every new archive separately at the published head: exact path, terminal headers, and byte-for-byte equality with its root source except the two header fields. Confirm the final PR contains every file, its remote head equals the local head, and all post-review commits touch only the owned archive paths. Link every archive at an immutable commit in the final PR body and fetch it to verify the links.
5. Save cleanup evidence using [handoff](../handoff.md): exact root paths, archive commits, PR URLs, branch tips, worktrees, and verification results. Then remove each distinct inventoried worktree path once under the removal checks above: the docs worktree and code worktrees, with the final code worktree also owning the archive. Confirm chain ownership and published branch tips first; never remove the main root. Record progress in the handoff without changing verified live plans.
6. After worktree removal, recompare each root file with its verified archive before deleting it. Untracked files need no commit. For files tracked in root HEAD, isolate their deletions in a local `docs(plan): remove archived live plans` commit and verify its complete path list. An index-only plan addition needs removal of its matching index entry, not a deletion commit. Preserve distinct staged content and unrelated changes; if isolation is unsafe, retain the affected file and report the blocker.

Root cleanup commits stay local unless pushing that branch and its outgoing commits is explicitly authorized. Report their SHA, branch, and pushed/unpushed state; an unpushed cleanup commit blocks completion only when its push is part of the task.

On failure, retain remaining live files/worktrees and report per-item progress. Completion requires verified publication, removal of all inventoried live files/worktrees, and required cleanup commits. Finish the handoff when cleanup succeeds.

### Cleanup-only resume

Resume verified publication's remaining cleanup from the main root using the saved handoff and the exact live paths or committed archives. Revalidate PR heads, archive contents, and worktree registration; skip completed removals only with evidence. Continue steps 5–6 without recreating removed worktrees or restarting publication. The current create-pr/ship-feature entry gate requires a registered worktree, so this is a direct cleanup continuation, not a new phase invocation. Missing or conflicting publication evidence requires investigation before further deletion.
