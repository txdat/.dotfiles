---
model: sonnet
effort: high
---

# /execute-infra — Write Infrastructure Config + Runbook

Writes config files and generates execution runbook. Does NOT apply.

Find plan from $ARGUMENTS or by status `approved`/`in-progress`. Set `in-progress`. Read `CLAUDE.md`.

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

Discovered work → STOP. Log in `## Discovered Scope`. Ask: include / separate / skip?

## Completion

`git diff --stat` → append runbook → status `implemented` → print "Config + runbook complete. Review ⚠️ destructive steps, then execute manually."
