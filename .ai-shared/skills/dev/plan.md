# Plan-Backed Delivery

The shared contract for application plans. Phase skills say how to do each phase; this file owns what they share.

## Scope

The workflow applies when the user invokes a phase: design-feature, review-feature, execute-feature, review-code, or create-pr, or [run-stack](run-stack.md), which runs review-feature through create-pr, or [autopilot](autopilot.md), for the changes it routes plan-backed. It governs application code and developer tooling other than this dev flow, with their tests, including refactors. Docs, declarative config, and this dev flow — its skills and its [scripts](../../bin) with their tests — take the direct-edit path under [CORE.md — Work](../../CORE.md#work), even inside plan work, except a `Type: config` plan: declarative config that the repository requires in its own PR within a stack. Mixed changes follow the workflow for their governed part.

## Sequence

**design-feature → review-feature → user sets `Status: approved` (or run-stack `--auto-approve` sets `auto-approved`) → execute-feature → review-code → create-pr**

| Status | Set by |
|---|---|
| `planning` | design-feature, a revision before approval, the user's `dev-stack.sh reopen`, or autopilot's `dev-stack.sh auto-reopen` |
| `needs-changes`, `ready` | review-feature's verdict, recorded with `Spec:` |
| `approved` | the user only, from `ready` |
| `auto-approved` | `dev-stack.sh approve`, from `ready`, under run-stack `--auto-approve`, which only autopilot passes; gates treat it as `approved` |
| `implemented` | execute-feature, or any change to a reviewed Branch |
| `reviewed` | review-code, with `Tip:` set to the tip it passed |
| `published` | create-pr's cleanup |

A gate blocks each phase until its entry status holds, and blocks every gated phase on a stopped plan ([run-stack.md](run-stack.md)) or a frozen one ([Changes](#changes)). No phase resumes or edits a published plan.

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

After approval only `Status:` and `Tip:` change, and `Status:` never returns below `approved` until the user's `dev-stack.sh reopen`, or for an `auto-approved` plan autopilot's `auto-reopen`: the spec is frozen. To approve, the user changes `ready` to `approved` and leaves `Spec:` as it is; only autopilot, through run-stack `--auto-approve`, runs `dev-stack.sh approve`, which sets `auto-approved`. Execution decides only details that are not design choices, such as names and internal structure.

[dev-stack.sh](../../bin/dev-stack.sh) records each verdict, approval, and stop, the user's `resume` and `reopen`, and autopilot's `auto-reopen`, in the stack directory's `log`; only dev-stack.sh writes it. It binds each approval to the spec hash approved, including the user's, which `next` and `check` record. The gates and `next` block a plan whose spec, or a spec below it, changed since its approval, or whose Status went back below `approved`. The user lifts that by reverting the change, or with `dev-stack.sh reopen <plan>`, which returns the plan and every plan above it that is approved or later to `planning` and clears their stops. A plan is unapproved when its Status is below `approved` and it has no approval since its last reopen. Where installed ([claude.md](../../references/claude.md)), a hook refuses an agent's edit that sets `approved`, moves an unapproved plan to `approved` or later other than through `dev-stack.sh approve`, returns an approved plan below `approved` other than through `dev-stack.sh auto-reopen`, changes a frozen plan's spec, moves or deletes it, changes a published plan, or moves or deletes a plan the log still names, and an agent's `resume`, `reopen`, or write to the log. It refuses an edit tool's edit before it lands, and after a shell command restores the plans and log of the current repository that the command changed that way. It catches mistakes and shortcuts, not an agent set on evading it: a background job that changes plans after its call returns goes unchecked, and a change the user makes to the same repository's plans while a shell command runs is restored, so the user makes it again.

Anything else stops the affected work: a failed PC, an AC or TC that cannot be met, a step that cannot be followed, a different PR split, or new scope. Bring the user options, tradeoffs, and a recommendation; under autopilot, [autopilot.md — Decisions](autopilot.md#decisions) decides instead. An unapproved plan is revised: set `planning`, revise, and re-review. An agent never reopens an approved plan; only the user does, except that autopilot runs `dev-stack.sh auto-reopen` once per plan on a plan whose approval, and that of every approved plan above it, is `auto-approved`, never past a round limit or a `Failed fixes: 3/3` stop ([autopilot.md — Decisions](autopilot.md#decisions)). `auto-reopen` returns plans to `planning` as `reopen` does but clears no stop: the Status change ends an ordinary stop, and it refuses a held one. For an approved plan, the main agent, once the user decides, or autopilot under its Decisions, puts new scope, a changed behavior, or a contract the plans above need into an unapproved plan above it, a new plan stacked on it, or one inserted above it when every plan above it is unapproved, has no existing Branch, and has no worktree ([Stacks](#stacks)), and the plan's own Branch gets code and test fixes until it meets its ACs, TCs, and Goal as written. On an approved plan, a failed PC, a contract it needs from below, or an AC, TC, or step that cannot be met or followed as written stops the plan for the user, who decides whether to reopen it; under autopilot, [autopilot.md — Decisions](autopilot.md#decisions) decides first. The worktree stays.

## Stacks

When a goal needs several PRs, each gets its own plan, and the plans form a stack in one directory that shares the issue. Every plan but the root, the lowest-numbered, stacks on one parent; a parent may carry several children. A plan's parent, the parent's parent, and so on are the plans below it. Two plans neither of which is below the other change disjoint files; when they cannot, stack one on the other. A contract between plans belongs to the plan that provides it, in its Design Decisions or a contract file it ships, proven by its ACs and TCs.

A child is designed against the specs below it as if implemented. It cites none of their IDs: it restates each contract fact it relies on as a PC, whose Check greps the providing plan's spec, by its absolute path, for the exact name relied on, such as a field or symbol, so a mismatched name fails before review. It uses the parent's Base. Its review requires the parent `approved` or later; its execution and code review require it `reviewed`. Its integration TCs exercise the real code below it; mocks of the contract do not prove integration.

The stack publishes at once as the last step: when every plan in it is `reviewed`, create-pr runs once, on the root, and publishes every plan. A published plan never becomes a parent; later work waits for the stack to merge and starts a new stack directory on Base.

The user, or autopilot, may split, merge, insert, or drop unapproved plans ([Changes](#changes)) whose Branch does not exist, that have no worktree, and that are not stopped; a plan executed once is revised instead, an approved plan stays as it is, and a stopped plan waits until its stop ends ([run-stack.md](run-stack.md)). The main agent removes a plan only through `drop`, which relabels its log lines. The main agent runs [dev-stack.sh](../../bin/dev-stack.sh) `renumber` and `drop`; the planner writes or folds the plans. `renumber <root plan> <old>=<new> ...` renames plans with the `Stacks On:` lines and log lines naming them, keeping each parent's number below its children's. `drop <plan>` deletes a plan and stacks its children on its parent; for the root, its lowest-numbered child becomes the root and the others stack on it. To split or insert, renumber the plans above the new one, write it, and stack the plan above it on it; to merge, fold one plan into the other, then drop it. Repoint every contract PC path that names a moved or dropped plan. Each reshaped plan returns to review-feature, since its spec changed.

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

When this session wrote the artifact, run the review in a subagent that has not seen the conversation: the [dev-reviewer](../../agents/dev-reviewer.md) agent where installed, on the model and effort [README](../../README.md#skills) gives the review skill. Give it only [CODING.md](../../CODING.md), the review skill and the files it links, the artifact path, the user's request, the worktree and refs it needs, and, for a re-review, the prior findings and the diff of the repair. A review-code reviewer outside a review-only request also gets its round's scratch path. A stacked plan's reviewer also reads the plans below it. If no subagent is available, review directly and say so.

The main agent keeps one reviewer for a stack's review-feature rounds, plans in dependency order, and one per plan for its review-code rounds, and sends each next plan or round to it through the harness's message or resume tool. It starts a fresh reviewer, given the same inputs, where the harness has no such tool, the reviewer's context is full, or another plan's review is still running in it.

Preferences and style never block. The reviewer may read, run tests, and inspect Git. It edits files only in its review-code round's scratch and under `/tmp`, never inside a linked dependency, and never commits, touches refs, the stash, or status, or installs dependencies. The main agent repairs. A review-only request gets no scratch, returns findings, and changes nothing.

Outside a review-only request, each review-code round runs in a scratch from [dev-worktree.sh](../../bin/dev-worktree.sh) `scratch <issue>_<slug>-pr<N>-r<round> <tip SHA> [<repro> ...]`, run from the plan's worktree. The main agent passes each open finding's saved repro; when `scratch` reports one as not applying, it retries without it and gives it to the reviewer to rebuild. On a tip that changes a dependency manifest, it runs `isolate-dep` and installs in every scratch it opens. Each `ran` finding carries its repro from `scratch-diff <scratch> -- <its files>`. Before repairing, the main agent saves each blocking `ran` finding's repro under `/tmp`, reruns its command in a fresh `scratch <issue>_<slug>-pr<N>-r<round>-f<k> <tip SHA> <repro>`, and removes that scratch. A finding that does not reproduce goes back to the reviewer once, resumed where possible; if it still does not, the main agent relabels it `traced`, `located`, or `asserted` by the evidence left. Then the round ends with `scratch-remove` on its scratch.

A verdict holds while the spec and the specs below it are unchanged: the spec hash ignores only the header's Status, Spec, and Tip lines, and [dev-stack.sh](../../bin/dev-stack.sh) compares it with `Spec:`. The execute-feature, review-code, and create-pr gates require a current ready `Spec:`; create-pr requires one for every plan in the stack.

Round 1 covers the whole artifact. A re-review is a delta review: it checks the prior findings, the changed text, what cites or depends on it, and the PC Checks of changed PCs, and, in review-code, the repair diff with the TC and affected tests at the new tip, and nothing else.

[dev-stack.sh](../../bin/dev-stack.sh) counts the rounds in the stack's log: the main agent records each review-feature verdict with `review <plan> ready|needs-changes` and each review-code verdict with `code-review <plan> pass|needs-changes`, which print the round as `<k>/<limit>`. The limit is 3, round 1 and two re-reviews. A needs-changes verdict on round `<limit>` stops the plan until the user runs `dev-stack.sh resume`, which at the limit grants three more rounds, so the count goes on as `4/6`. A review-code pass ends its review phase, and the next one counts from 1; a `reopen` or `auto-reopen` restarts both counts. A ready verdict does not reset the count: when the spec changes after it, the next review continues the count, so a plan ready at `3/3` is re-reviewed at `4/3`, where a needs-changes verdict stops it.

## Verification

Test-first:

1. **RED.** Turn each TC's fixture, action, and expected result into a test. Run it against the unchanged PR target: it must fail for the intended missing behavior — fixture, import, and syntax failures do not count. Refactors instead start with passing tests of the behavior they preserve.
2. Commit only the tests, plus throwing stubs where a new API needs them, as `test(red): <scope>`, or `test: baseline <scope>` for a refactor. The gate counts these subjects. Run `~/.dotfiles/.ai-shared/bin/dev-check.sh proof <commit> [--test <path>] [--stub <path>]` and read the diff.
3. **GREEN.** Implement, run the tests, and commit the implementation separately. When it is unclear whether an assertion really depends on the behavior, break the behavior briefly and confirm the test fails.

Rules:

- If a fixture cannot be built or an expected result would need invented semantics, stop under [Changes](#changes). Never take an expected result from production output, and never relax an obligation to make a test pass.
- Restructuring test code must keep each scenario's distinguishing conditions and expected result.
- Assertions must tell the required result from a plausible wrong one. Snapshots, mock-call checks, and mocked adapters standing in for queries or transactions are weak evidence.
- At the plan's tip, run the project's local checks (such as lint, build, and the checks CI runs), its TC tests, and affected tests, selected under [CODING.md — Tests](../../CODING.md#tests).
- A `Type: config` plan skips RED and its commit: its TCs are checks of the config, such as schema validation or a lookup of each key, run at the tip. The gate requires only a commit of its own.

## Git identity

Use the configured Git identity and active `gh` account. Never invent authors, switch accounts, or inject tokens; missing identity or auth blocks the operation.
