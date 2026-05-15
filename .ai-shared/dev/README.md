# Dev Skills

## Hierarchy

```
/design-system    → architecture, cross-cutting patterns
    ↓ decomposes to
/design-feature   → feature/fix/refactor implementation
    ↓ may require
/design-infra     → infrastructure config (terraform, k8s)
```

## Full Feature Cycle

`/dev:ship-feature <requirement>` — explore → plan → execute → review-code → recap → pr

Resume: `/dev:ship-feature add-jwt from execute`

No phase confirmations: `/dev:ship-feature add-jwt skip approval` (destructive actions still require explicit confirmation)

---

## Design Skills

| Skill | Scope | Output |
|-------|-------|--------|
| `/dev:design-system` | Architecture, system patterns | `docs/architecture/<date>_<slug>.md` |
| `/dev:design-feature` | Feature/fix/refactor | `docs/plans/<basename>_<date>_<type>_<slug>.md` |
| `/dev:design-infra` | Infrastructure config | `docs/plans/<basename>_<date>_infra_<slug>.md` |

## Review Skills

| Skill | Reviews |
|-------|---------|
| `/dev:review-system` | Architecture design |
| `/dev:review-feature` | Feature plan |
| `/dev:review-code` | Code changes |

## Execution Skills

| Skill | Purpose |
|-------|---------|
| `/dev:execute-feature` | TDD RED→GREEN→BLUE |
| `/dev:execute-infra` | Write config + runbook (no apply) |
| `/dev:fix-bug <symptom>` | Diagnose + minimal fix |

## Utility Skills

| Skill | Purpose |
|-------|---------|
| `/dev:explore <target>` | Map entry points, flow, patterns |
| `/dev:simplify-code <target>` | Simplify without behavior change |
| `/dev:recap` | Extract patterns → project config |
| `/dev:create-issue <title>` | Standalone GitHub issue |
| `/dev:create-pr [ready]` | Draft PR (or ready) |
