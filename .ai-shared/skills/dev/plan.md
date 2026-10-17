# Plan and Worktree Lifecycle

Owns application plan identity, location, ownership, lifecycle, changes, worktree operations, and archival. [design-feature.md](design-feature.md) owns schema; [ids.md](ids.md) owns the IDs inside it.

Use [language.md](language.md) for plan prose and subsequent updates.

## Live artifact

Every consumer names one exact `docs/plans/<file>.md`, except that a [chain review](review-feature.md#chain-review) or a [chain run](reference/related-plans.md#chain-runs) names each plan of the chain; design creates a new artifact. Do not select by slug, recency, or whichever plan happens to exist. Ask for an exact path when identity is missing or ambiguous.

Resolve the main working tree with [dev-utils.sh](../../bin/dev-utils.sh) `main-root`. The live file must be a direct child of that root's `docs/plans/`; nested paths, traversal, and cross-repository substitution are invalid. The live plan is untracked; a plan tracked in the main root is a published record, which no phase resumes or edits. Inspect root HEAD, index, and working-tree state before editing or cleanup. All consumers read the authoritative root file; the only worktree copy is its [archive](#archive-and-cleanup).

The main agent edits the plan; only the user sets `Status: approved`.

## Lifecycle

The plan follows `planning → approved → implemented → reviewed`, and each phase advances it at most one status:

| Phase | Sets |
|---|---|
| [design-feature](design-feature.md) | `planning` |
| [review-feature](review-feature.md) | none; reports its verdict |
| the user | `approved` |
| [execute-feature](execute-feature.md) | `implemented` |
| [review-code](review-code.md) | `reviewed` |
| [create-pr](create-pr.md) | none; commits the plan copy |

An `approved` plan with a recorded `Worktree:` is mid-execution and resumes there. Phase skills own completion conditions; a [change](#changes) may return a plan to `planning`. A code repair that reaches a `reviewed` plan, made on its own slices or [merged forward](#worktree-operations) from an earlier plan, voids its `Green:` records: the main agent returns it to `implemented`, along with every later plan the repair reaches, and review-code reviews each again. Delivery ends in one of two ways, and neither resumes; follow-up starts a new plan:

- Publication: create-pr commits the plan copy with the final PR, then deletes the live plan and its worktrees. Once merged, the copy is the tracked record.
- Stopping: the user deletes the live plan and removes its worktrees.

Keep the live root plan until publication and cleanup below succeed. Committed copies are historical records; never edit one after its commit. Recap may read an exact committed path/permalink or legacy issue-comment URL without recreating a live plan or worktree; identify the repository and plan from the source.

## Changes

An approved plan's spec (its DDs, ACs, TCs, fixtures, steps, and PR Pattern) is not edited. Execution and review add only records: PC results, `Test:` lines and proof, Green records, `Worktree:` and the Publication Inventory, Coverage Gaps, and Discovered Scope; review-code also removes `(provisional)` from the PR Pattern heading once the slices match the verified work. Execution decides only implementation details that are not design choices, such as names and internal structure.

Anything else stops the affected work: a failed PC, a fixture or obligation that cannot be met as specified, a step that cannot be followed, a different PR Pattern, or new scope (recorded as a `DS-n` entry). Present it to the user with options, tradeoffs, and one recommendation. If the user chooses to revise, set `planning`, revise under [design-feature.md](design-feature.md), re-review under [independence.md — Re-review](independence.md#re-review), and wait for the user to set `approved`. A revision reopens every later plan whose `After:` chain includes it.

## Worktree operations

A single-PR plan uses one recorded worktree through execution, review, and publication. A `Type: chain` plan gives every slice its own worktree, kept until publication cleanup, so each tip is reviewed and published without switching branches. `Worktree:` records the active slice's worktree, and the final slice's from review onward. For a `Type: chain` plan, record every slice's worktree:

```text
## Publication Inventory
Worktree: PR-1 (<branch>) at <path>
```

- Create with [dev-worktree.sh](../../bin/dev-worktree.sh) `create <slug> <branch> <parent> [directory]`. Record its stdout path immediately as `Worktree:` and, in a chain, as the slice's Publication Inventory line.
- Before tests, `link-deps <worktree> [dependency names...]` links missing installed dependencies from the main root. This is valid only while dependency versions agree.
- Before any command that can change a linked dependency directory, run `isolate-dep <worktree> <dependency-name>`, for example `isolate-dep <worktree> node_modules`. The dependency must be a direct-child directory name. Proceed only after isolation succeeds; installing through a symlink changes the main root's dependencies that other worktrees rely on.
- Resume the recorded path only after checking Git registration and branch ancestry against its Parent. Missing or mismatched state requires investigation, not a replacement plan.
- Remove with `remove <worktree>`, at publication cleanup or when the user stops the plan. It refuses the main root, an unregistered path, and a dirty or detached worktree; otherwise it removes the worktree, then deletes the local branch only when a fresh fetch shows `origin/<branch>` at the same tip. It prints `deleted <branch>` or `kept <branch>`, with the reason on stderr: unpushed commits, no origin counterpart, or origin unreachable. First check ignored content for unrelated files; removal deletes it without inspection, except that linked dependencies go as symlinks and their main-root targets remain.

A repair to a slice after a later slice has branched from it is committed on that slice's branch, in its worktree. Then merge it forward, in order: each later slice's branch merges its Parent in its own worktree. This includes a later plan's PR-1, whose Parent is this plan's last slice. Each slice then reruns its verification. Never rebase, reset, or force-push to propagate a repair, because the recorded PC results, proof, and `Green:` SHAs must stay in the branch history. Resolve conflicts in the merge commit; a resolution that changes approved behavior follows [Changes](#changes).

Run code, tests, and branch Git operations in the worktree. Preserve unpublished work and unrelated root/worktree changes; do not stash, reset, clean, or commit them to enable cleanup. Report removal refusals without forcing.

## Archive and cleanup

The final PR — the only PR of a single-PR plan, or a `Type: chain` plan's last slice — archives the plan in its own worktree at the plan's `docs/plans/<file>.md` path; there is no separate archive PR. [dev-publish.sh](../../bin/dev-publish.sh) is the only tool that copies or deletes the live plan, acting for the main agent:

- `archive` writes the copy, unchanged except for an empty `Worktree:`, and refuses a tracked plan already at that path; `archive --commit` commits it as `docs(plan): archive <plan-file-stem>`. Archive-only commits are the sole permitted additions above the final reviewed code tip; code proof, green SHAs, and artifact scans end there.
- `create` leaves the live plan unchanged. On a rerun it reports `EXISTS` for an open PR that targets the recorded Parent at the slice tip, and fails on any other open PR. PR URLs go in the final report, not the plan.
- `verify` checks the copy at the final PR's remote head and the body's link to it at an immutable commit.
- `cleanup` removes each slice's worktree, each of which must report `deleted`, then deletes the live plan.

On failure the script retains the live plan, remaining worktrees, and local branches; report its output for manual handling. A failed cleanup resumes by rerunning `cleanup`. Completion requires a passing verify and cleanup.
