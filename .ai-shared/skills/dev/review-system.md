# /review-system — Architecture Review

Find doc from $ARGUMENTS or latest `docs/architecture/`. Read doc + project AI config files.

## Review Checklist

**Problem**: pain quantified, constraints justified, success measurable, `Contexts` field filled (affected bounded contexts + integration style)

**Options**: ≥2 viable, trade-offs honest, failure modes specific, dependencies identified, context coupling rated

**Decision**: rationale traces to trade-offs, rejected options have reasons, `Contracts` block specifies invariants per affected boundary (or "no boundary changes")

**Migration**: phases deployable independently, each has rollback, dual-run realistic, cutover trigger objective

**Decomposition**: ordered by dependency, no cycles, first plan unblocked

## Flags

**Blocking:** missing failure mode for critical path, no rollback for destructive phase, circular dependency, unmeasurable success, undefined contracts on a changed boundary

**Warning:** single option, phase >2 weeks without checkpoint, team unfamiliar with key components

## Self-Check (BLOCKING — do NOT emit verdict until every item is ✅)

Run this audit before the final output. If ANY blocking item is unchecked → verdict is NEEDS REVISION.

- [ ] **Problem quantified** (Checklist Problem): measurable pain, justified constraints, success target + baseline.
- [ ] **Options sufficient** (Checklist Options): ≥2 viable, honest trade-offs, specific failure modes, dependencies, context coupling rated.
- [ ] **Contracts** (Checklist Decision): invariants per affected boundary (or "no boundary changes"). Missing: __.
- [ ] **Migration viable** (Checklist Migration): independently deployable phases, each rollback, realistic dual-run, objective cutover.
- [ ] **Decomposition sound** (Checklist Decomposition): dependency-ordered, no cycles, first plan unblocked.
- [ ] **Blocking checks** (`## Flags`): no missing critical-path failure mode, no destructive phase without rollback, no circular dependency, measurable success.

If ALL ✅ → verdict APPROVED, update status to `approved`. Print: "Architecture approved. Create plans with the design-feature skill."
If ANY ❌ → verdict NEEDS REVISION. List specific sections to revise.

## Output

```
## Architecture Review: <name>

### Verdict: APPROVED | NEEDS REVISION

### ❌ Blocking
- <issue>: <why blocking> → <suggested fix>

### ⚠️ Warnings
- <issue>: <risk>

### ✅ Strengths
- <what's good>

### Questions for Author
- <clarification needed>
```

If APPROVED: the Self-Check already authorized status `approved`. Print: "Architecture approved. Create plans with the design-feature skill."

If NEEDS REVISION: list specific sections to revise.
