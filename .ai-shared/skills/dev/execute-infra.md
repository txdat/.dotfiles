# /execute-infra — Write Infrastructure Config + Runbook

Writes config files and generates execution runbook. Does NOT apply.

Resolve the session's active plan: an explicit `docs/plans/<file>.md` (or its slug) in $ARGUMENTS pins it; otherwise the session's pinned plan, else the lone active plan. 0 or 2+ active and none named → STOP, ask which.

**Approval Gate (BLOCKING):** the plan's `Status:` MUST be `approved` (or `in-progress` on resume). `planning`/`blocked-by-architecture` → STOP; ask the user to approve it manually (set `Status: approved`). Never self-approve — only ship-feature flips the status, and only after the user confirms at its plan-phase PAUSE. Then set `in-progress`. Read project config file (CLAUDE.md/CODEX.md/GEMINI.md/AGENTS.md).

Partial: `<name> from <N>` starts at N; `<name> <N>` runs only N.

## Destructive Command Detection

Flag steps containing:
- Terraform: `destroy`, `taint`, `-replace`, `state rm`
- K8s: `delete`, `replace --force`, `drain`, `cordon`
- SQL: `DROP`, `TRUNCATE`, `DELETE`, `ALTER TABLE`
- Cloud: `rm`, `delete`, `terminate`, `remove`, `purge`
- Shell: `rm -rf`, `mv` (overwrite), `chmod`, `chown`

## Execution

Per step: **Write** config → **Validate** (`terraform validate`, `kubectl --dry-run=client`, `yamllint`) → **Diff** (`git diff`) → **Flag** destructive → `✅ Step N: <files>`.

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

If ALL checked → status `implemented` → print "Config + runbook complete. Review ⚠️ destructive steps, then execute manually."

## Completion

`git diff --stat` → append runbook → run the Self-Check. Only then set status `implemented`.
