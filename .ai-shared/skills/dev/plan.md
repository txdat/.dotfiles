# Plan-Backed Delivery

The shared contract for application plans. Phase skills say how to do each phase; this file owns what they share.

## Scope

The workflow applies when the user invokes a phase — design-feature, review-feature, execute-feature, review-code, or create-pr — or [run-stack](run-stack.md), which runs review-feature through create-pr, or [autopilot](autopilot.md), for the changes it routes plan-backed. It covers application code and developer tooling other than this dev flow, with their tests, including refactors.

Docs, declarative config, and this dev flow — its skills and its [scripts](../../bin) with their tests — take the direct-edit path under [CORE.md — Work](../../CORE.md#work). Inside plan work, such a change goes on the plan's Branch with its implementation, after its proof commit. The exception is a `Type: config` plan: a declarative config change that must merge as its own PR within a stack, such as a flag a plan above it reads. A mixed change follows the workflow for its code.

A change is contained when it stays in one module (a package, service, or top-level source directory), changes no contract, data model, dependency, or rollout behavior, and is estimated at no more than 3 files and 200 lines, tests excluded. fix-bug recommends, and autopilot routes, a contained change to a direct edit and any other change the workflow covers to plan-backed delivery.

## Sequence

**design-feature → review-feature → user sets `Status: approved` (or run-stack `--auto-approve` sets `auto-approved`) → execute-feature → review-code → create-pr**

| Status | Set by |
|---|---|
| `planning` | design-feature, a revision before approval, the user's `dev-stack.sh reopen`, or autopilot's `dev-stack.sh auto-reopen` |
| `needs-changes`, `ready` | review-feature's verdict, recorded with `Spec:` |
| `approved` | the user only, from `ready` |
| `auto-approved` | `dev-stack.sh approve`, from `ready`, under run-stack `--auto-approve`, which only autopilot passes; gates treat it as `approved` |
| `implemented` | execute-feature, or the main agent after any change to a `reviewed` plan's Branch, such as a merge forward ([Worktree](#worktree)) |
| `reviewed` | the main agent, after a review-code pass that `dev-stack.sh code-review` logged at the Branch tip, with `Tip:` set to that tip |
| `published` | create-pr's cleanup |

A gate blocks each phase until its entry status holds, and blocks every gated phase on a stopped plan ([run-stack.md — Stops](run-stack.md#stops)) or a frozen one ([Changes](#changes)). The create-pr gate also blocks a `reviewed` plan whose last logged review-code verdict is not a pass at its `Tip:`. No phase resumes or edits a published plan.

## Artifact

One plan delivers one PR. Plans live in the main working tree ([dev-utils.sh](../../bin/dev-utils.sh) `main-root`), never a linked worktree, at `docs/plans/<issue>_<slug>/pr<N>.spec.md`: `<issue>` is the issue number or `0`, and `<slug>` lowercase words joined by hyphens. One directory holds one stack; a parent's number is below its children's. Plans are never committed: the code, its tests, and the PR carry what ships. Git must ignore `docs/plans/` through the global excludes file or `.git/info/exclude`, never a committed `.gitignore`; the gates and `dev-stack.sh check` block when Git does not ignore it. Never run `git clean -x`; it deletes plans. Every phase takes exactly one plan path; never pick a plan by slug or recency.

Write plan, PR, and review prose in the linked issue's primary language, or English without one. Keep headings, field names, statuses, IDs, code, and paths as written below.

## Schema

Write these lines unfenced in the plan:

```text
# <title>
Status: planning
Spec: -
Tip: -
Type: feature|fix|refactor|config
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

After approval only `Status:` and `Tip:` change: the spec is frozen. The user approves by changing `ready` to `approved`, leaving `Spec:` as it is. Only autopilot, through run-stack `--auto-approve`, runs `dev-stack.sh approve`, which sets `auto-approved`. Execution decides only details that are not design choices, such as names and internal structure.

[dev-stack.sh](../../bin/dev-stack.sh) records each verdict, approval, stop, `resume`, `reopen`, and `auto-reopen` in the stack directory's `log`; only dev-stack.sh writes it. It binds each approval, the user's included, to the spec hash approved; `next` and `check` record the user's approval. The gates and `next` block a plan whose spec, or a spec below it, changed since its approval, or whose Status went back below `approved`. A plan is unapproved when its Status is below `approved` and it has no approval since its last reopen. Where installed ([claude.md](../../references/claude.md), [pi.md](../../references/pi.md), [antigravity.md](../../references/antigravity.md)), the [gate-check.sh](../../bin/gate-check.sh) hook refuses an agent's call that sets `approved`, moves an unapproved plan to `approved` or later other than through `dev-stack.sh approve`, returns an approved plan below `approved` other than through `dev-stack.sh auto-reopen`, changes a frozen plan's spec or a published plan, moves or deletes a plan the stack log names, runs `dev-stack.sh resume` or `reopen`, or writes to the stack log. It refuses an edit tool's call before it lands; it snapshots the current repository's plans before a shell call and restores any plan or stack log the call changed that way. It catches mistakes and shortcuts, not an agent set on evading it: a background job that changes plans after its call returns goes unchecked, a change the user makes to the same repository's plans while a shell call runs is restored, so the user makes it again, and a shell command that only contains a stack-log write as text, such as test code in a heredoc, is refused too; edit a file holding such text with an edit tool.

Each case in the table below, including a failed PC, needs a decision and stops the work it affects until the decision is taken. The main agent brings the user options, tradeoffs, and a recommendation; under autopilot, [autopilot.md — Decisions](autopilot.md#decisions) decides instead unless it stops. The next step depends on the plan:

| Plan | Its spec cannot be met or followed as written, or it needs a contract from a plan below | New scope, a changed behavior, a different PR split, or a contract plans above it need |
|---|---|---|
| unapproved | set `planning`, revise, and re-review | the same |
| approved by the user, or `auto-approved` outside autopilot | stop; the user decides whether to run `dev-stack.sh reopen <plan>` | the plan continues, with no stop recorded on it; the change goes to an unapproved plan above it, a new plan stacked on it, or a new plan inserted above it where [Stacks](#stacks) allows |
| whose approval is `auto-approved`, under autopilot | `dev-stack.sh auto-reopen <plan>`, then revise and re-review | as for the user's approval |

`reopen` returns the plan, and every plan above it that is approved or later, to `planning`, clears their `Tip:` and stops, and restarts their round counts; only the user runs it. `auto-reopen` does the same for autopilot without clearing stops, since the Status change ends an ordinary stop. It refuses unless the approval of every plan it returns is `auto-approved`, and refuses when any plan it would return was auto-reopened before or is under a held stop ([run-stack.md — Stops](run-stack.md#stops)); the plan then stops for the user. Until a reopen, an approved plan's Branch takes only code and test fixes that meet its ACs, TCs, and Goal as written, and its worktree stays.

## Stacks

When a goal needs several PRs, each gets its own plan, and the plans form a stack in one directory that shares the issue. Every plan but the root, the lowest-numbered, stacks on one parent; a parent may carry several children. A plan's parent, the parent's parent, and so on are the plans below it. Two plans neither of which is below the other change disjoint files; when they cannot, stack one on the other. A contract between plans belongs to the plan that provides it, in its Design Decisions or a contract file it ships, proven by its ACs and TCs.

A child is designed against the specs below it as if implemented. It cites none of their IDs: it restates each contract fact it relies on as a PC, whose Check greps the providing plan's spec, by its absolute path, for the exact name relied on, such as a field or symbol, so a mismatched name fails before review. It uses the parent's Base. Its review requires the parent `approved` or later; its execution and code review require it `reviewed`. Its integration TCs exercise the real code below it; mocks of the contract do not prove integration.

The stack publishes at once as the last step: when every plan in it is `reviewed`, create-pr runs once, on the root, and publishes every plan. A published plan never becomes a parent; later work waits for the stack to merge and starts a new stack directory on Base.

The user, or autopilot, may split, merge, insert, or drop unapproved plans ([Changes](#changes)) whose Branch does not exist, that have no worktree, and that are not stopped; a plan executed once is revised instead, an approved plan stays as it is, and a stopped plan waits until its stop ends ([run-stack.md — Stops](run-stack.md#stops)). The main agent removes a plan only through `drop`, which relabels its log lines. The main agent runs [dev-stack.sh](../../bin/dev-stack.sh) `renumber` and `drop`; the planner writes or folds the plans. `renumber <root plan> <old>=<new> ...` renames plans with the `Stacks On:` lines and log lines naming them, keeping each parent's number below its children's. `drop <plan>` deletes a plan and stacks its children on its parent; for the root, its lowest-numbered child becomes the root and the others stack on it. To split or insert, renumber the plans above the new one, write it, and stack the plan above it on it; to merge, fold one plan into the other, then drop it. Repoint every contract PC path that names a moved or dropped plan. Each reshaped plan returns to review-feature, since its spec changed.

## Worktree

Each plan has its own worktree at `~/work/wt/<repo>-<issue>_<slug>-pr<N>`, found by that path, never recorded.

- Create it only with [dev-worktree.sh](../../bin/dev-worktree.sh) `create <issue>_<slug>-pr<N> <Branch> <target>`, where target is the PR target: `origin/<Base>` (local Base without one), or the parent plan's Branch for a stacked plan. On an existing Branch it reattaches that Branch as it is, so a worktree that went missing is recreated the same way.
- One phase runs in a worktree at a time, on the plan's own Branch. The worktree stays until create-pr's cleanup removes it.
- `link-deps <worktree>` links installed dependencies from the main root. Before any command that changes a linked dependency directory, run `isolate-dep <worktree> <name>`; installing through the symlink corrupts the main root.
- Run code, tests, and branch Git operations in the worktree. Never stash, reset, or clean to get past unrelated changes in the worktree or the main root.
- Fix a plan on its own Branch. Then the main agent merges it forward into each child whose Branch exists, then each changed child into its children, each in its own worktree once no phase runs there, reruns each merged-into plan's local checks, TC tests, and affected tests, and sets each that was `reviewed` to `implemented`, so review-code runs again. Never rebase, reset, or force-push.

## Review

These rules apply to every review skill. When this session wrote the artifact, run the review in a subagent that has not seen the conversation: the [dev-reviewer](../../agents/dev-reviewer.md) agent where installed, on the model and effort [skills README](../README.md) gives the review skill. Give it only [CODING.md](../../CODING.md), the review skill and the files that skill links directly, the artifact path, the user's request, the worktree and refs it needs, for review-code execute-feature's per-TC report and, outside a review-only request, its round's scratch path ([Review rounds](#review-rounds)), and, for a re-review, the prior findings and the diff of the repair. A stacked plan's reviewer also reads the plans below it. If no subagent is available, review directly and say so.

The main agent keeps one reviewer for a stack's review-feature rounds, plans in dependency order, and one per plan for its review-code rounds, and sends each next plan or round to it through the harness's message or resume tool. It starts a fresh reviewer, given the same inputs, where the harness has no such tool, the reviewer's context is full, or another review is still running in it.

Preferences and style never block. The reviewer may read, run tests, and inspect Git. It edits files only in its review-code round's scratch and under `/tmp`, never inside a linked dependency, and never commits, touches refs, the stash, or status, or installs dependencies. The main agent repairs. A review-only request gets no scratch, returns findings, and changes nothing.

Round 1 covers the whole artifact. A re-review is a delta review: it checks the prior findings, the changed text, what cites or depends on it, and the PC Checks of changed PCs, and, in review-code, the repair diff with the TC and affected tests at the new tip, and nothing else.

A review has 3 rounds: round 1 and two re-reviews. For a plan, dev-stack.sh counts them under [Review rounds](#review-rounds). For an architecture document or runbook, the main agent counts them, and a NEEDS CHANGES verdict on the round at its limit goes to the user, who decides whether to grant three more rounds.

## Review rounds

A verdict holds while the spec and the specs below it are unchanged: the spec hash ignores only the header's Status, Spec, and Tip lines, and [dev-stack.sh](../../bin/dev-stack.sh) compares it with `Spec:`. The execute-feature, review-code, and create-pr gates require a current ready `Spec:`; create-pr requires one for every plan in the stack.

The main agent records each review-feature verdict with `dev-stack.sh review <plan> ready|needs-changes` and each review-code verdict with `code-review <plan> pass|needs-changes`; each prints the round as `<k>/<limit>`. The limit starts at 3. A needs-changes verdict at or past the limit stops the plan until the user runs `dev-stack.sh resume`, which grants three more rounds (the limit becomes the current round plus 3), or `reopen`. A review-code pass ends its review phase, and the next one counts from 1; a `reopen` or `auto-reopen` restarts both counts. A ready verdict does not reset the count, so a plan ready at its limit, such as `3/3`, whose spec then changes is re-reviewed at `4/3`, where a needs-changes verdict stops it.

A needs-changes verdict counts as a round, never as a failed fix; `Failed fixes` ([CORE.md — Work](../../CORE.md#work)) counts only a repair whose own verification fails before re-review.

Outside a review-only request, each review-code round runs in a scratch the main agent creates from the plan's worktree with [dev-worktree.sh](../../bin/dev-worktree.sh) `scratch <issue>_<slug>-pr<N>-r<round> <tip SHA> [<repro> ...]`, passing each open finding's saved repro, and gives its path to the reviewer, who runs every command there. When `scratch` reports a repro as not applying, the main agent retries without it and gives that finding to the reviewer to rebuild. On a tip that changes a dependency manifest, it runs `isolate-dep` and installs in each scratch it opens. Each `ran` finding carries its repro from `scratch-diff <scratch> -- <its files>`, which the main agent saves under `/tmp` before ending the round with `scratch-remove`.

Before repairing, the main agent reruns the command of every blocking `ran` finding in one fresh `scratch <issue>_<slug>-pr<N>-r<round>-v <tip SHA> <repro> ...`, then removes it. When `scratch` reports a repro as not applying, it retries `-r<round>-v` without that repro and reruns that finding alone in `scratch <issue>_<slug>-pr<N>-r<round>-v<k> <tip SHA> <repro>`, numbering `<k>` from 1, removing each scratch after its run. A repro that does not apply even alone counts as not reproducing. A finding that does not reproduce goes back to the reviewer once, in `scratch <issue>_<slug>-pr<N>-r<round>-f<k> <tip SHA>`, numbering `<k>` from 1, which the main agent removes after saving any rebuilt repro under `/tmp`; the reviewer's answer is not a verdict and records no round. The main agent then reruns the rebuilt repro in `scratch <issue>_<slug>-pr<N>-r<round>-v<k> <tip SHA> <repro>`, continuing the `<k>` numbering; if it still does not reproduce, the main agent relabels it `traced`, `located`, or `asserted` by the evidence left.

## Verification

The review base is where the Branch leaves its PR target: for Base, the merge-base with `origin/<Base>` (or local Base without one); for the parent plan's Branch, its tip (local, or `origin/<branch>`), which the Branch must contain.

Test-first:

1. **RED.** Turn each TC's fixture, action, and expected result into a test. Run it at the review base: it must fail for the intended missing behavior — fixture, import, and syntax failures do not count. A refactor instead gives each TC a test, new or edited from an existing one, that passes at the review base.
2. Commit only the tests, plus throwing stubs where a new API needs them, as `test(red): <scope>`, or `test: baseline <scope>` for a refactor. The gate counts these subjects. Run `~/.dotfiles/.ai-shared/bin/dev-check.sh proof <commit> [--test <path>] [--stub <path>]` and read the diff.
3. **GREEN.** Implement, run the tests, and commit the implementation separately. When it is unclear whether an assertion really depends on the behavior, break the behavior briefly and confirm the test fails.

Rules:

- If a fixture cannot be built or an expected result would need invented semantics, stop under [Changes](#changes). Never take an expected result from production output, and never relax an obligation to make a test pass.
- Restructuring test code must keep each scenario's distinguishing conditions and expected result.
- Assertions must tell the required result from a plausible wrong one. Snapshots, mock-call checks, and mocked adapters standing in for queries or transactions are weak evidence.
- At the plan's tip, run the project's local checks (such as lint, build, and the checks CI runs), its TC tests, and affected tests, selected under [CODING.md — Tests](../../CODING.md#tests).
- A revised plan re-executed on a Branch that already holds commits of an earlier revision proves only its new and changed TCs. Here an implementation commit is any commit other than a proof commit, a merge, or a `test(update): <scope>` commit; for a feature, fix, or refactor plan, the gate counts `test(update)` as neither proof nor implementation.
  - When the Branch's latest proof commit has no implementation commit after it, the new and changed TCs' tests go in a `test(update)` commit, with any throwing stubs step 2 allows, and must fail (a refactor's pass) at that proof commit's parent.
  - Otherwise, the tests of TCs the Branch tip does not meet go in a new proof commit, failing there for the intended missing behavior, and the implementation follows. A refactor whose revision changes its implementation instead puts its new and changed TCs' tests in a new baseline commit, passing at the Branch tip, before that change.
  - Every other test change, including deleting the tests of removed TCs, goes in a `test(update)` commit.
  - A `Type: config` plan changes its config and reruns its TC checks.
- A `Type: config` plan skips RED and its commit: its TCs are checks of the config, such as schema validation or a lookup of each key, run at the tip. The gate requires only a commit of its own.

## Git identity

Use the configured Git identity and active `gh` account. Never invent authors, switch accounts, or inject tokens; missing identity or auth blocks the operation.
