# /execute-infra — Write Infrastructure Config + Runbook

Writes infrastructure config files and generates their execution runbook. Does NOT apply or change application code; discovered application-code work is scope creep and requires a separate design-feature plan.

Resolve the session's active plan: an explicit `docs/plans/<file>.md` (or its slug) in $ARGUMENTS pins it; otherwise the session's pinned plan, else the lone active plan. 0 or 2+ active and none named → STOP, ask which.

**Approval + Issue Gates (BLOCKING):** the plan's `Status:` MUST be `approved` (or `in-progress` on resume), and `Issue:` MUST contain a valid `#<number>`. `planning`/`blocked-by-architecture` → STOP; ask the user to approve it manually (set `Status: approved`) or through ship-feature's explicit `Approve plan?` pause. Empty/invalid `Issue:` → STOP and create/link the issue first. Never self-approve. Then set `in-progress`. Read project AI config files.

Partial: `<name> from <N>` starts at N; `<name> <N>` runs only N.

## Worktree & Branch Model

Use the shared lifecycle in `~/.dotfiles/.ai-shared/skills/dev/worktree.md`; never write config or plan changes in `$MAIN_ROOT`. Bind `<slug>` to the plan filename, `<branch>` to `infra/<slug>`, and `<parent>` to `<base>`. Create/copy/dependency-link/resume exactly as that lifecycle specifies, then perform all validation, plan edits, commits, and later PR commands in `<worktree>`.

## Destructive Command Detection

Flag steps containing:
- Terraform: `destroy`, `taint`, `-replace`, `state rm`
- K8s: `delete`, `replace --force`, `drain`, `cordon`
- SQL: `DROP`, `TRUNCATE`, `DELETE`, `ALTER TABLE`
- Cloud: `rm`, `delete`, `terminate`, `remove`, `purge`
- Shell: `rm -rf`, `mv` (overwrite), `chmod`, `chown`

## Execution

Per step: **Write** config → **Validate** (`terraform validate`, `kubectl --dry-run=client`, `yamllint`) → **Diff** (`git -C <worktree> diff`) → **Flag** destructive → `✅ Step N: <files>`. The main agent alone runs Git commands, edits the plan, stages, and commits.

Validation fails → stop, ask how to proceed.

## Runbook Output

Append to plan file:

```
## Execution Runbook

### Step N: <action>
- **Run:** `<full command, no aliases>`
- **Expect:** <output/state>
- **Rollback:** `<undo>`

### Step N: ⚠️ DESTRUCTIVE — <action>
- **Impact:** <what will be lost>
- **Dry-run:** `<preview command>`
- **Run:** `<actual command>`
- **Expect:** <output/state>
- **Rollback:** `<undo>` | `NOT REVERSIBLE`

## ⚠️ Destructive Steps
- Step N: <impact summary>
```

Rules: commands explicit/complete (no aliases, no flag shortcuts), expect = specific string/code/state, async = wait condition, destructive = MUST have Impact + Dry-run.

## Scope Creep

Discovered work → STOP. Log in `## Discovered Scope` with estimated effort. Ask: include / separate / skip?

## Self-Check (BLOCKING — do NOT emit completion until every item is ✅)

Run this audit before marking the plan `implemented`. If ANY item is unchecked → STOP, fix, re-check.

- [ ] **All steps written** (`## Execution`): every Implementation Step has config written. Missing: __.
- [ ] **Validation passed** (`## Execution`): `terraform validate` / `kubectl --dry-run=client` / `yamllint` passed. Failures: __.
- [ ] **Destructive flags** (`## Destructive Command Detection`): every destructive step flagged. Missed: __.
- [ ] **Runbook appended** (`## Runbook Output`): `## Execution Runbook` present; each step Run + Expect + Rollback; destructive add Impact + Dry-run.
- [ ] **Commands explicit** (Runbook Rules): no aliases, no flag shortcuts. Issues: __.
- [ ] **Scope Creep logged** (`## Scope Creep`): discovered work in `## Discovered Scope`. Unlogged: __.
- [ ] **Issue linked** (top): `Issue:` contains a valid `#<number>`. Value: __.
- [ ] **Worktree + PR Pattern** (`## Worktree & Branch Model`): worktree exists and matches `Worktree:`; provisional PR Pattern names `infra/<slug>`. Missing: __.

If ALL checked → status `implemented`, commit the config/runbook/plan changes in `<worktree>`, and print "Config + runbook complete. Run the review-code skill; execute ⚠️ destructive steps manually only after review."

## Completion

`git -C <worktree> diff --stat` → append runbook → run the Self-Check. Only then set status `implemented` in the worktree plan copy and commit: `git -C <worktree> add <config-files> docs/plans/<file>.md && git -C <worktree> commit -m "infra(<scope>): implement config and runbook"`.
