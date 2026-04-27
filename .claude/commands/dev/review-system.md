---
model: opus
effort: high
---

# /review-system — Architecture Review

Find doc from $ARGUMENTS or latest `docs/architecture/`. Read doc + `CLAUDE.md`.

## Review Checklist

**Problem**: pain quantified, constraints justified, success measurable

**Options**: ≥2 viable, trade-offs honest, failure modes specific, dependencies identified

**Decision**: rationale traces to trade-offs, rejected options have reasons

**Migration**: phases deployable independently, each has rollback, dual-run realistic, cutover trigger objective

**Decomposition**: ordered by dependency, no cycles, first plan unblocked

## Flags

**Blocking:** missing failure mode for critical path, no rollback for destructive phase, circular dependency, unmeasurable success

**Warning:** single option, phase >2 weeks without checkpoint, team unfamiliar with key components

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

If APPROVED: update status to `approved`. Print: "Architecture approved. Create plans with /dev:design-feature."

If NEEDS REVISION: list specific sections to revise.
