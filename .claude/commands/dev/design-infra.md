---
model: sonnet
effort: high
---

# /design-infra — Infrastructure Change Planning

Warn if active infra plan exists. Filename: `docs/plans/<basename>_<date>_infra_<slug>.md`.

Read `CLAUDE.md`. No apply. Read-only OK (`terraform show`, `kubectl get`).

**Drift detection**: compare live vs config. If drift → add sync step first.

## Draft

Clarify: scope, environments, dependencies, re-run safety, rollback, downtime. Up to 3 rounds.

```
# Task: <name>
Status: planning | Type: infra | Env: <dev|staging|prod|all> | Issue:

## Requirement
<change and why>

## Scope
In: <items>
Out: <items>

## Design Decisions
| Decision | Options | Chosen | Reason |

## Risk Flags
- [ ] <risk>: <mitigation>

## Pre-flight
- [ ] `<cmd>` — confirms <state>

## Implementation Steps
- [ ] Step 1: <action> — `<cmd>`

## Verification Steps
- [ ] Verify 1: `<cmd>` — expected: <result>

## Rollback
Trigger: <condition>
- [ ] `<undo cmd>`

## Out of Scope
- <item>: <why>
```

Rules: 5–15 steps, dependency-ordered. >15 → split. Destructive → dry-run inline.

**Gate**: pre-flight non-empty, each impl has verify, rollback has step.

Save. Show: name, env, requirement, counts, path. Ask: "Changes?" then "Create issue?"

## Review

Checks: requirement measurable, scope explicit, alternatives considered, risks actionable, dry-runs for destructive.

**Gate**: destructive → dry-run, rollback → trigger. Flag: undefined env, missing rollback, no drift sync.

Show: Verdict, Blocking N, Suggestions N. Ask: "Apply?" → set `approved`, print path.
