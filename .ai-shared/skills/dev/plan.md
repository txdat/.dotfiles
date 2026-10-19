# Plan-Backed Delivery

The shared contract for application plans. Phase skills say how to do each phase; this file owns what they share.

## Scope

The workflow applies when the user invokes a phase: design-feature, review-feature, execute-feature, review-code, or create-pr. It governs application code and developer tooling other than this dev flow, with their tests, including refactors. Docs, declarative config, and this dev flow — its skills and its [scripts](../../bin) with their tests — take the direct-edit path under [AGENTS.md — Work](../../AGENTS.md#work), even inside plan work; mixed changes follow the workflow for their governed part.

## Sequence

**design-feature → review-feature → user sets `Status: approved` → execute-feature → review-code → create-pr**

| Status | Set by |
|---|---|
| `planning` | design-feature, or any revision |
| `approved` | the user only |
| `implemented` | execute-feature, or any change that voids a Green line |
| `reviewed` | review-code |

create-pr publishes the plan and deletes the live copy. A gate blocks each phase until its entry status holds.

## Artifact

The live plan is `docs/plans/<issue>_<type>_<slug>.spec.md` in the main working tree (resolve it with [dev-utils.sh](../../bin/dev-utils.sh) `main-root`). `<issue>` is the issue number, or `0` when none is linked; `<type>` is `feature`, `fix`, or `refactor`. The live plan is untracked; a tracked plan is a published record, which no phase resumes or edits. Every phase takes exactly one plan path; never pick a plan by slug or recency.

Write plan, PR, and review prose in the linked issue's primary language, or English without one. Keep headings, field names, statuses, IDs, code, and paths as written below.

## Schema

Write these lines unfenced in the plan:

```text
# <title>
Status: planning | Type: feature|fix|refactor | Base: <branch> | Issue: #N|none | Worktree:
Stacks On: <docs/plans/... of the parent plan; stacked plans only, omit otherwise>
## Goal
## Scope
<in / out>
## Design Decisions
DD-1 — <decision>
  Options: <considered> | Choice: <chosen, by whom> | Why: <rationale, derivation>
## Acceptance Criteria
AC-1 — <observable outcome>
  Source: <goal, contract, or requirement>
  Success: <observable result>
  Failure: <violating result>
## Test Cases
TC-1 — <scenario>
  Proves: AC-1
  Fixture: <concrete inputs and starting state>
  Action: <operation or event sequence>
  Expected: <exact result and final state, including what must not change>
  Test: <path::name> — RED at <sha>: <failure>, or baseline at <sha> for a refactor; filled by execute-feature
## Implementation Steps
ST-1 — <change, files/symbols> — satisfies TC-1
  PC-1 — <fact about current code the step relies on> — Check: <command that fails when the fact is false>
## PR Pattern
| PR | Branch | Parent | Steps | Summary |
|---|---|---|---|---|
| PR-1 | feat/x-1 | <Base> | ST-1 | <outcome> |
Green: PR-1 (feat/x-1) at <sha>, recorded by review-code
```

Optional sections: `## Context`, `## Affected Existing Tests` (how to find them and the expected effect). Omit Design Decisions when there are none.

IDs are `AC`, `TC`, `ST`, `PC`, `PR`, and `DD`, numbered from 1, never renumbered or reused. Declare each at the start of a line in its own section — PR IDs in the table's first cell — outside code fences. List IDs one by one, never as ranges. Cite only this plan's IDs; refer to other artifacts by path. Each TC proves exactly one AC and belongs to the one PR row whose steps include its tests and the code they need. Every AC, TC, and ST is linked; each ST belongs to exactly one PR row; every row has a Parent. The gate checks this shape at review-feature and review-code.

## Changes

An approved spec — Goal, Scope, DDs, ACs, TCs, steps, PR Pattern — is frozen. Execution and review only add records: `Worktree:`, `Test:` lines with their RED results, and `Green:` lines; a PR's last Green line is the current one. Execution decides only details that are not design choices, such as names and internal structure.

Anything else stops the affected work: a failed PC, an unmeetable fixture or obligation, a step that cannot be followed, a different PR Pattern, or new scope. Bring the user options, tradeoffs, and a recommendation. If the user chooses to revise: set `planning`, revise, re-review, and wait for approval again. The worktree stays; existing Green lines are void until review-code records them again.

## Stacks

When a goal spans several plans, they form a stack that shares the issue. Each plan stacks on at most one parent, a parent may carry several children, and the stack never cycles; a plan's parent, the parent's parent, and so on are the plans below it. Two plans neither of which is below the other change disjoint files; when they cannot, stack one on the other. A contract between plans belongs to the plan that provides it, in its Design Decisions or a contract file it ships, proven by its ACs and TCs.

A child names its parent in `Stacks On:` and is designed against the specs below it as if implemented. It cites none of their IDs: it restates each contract fact it relies on as a PC. It uses the parent's Base, and its PR-1 Parent is the parent's last branch. Its review requires the parent `approved` or later; its execution and code review require it `reviewed`. Its integration TCs exercise the real code below it; mocks of the contract do not prove integration.

The stack publishes at once as the last step: when every plan in it is `reviewed`, create-pr runs once, on the root, and publishes every plan. A published plan never becomes a parent; later work waits for the stack to merge and starts a new stack on Base.

Whoever revises a plan returns every plan above it to `planning` when the contract changes. Only the user drops a plan, and only while it is `planning` with no `Worktree:`; a plan executed once is revised instead. Delete its live plan. Each of its children returns to `planning` and stacks on the dropped plan's parent, or, when the root was dropped, deletes its `Stacks On:` line and uses Base as PR-1's Parent.

## Worktree

One worktree per plan; slices are stacked branches in it.

- Create it only with [dev-worktree.sh](../../bin/dev-worktree.sh) `create <slug> <branch> <parent>`, with the plan filename's `<slug>` and no directory argument, and record the printed path, `$HOME/work/ai-worktrees/<repo>-<slug>`, as `Worktree:`. Create each later slice's branch inside it with `git switch -c <branch> <parent-branch>` once the parent slice passes its checks.
- The worktree stays until create-pr's cleanup. If it is missing earlier, stop and report it.
- `link-deps <worktree>` links installed dependencies from the main root. Before any command that changes a linked dependency directory, run `isolate-dep <worktree> <name>`; installing through the symlink corrupts the main root.
- Run code, tests, and branch Git operations in the worktree. Never stash, reset, or clean to get past unrelated changes in the worktree or the main root.
- Fix an earlier slice on its own branch, then merge it forward into each later slice and rerun their checks. A change to a parent's last branch after a child branched from it merges forward into the child's slices the same way, and on up the stack. Never rebase, reset, or force-push.

## Review

When this session wrote the artifact, run the review in a fresh subagent without the conversation. Give it only [CODING.md](../../CODING.md), the review skill and the files it links, the artifact path, the user's request, the worktree and refs it needs, and, for a re-review, the prior findings and what changed. A stacked plan's reviewer also reads the plans below it. If no subagent is available, review directly and say so.

Preferences and style never block. The reviewer is read-only: it may read, run tests, and inspect Git, but never edits files, mutates Git or switches branches, or changes status. The main agent repairs. A review-only request returns findings and changes nothing.

Round 1 covers the whole artifact. A re-review covers the prior findings and what the repair changed. After two re-reviews in one review phase, stop and report the remaining blockers; the user decides whether to narrow, decide, or grant more rounds.

## Verification

Test-first, per slice:

1. **RED.** Turn each TC's fixture, action, and expected result into a test. Run it against the unchanged parent: it must fail for the intended missing behavior — fixture, import, and syntax failures do not count. Refactors instead start with passing tests of the behavior they preserve.
2. Commit only the tests, plus throwing stubs where a new API needs them, as `test(red): <scope>`, or `test: baseline <scope>` for a refactor. The gate counts these subjects. Run `~/.dotfiles/.ai-shared/bin/dev-check proof <commit> [--test <path>] [--stub <path>]` and read the diff. Fill each TC's `Test:` line with the test, the commit SHA, and its RED failure, or the baseline result for a refactor.
3. **GREEN.** Implement, run the tests, and commit the implementation separately. When it is unclear whether an assertion really depends on the behavior, break the behavior briefly and confirm the test fails.

Rules:

- If a fixture cannot be built or an expected result would need invented semantics, stop under [Changes](#changes). Never take an expected result from production output, and never relax an obligation to make a test pass.
- Restructuring test code must keep each scenario's distinguishing conditions and expected result.
- Assertions must tell the required result from a plausible wrong one. Snapshots, mock-call checks, and mocked adapters standing in for queries or transactions are weak evidence.
- At each slice tip, run the project's local checks (lint, build, whatever CI runs), the slice's TC tests, and affected existing tests.

## Git identity

Use the configured Git identity and active `gh` account. Never invent authors, switch accounts, or inject tokens; missing identity or auth blocks the operation.
