# Dev Skills

## Hierarchy

```
/design-system → /review-system → architecture approval
    ↓ each phase enters the application lane when dependencies permit
/design-feature → /review-feature → spec approval → RED → GREEN → BLUE
```

Architecture uses a separate falsifiable chain: goal and constraints → options → recommendation → boundary contracts → reversible phases → measured outcome. Independent review precedes human approval. Each approved contract is assigned to a feature plan, where observable behavior enters Goal → AC → TC → RED → GREEN → BLUE; architecture never replaces the feature Goal.

## Full Feature Cycle

`/dev:ship-feature <requirement>` — explore → design-feature → review-feature → spec approval → execute → review-code → PR

Resume: `/dev:ship-feature add-jwt from execute`

Plan review enforces the Open Questions gate and does the real work: it independently derives the expected outcomes from `## Goal` before reading the proposed TCs, then attacks them with counterexamples. It returns READY; it never approves.

**One application-spec approval, and it is the human's.** `approval.md` is the single source: after review returns READY, the full Goal/AC/TC spec is shown and the user answers `Approve this spec?` — approve, or name the IDs to revise or drop. Only that answer sets `Status: approved`. There is no inferred, request-as-approval, urgent-fix, or planless-mutation shortcut; behavior-preserving cleanup is a `Type: refactor` plan like any other change. Changing approved behavior later returns the plan to `planning` and back through review and the pause. A different *means* to the same behavior is an ordinary `## Deviations` record, not a re-approval.

Know what enforces what. For application plans, `gate-check` blocks on `Status: approved` and facts a script can verify — status, issue, worktree, proof order, and PR pattern. It does not judge plan or architecture prose or identify who approved it. Human pauses enforce decisions; adversarial reviews provide rigor.

**BDD then TDD.** BDD owns `Goal → AC → Given/When/Then TC` and answers whether the right behavior is specified. TDD consumes only approved TCs through RED → GREEN → BLUE and answers whether code implements that behavior. Passing TCs never overrides a failed AC or Goal; contradictions return to design/review and human reapproval.

**One lane, scaled to the change.** There is no lite mode. A small change gets a short plan because it has little to say, not because a flag excused it — and Goal, ACs, TCs, adversarial review, the approval pause, RED proof, coverage, and symbol gates apply to every change regardless of size.

**Session-pinned active plan.** Resolution and ambiguity handling follow ENGINEERING_CORE `Active plan and entry gates`; name the plan explicitly when more than one is active.

Every dev skill ends with a blocking self-check. Do not emit the skill's handoff line until that checklist is verified against the artifacts.

---

## Design Skills

| Skill | Scope | Output |
|-------|-------|--------|
| `/dev:design-system` | Boundaries, communication, decomposition | `docs/architecture/<date>_<slug>.md` |
| `/dev:design-feature` | Feature/fix/refactor | `docs/plans/<basename>_<date>_<type>_<slug>.md` |

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
| `/dev:fix-bug diagnose <symptom>` | Read-only root-cause diagnosis |
| `/dev:fix-bug execute <fix-plan>` | Execute an already reviewed and human-approved fix plan |

## Utility Skills

| Skill | Purpose |
|-------|---------|
| `/dev:explore <target>` | Map entry points, flow, patterns |
| `/dev:create-issue <title>` | Standalone GitHub issue |
| `/dev:create-pr [ready]` | Draft PR (or ready) |
