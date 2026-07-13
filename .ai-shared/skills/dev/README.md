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

`/dev:ship-feature <requirement>` — explore → design-feature → review-feature → execute → review-code → recap → PR

Resume: `/dev:ship-feature add-jwt from execute`

Plan review enforces the open-questions gate: if `design-feature` saves a draft with unresolved `Open Questions:`, `review-feature` stops and routes back to planning.

**Human approval, always.** A plan is approved only after an explicit human answer to `Approve plan?`. Direct skill use records that approval by manually setting `Status: approved`; in `/dev:ship-feature`, the orchestrator records it after its plan-phase PAUSE. Implementing skills (`execute-feature`, `execute-infra`, and `fix-bug` when a plan is active) only verify `approved` before touching files and may transition it to `in-progress`. The one exception is planless `fix-bug`: its bootstrapped fix plan is an execution record created directly `in-progress` — the fix request itself is the human decision.

**Lite lane.** Small changes (≤2 non-test files, no new data structure, no contract/schema change, no security surface) get `Mode: lite` at design time: condensed plan (Requirement, Scope, TCs, 1–3 steps, single-PR pattern), structural-only review. Execution rigor is unchanged — RED commit, coverage, symbol membership all apply. Any lite condition proven false mid-flight → escalate to `Mode: full` and re-review; never widen a lite plan in place.

**Session-pinned active plan.** Each session has one active plan. Establish it by naming an existing plan (`docs/plans/<file>.md` or its slug) in the skill args, or by running `design-feature` (the new plan is adopted on the next gated skill). It is then reused for the rest of the session; naming a different plan re-pins. With 0 or 2+ active plans and none named, gated skills STOP and ask which.

Every dev skill ends with a blocking self-check. Do not emit the skill's handoff line until that checklist is verified against the artifacts.

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
| `/dev:write-rca <issue/pr>` | RCA/incident report from issues and PRs |
| `/dev:create-issue <title>` | Standalone GitHub issue |
| `/dev:create-pr [ready]` | Draft PR (or ready) |
