# Claude Code Commands

## Hierarchy

```
/design-system    → architecture, cross-cutting patterns
    ↓ decomposes to
/design-feature      → feature/fix/refactor implementation
    ↓ may require
/design-infra     → infrastructure config (terraform, k8s)
```

## Full Feature Cycle

`/dev:ship-feature <requirement>` — explore → design → execute → review → recap → pr

Resume: `/dev:ship-feature add-jwt from execute`

No confirmations: `/dev:ship-feature add-jwt skip approval`

---

## Design Commands

| Command | Scope | Output |
|---------|-------|--------|
| `/dev:design-system` | Architecture, system patterns | `docs/architecture/<date>_<slug>.md` |
| `/dev:design-feature` | Feature/fix/refactor | `docs/plans/<basename>_<date>_<type>_<slug>.md` |
| `/dev:design-infra` | Infrastructure config | `docs/plans/<basename>_<date>_infra_<slug>.md` |

## Review Commands

| Command | Reviews |
|---------|---------|
| `/dev:review-system` | Architecture design |
| `/dev:review-feature` | Feature plan |
| `/dev:review-code` | Code changes |

## Execution Commands

| Command | Purpose |
|---------|---------|
| `/dev:execute-feature` | TDD RED→GREEN→BLUE |
| `/dev:execute-infra` | Write config + runbook (no apply) |
| `/dev:fix-bug <symptom>` | Diagnose + minimal fix |

## Utility Commands

| Command | Purpose |
|---------|---------|
| `/dev:explore <target>` | Map entry points, flow, patterns |
| `/dev:simplify-code <target>` | Simplify without behavior change |
| `/dev:recap` | Extract patterns → CLAUDE.md |
| `/dev:create-issue <title>` | Standalone GitHub issue |
| `/dev:create-pr [ready]` | Draft PR (or ready) |
