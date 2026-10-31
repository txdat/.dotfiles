# Plan-Backed Delivery

The shared contract for application plans. Phase skills say how to do each phase; this file owns what they share.

## Scope

The workflow applies when the user invokes a phase: design-feature, review-feature, execute-feature, review-code, or create-pr, or [run-stack](run-stack.md), which runs review-feature through create-pr. It governs application code and developer tooling other than this dev flow, with their tests, including refactors. Docs, declarative config, and this dev flow — its skills and its [scripts](../../bin) with their tests — take the direct-edit path under [AGENTS.md — Work](../../AGENTS.md#work), even inside plan work; mixed changes follow the workflow for their governed part.

## Sequence

**design-feature → review-feature → user sets `Status: approved` → execute-feature → review-code → create-pr**

| Status | Set by |
|---|---|
| `planning` | design-feature, or any revision |
| `needs-changes`, `ready` | review-feature's verdict, recorded with `Spec:` |
| `approved` | the user only, from `ready` |
| `implemented` | execute-feature, or any change to a reviewed Branch |
| `reviewed` | review-code, with `Tip:` set to the tip it passed |
| `published` | create-pr's cleanup |

A gate blocks each phase until its entry status holds. No phase resumes or edits a published plan.

## Artifact

One plan delivers one PR. Plans live outside the repository, at `~/work/plans/<repo>/<issue>_<slug>/pr<N>.spec.md`: `<repo>` is the main working tree's directory name ([dev-utils.sh](../../bin/dev-utils.sh) `main-root`), `<issue>` the issue number or `0`, and `<slug>` lowercase words joined by hyphens. One directory holds one stack; a parent's number is below its children's. Plans are never committed: the code, its tests, and the PR carry what ships. Every phase takes exactly one plan path; never pick a plan by slug or recency.

Write plan, PR, and review prose in the linked issue's primary language, or English without one. Keep headings, field names, statuses, IDs, code, and paths as written below.

## Schema

Write these lines unfenced in the plan:

```text
# <title>
Status: planning
Spec: -
Tip: -
Type: feature|fix|refactor
Base: <branch>
Branch: <branch>
Issue: #N|none
Stacks On: pr<K>
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
## Implementation Steps
ST-1 — <change, files/symbols> — satisfies TC-1
  PC-1 — <fact about current code the step relies on> — Check: <command that fails when the fact is false>
```

The header is the `<Key>: <value>` lines between the title and the first `##` heading, outside code fences, one field per line; the first line of each key counts. `Spec:` binds the last verdict to the spec it judged, set by [dev-stack.sh](../../bin/dev-stack.sh) `review`; `Tip:` is the Branch tip review-code passed. Both start as `-` and change in place. `Branch:` is the plan's PR branch, never its Base. `Stacks On:` names the parent plan in this directory, numbered below this one; the root omits it. The PR targets the parent's Branch, or Base for the root.

Optional sections: `## Context`, `## Affected Existing Tests` (how to find them and the expected effect). Omit Design Decisions when there are none.

IDs are `AC`, `TC`, `ST`, `PC`, and `DD`, numbered from 1, never renumbered or reused. Declare each at the start of a line in its own section, outside code fences. List IDs one by one, never as ranges. Cite only this plan's IDs; refer to other artifacts by path. Each TC proves exactly one AC, and every AC, TC, and ST is linked. The gate checks this shape at review-feature and review-code.

## Changes

After approval only `Status:` and `Tip:` change; everything else in the plan is frozen. To approve, the user changes `ready` to `approved` and leaves `Spec:` as it is. run-stack records its stops in the stack directory's `stops.log`. Execution decides only details that are not design choices, such as names and internal structure.

Anything else stops the affected work: a failed PC, an unmeetable fixture or obligation, a step that cannot be followed, a different PR split, or new scope. Bring the user options, tradeoffs, and a recommendation. If the user chooses to revise: set `planning`, revise, re-review, and wait for approval again. The worktree stays.

## Stacks

When a goal needs several PRs, each gets its own plan, and the plans form a stack in one directory that shares the issue. Every plan but the root, the lowest-numbered, stacks on one parent; a parent may carry several children. A plan's parent, the parent's parent, and so on are the plans below it. Two plans neither of which is below the other change disjoint files; when they cannot, stack one on the other. A contract between plans belongs to the plan that provides it, in its Design Decisions or a contract file it ships, proven by its ACs and TCs.

A child is designed against the specs below it as if implemented. It cites none of their IDs: it restates each contract fact it relies on as a PC. It uses the parent's Base. Its review requires the parent `approved` or later; its execution and code review require it `reviewed`. Its integration TCs exercise the real code below it; mocks of the contract do not prove integration.

The stack publishes at once as the last step: when every plan in it is `reviewed`, create-pr runs once, on the root, and publishes every plan. A published plan never becomes a parent; later work waits for the stack to merge and starts a new stack directory on Base.

Whoever revises a plan returns every plan above it to `planning` when the contract changes. Only the user drops a plan, and only while it is `planning` and its Branch does not exist; a plan executed once is revised instead. Delete its file. Each of its children returns to `planning` and stacks on the dropped plan's parent; when the root was dropped, its lowest-numbered child becomes the root by deleting its `Stacks On:` line, and the other children stack on it.

## Worktree

A plan's worktree is found, never recorded: its own at `~/work/wt/<repo>-<issue>_<slug>-pr<N>`, or, once its Branch exists, its parent's. A plan shares its parent's worktree when no other plan stacks on that parent at setup; otherwise, as does a sibling designed later, it creates its own. The create-pr gate refuses a worktree shared between siblings. A linear stack runs in one worktree.

- Create one only with [dev-worktree.sh](../../bin/dev-worktree.sh) `create <issue>_<slug>-pr<N> <Branch> <target>`, where target is the PR target (`origin/<Base>` without a local Base); on an existing Branch it reattaches that Branch as it is. To share, run `git switch -c <Branch> <parent Branch>` in the parent's worktree.
- Append the repo-relative directories the plan changes, plus those its build and tests read, to make a cone-mode sparse checkout; root files always come along. Omit them for a full checkout. In a sparse worktree, run `git sparse-checkout add <dir>` before a phase, a child sharing it, or a merge forward touches another directory.
- One phase runs in a worktree at a time, on the plan's own Branch. A repair to a parent that shares its worktree waits until the child's running phase returns.
- The worktree stays until create-pr's cleanup: a child sharing it returns it to the parent's Branch, and the plan that created it removes it. If it goes missing earlier, recreate it with `create`, passing the directories again; nothing records them.
- `link-deps <worktree>` links installed dependencies from the main root. Before any command that changes a linked dependency directory, run `isolate-dep <worktree> <name>`; installing through the symlink corrupts the main root.
- Run code, tests, and branch Git operations in the worktree. Never stash, reset, or clean to get past unrelated changes in the worktree or the main root.
- Fix a plan on its own Branch, then merge it forward into each plan above it and rerun their checks; a merge that changes a reviewed plan's tip returns it to `implemented`. Never rebase, reset, or force-push.

## Review

When this session wrote the artifact, run the review in a fresh subagent without the conversation: the [dev-reviewer](../../agents/dev-reviewer.md) agent where installed, on the model and effort [README](../../README.md#skills) gives the review skill. Give it only [CODING.md](../../CODING.md), the review skill and the files it links, the artifact path, the user's request, the worktree and refs it needs, and, for a re-review, the prior findings and what changed. A review-code reviewer outside a review-only request also gets its round's scratch path. A stacked plan's reviewer also reads the plans below it. If no subagent is available, review directly and say so.

Preferences and style never block. The reviewer may read, run tests, and inspect Git. It edits files only in its review-code round's scratch and under `/tmp`, never inside a linked dependency, and never commits, touches refs, the stash, or status, or installs dependencies. The main agent repairs. A review-only request gets no scratch, returns findings, and changes nothing.

Outside a review-only request, each review-code round runs in a scratch from [dev-worktree.sh](../../bin/dev-worktree.sh) `scratch <issue>_<slug>-pr<N>-r<round> <tip SHA> [<repro> ...]`, run from the plan's worktree. The main agent passes each open finding's saved repro; when `scratch` reports one as not applying, it retries without it and gives it to the reviewer to rebuild. On a tip that changes a dependency manifest, it runs `isolate-dep` and installs in every scratch it opens. Each `ran` finding carries its repro from `scratch-diff <scratch> -- <its files>`. Before repairing, the main agent saves each blocking `ran` finding's repro under `/tmp`, reruns its command in a fresh `scratch <issue>_<slug>-pr<N>-r<round>-f<k> <tip SHA> <repro>`, and removes that scratch. A finding that does not reproduce goes back to the reviewer once, resumed where possible; if it still does not, the main agent relabels it `traced`, `located`, or `asserted` by the evidence left. Then the round ends with `scratch-remove` on its scratch.

A verdict holds while the spec and the specs below it are unchanged: the spec hash ignores only the header's Status, Spec, and Tip lines, and [dev-stack.sh](../../bin/dev-stack.sh) compares it with `Spec:`. The execute-feature, review-code, and create-pr gates require a current ready `Spec:`; create-pr requires one for every plan in the stack.

Round 1 covers the whole artifact. A re-review covers the prior findings and what the repair changed. After two re-reviews in one review phase, stop and report the remaining blockers; the user decides whether to narrow, decide, or grant more rounds.

## Verification

Test-first:

1. **RED.** Turn each TC's fixture, action, and expected result into a test. Run it against the unchanged PR target: it must fail for the intended missing behavior — fixture, import, and syntax failures do not count. Refactors instead start with passing tests of the behavior they preserve.
2. Commit only the tests, plus throwing stubs where a new API needs them, as `test(red): <scope>`, or `test: baseline <scope>` for a refactor. The gate counts these subjects. Run `~/.dotfiles/.ai-shared/bin/dev-check.sh proof <commit> [--test <path>] [--stub <path>]` and read the diff.
3. **GREEN.** Implement, run the tests, and commit the implementation separately. When it is unclear whether an assertion really depends on the behavior, break the behavior briefly and confirm the test fails.

Rules:

- If a fixture cannot be built or an expected result would need invented semantics, stop under [Changes](#changes). Never take an expected result from production output, and never relax an obligation to make a test pass.
- Restructuring test code must keep each scenario's distinguishing conditions and expected result.
- Assertions must tell the required result from a plausible wrong one. Snapshots, mock-call checks, and mocked adapters standing in for queries or transactions are weak evidence.
- At the plan's tip, run the project's local checks (lint, build, whatever CI runs), its TC tests, and affected existing tests.

## Git identity

Use the configured Git identity and active `gh` account. Never invent authors, switch accounts, or inject tokens; missing identity or auth blocks the operation.
