# /autopilot — Requirement to Reviewed Draft PRs

Take one issue or requirement through triage, delivery, draft PRs, and one `/code-review` round. Pass the issue or requirement, or, after a stop, a root plan or the issue with the user's answers ([Resume](#resume)), then optionally `--until create-pr` to skip step 3; any other option or value is reported before triage, and nothing starts. Invoking it authorizes the issue it creates, pushes without force, draft PRs, and `auto-approved` plans; never set `Status: approved`, which is the user's.

This session is the main agent: it routes, decides under [Decisions](#decisions), and runs run-stack, create-issue, create-pr, and every worktree, push, PR, and merge-forward itself; subagents commit only where a step delegates it, and create only the scratch worktrees their own skills make. `Status:` changes stay with the phase that owns them under [plan.md — Sequence](plan.md#sequence). Every other step runs in a fresh subagent built from its row in [Handoffs](#handoffs); where an agent is not installed, the general-purpose agent gets that agent's md file as its instructions and the same row. Without subagents, run each step here, one at a time, and say so.

## Handoffs

Each prompt names the agent's job, gives [CODING.md](../../CODING.md), the row's inputs, delegated and off-limits actions, and expected return, says others share the codebase, and carries any `Failed fixes: <n>/3`; the subagent runs on the [README](../../README.md#skills) model and effort of the row's skill. A missing input is supplied before the subagent starts, never guessed; one no source has stops for the user. run-stack's phases take the inputs its step 2 and [plan.md — Review](plan.md#review) list.

| Step | Agent, job; model of | Inputs | Delegated | Off-limits | Returns |
|---|---|---|---|---|---|
| fix-bug | [dev-inspector](../../agents/dev-inspector.md); fix-bug | report or issue, expected and actual behavior, where it was seen; that autopilot takes the first option, so none needs confirming | fix-bug's scratch, `/tmp` | applying a fix, commits, refs, plan worktrees, shared-environment writes | whether it reproduced, mechanism support, the Proposal, regression patch path, with its other `/tmp` files removed |
| design-feature | [dev-planner](../../agents/dev-planner.md), Design; design-feature | requirement, `#N`, Type, for a bug the Proposal and patch path, answers labeled by source | plan files at their [plan.md — Artifact](plan.md#artifact) path | code, tests, Git, worktrees, `dev-stack.sh` writes, `approved` or `auto-approved` | plan paths with Status, check results, questions with options and a recommendation |
| direct edit | [dev-executor](../../agents/dev-executor.md), Chunk; execute-feature | the change and chosen option, exclusive files, worktree and branch, for a bug the regression patch, the verification in step 2 | commits on that branch | push, PRs, other branches, worktree changes | files changed, commit SHAs, each check with its result, anything unresolved |
| review fixes, code repairs | dev-executor, Chunk; execute-feature | each blocking finding with its evidence or repro, exclusive files, worktree and branch; verification: each finding's rerun and the local checks, plus, plan-backed, the plan's TC and affected tests | commits on that branch | the plan and its tests, push, merges, worktree changes | as for direct edit, with each finding's rerun result |
| `/code-review` | [dev-reviewer](../../agents/dev-reviewer.md), `/code-review`; review-code | PR number, level, the fallback and blocking rule in step 3 | nothing | any edit, `--fix`, `--comment`, posting | each finding with location, evidence, and whether it blocks |

## 1. Triage

1. **Input.** Read an issue (`#N` or URL) with `gh issue view`; anything else is the requirement as written.
2. **Bug or feature.** A bug is existing behavior that departs from expected, documented, or earlier behavior; anything else, or a request that reads either way, is a feature.
3. **Bug.** Run fix-bug. Stop if the bug does not reproduce, its mechanism stays unsupported, or its first fix option is containment or live-state remediation; otherwise take that option.
4. **Route.** Plan-backed unless one of these sends it to a direct edit: [plan.md — Scope](plan.md#scope); for a bug, fix-bug's route; for a feature, a change that stays in one module, the project's package, service, or top-level source directory, and changes no contract, data model, dependency, or rollout behavior. A change estimated at more than 3 files or 200 lines, tests excluded, is plan-backed unless plan.md — Scope requires a direct edit.
5. **Issue.** Without an input issue, run create-issue with the requirement, or for a bug with the problem, expected outcome, and diagnosis evidence, and in either case a `Triage` section giving the type and route with a one-line reason for each; use its `#N` from here on. With an input issue, give that section in the report.

## 2. Deliver

**Plan-backed.** Run design-feature with the requirement, the issue, and for a bug `Type: fix` with the proposal and its regression patch. Answer the questions it returns under [Decisions](#decisions), labeled as dev-autopilot's, and resume it until it returns the stack. Run [run-stack](run-stack.md) `<root> --until review-code --auto-approve`. Once every plan is `reviewed`, run create-pr on the root, with `--defer-cleanup` unless the run is `--until create-pr`.

**Direct edit.** On Base, the default branch unless the issue names one, create a worktree with [dev-worktree.sh](../../bin/dev-worktree.sh) `create <issue>_<slug> <branch> origin/<Base>`, the branch named by the project's convention, and run `link-deps <worktree>`. Delegate the change with its exclusive files and commits on that branch: a failing test first (for a bug, from the regression patch), shown failing and committed, then the change, shown passing, with any original reproduction rerun and the project's local checks passing. Rerun the checks here and confirm the test commit fails without the change; a failure returns to the chunk as a fix attempt. Then push with `git push -u origin <branch>` and open `gh pr create --draft --base <Base>` with a body under [create-pr.md](create-pr.md)'s rules.

## 3. Review the PRs

Review every PR before fixing any. For each PR, parents first, run `/code-review <level> <PR number>` review-only, without `--fix` or `--comment`, where `<level>` is review-code's effort in the README; never `ultra`. Where `/code-review` is unavailable, review `gh pr diff <PR number>` for correctness and security under CODING.md, with each finding's location and evidence. Correctness and security findings block; cleanups are reported, not applied.

Then, parents first, delegate a fix for each PR with blocking findings, in its worktree on its branch: fix each finding, rerun its evidence and the local checks, and commit. On a plan-backed PR, a fix that needs a changed test or spec stops for the user under [plan.md — Changes](plan.md#changes); otherwise set the plan's `Status: implemented` and merge it forward into each plan above it under [plan.md — Worktree](plan.md#worktree), setting each to `implemented`. Once every fix is in, run run-stack `<root> --until review-code --auto-approve` once; a repair to a plan's tests there also stops for the user. There is no second `/code-review` round.

## 4. Finish

- **Direct edit:** push any fixes, then `dev-worktree.sh remove <worktree>`.
- **Plan-backed:** unless step 2 already cleaned up, once every plan is `reviewed`, run create-pr on the root without `--defer-cleanup`; it pushes, verifies, and cleans up.

Any other outcome ends the run with its worktrees kept: a stop under [Decisions](#decisions), a fix reaching the [CORE.md — Work](../../CORE.md#work) attempt limit, or run-stack ending with a plan not `reviewed`.

Report the type and route with their reasons, the issue, each draft PR's URL, each decision taken for the user, and the `/code-review` findings with their fixes; include run-stack's report when it ran. Then list what needs the user: each stop's reason, options, and recommendation, with any `Failed fixes: <n>/3`. CI follows CORE.md — Work: cite known results or report it unverified.

## Decisions

On a question from triage, a subagent, or a review, or a stop under [plan.md — Changes](plan.md#changes), take the recommended option and record it as dev-autopilot's: in a DD as `Choice: <option>, by dev-autopilot` while the plan is `planning`, otherwise in the report. A decision that changes a plan past `ready` revises it under [Resume](#resume), as dev-autopilot's answer. Stop for the user instead when the choice would drop or narrow what was asked, change a contract other code or users consume, migrate or delete data, write to a shared environment, change a security boundary or permission, add a dependency or cost, or change a test or spec once the stack's PRs are open.

## Resume

Resume is run-stack's revise step, the diagram's edge from "ask human" back to design-feature, fed with answers labeled by their source: the user's, given after a stop as `/dev-autopilot <root plan>|#N <answers>`, or dev-autopilot's, from [Decisions](#decisions). A resume takes the original options again. With `#N` and no plan, direct-edit worktree or branch, or PR yet, rerun from step 1 on that issue with the answers, skipping create-issue; once a direct edit's worktree or branch exists, continue at the step that stopped, reusing them and any PR. A plan-backed resume takes the root plan path; `#N` with a plan reports that and starts nothing.

With a plan, return each plan past `ready` to `planning` under [plan.md — Changes](plan.md#changes), with each plan above it when the contract changes, and run that revise step on it with the stop's findings and the answers. The revision changes the spec, which ends the stop, except one citing `Failed fixes: 3/3`, which holds until the user runs `dev-stack.sh resume <plan>`. Then run step 2's run-stack, which re-reviews and auto-approves it; if the stack's PRs are already open, a repair to a plan's tests there stops for the user, and step 4 follows instead of step 2's create-pr and step 3, with no `/code-review`, updating each PR's body with `gh pr edit <PR> --body-file` before create-pr. A user's answer that changes no plan, such as more review rounds or fix attempts, comes with that `resume` and goes straight to run-stack.
