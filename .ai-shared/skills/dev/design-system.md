# /design-system — Architecture Design

Cross-cutting changes: polling→events, sync→async, monolith→services, new integrations.

Feature-level → use the design-feature skill. No code.

Filename: `docs/architecture/<date>_<slug>.md`. Read project AI config files.

## Phase 1 — Problem Framing

Clarify: pain, constraints, scale, team capacity. Up to 3 rounds.

```
# Architecture: <name>
Status: draft | Date: <date>
Current: <how it works>
Pain: <issue> → <impact>
Constraints: <what> — <why non-negotiable>
Contexts: <bounded contexts affected> — <current integration style between them>
Success: <metric> <target> (baseline: <current>)
```

## Phase 2 — Options Analysis

Generate 2-4 options:

```
## Option <N>: <name>
<description>

| Dimension        | L/M/H | Notes |
|------------------|-------|-------|
| Complexity       |       |       |
| Migration        |       |       |
| Ops cost         |       |       |
| Team fit         |       |       |
| Rollback         |       |       |
| Context coupling |       |       |

Failure modes: <failure> → <detection> → <recovery>
Dependencies: <system>: <change>
```

## Phase 3 — Decision

Ask: "Agree with recommendation?"

```
Chosen: Option <N> — <1-2 sentence rationale>
Trade-offs accepted: <trade-off> — <why>
Rejected: <Option X> — <reason>
Contracts:
  <context-a> → <context-b>: <event or call> — invariant: <what must hold across the boundary>
  no boundary changes
```

## Phase 4 — Migration Strategy

```
## Migration
Phases:
  1. <name> (<duration>) — deliverable: <what>, rollback: <how>, gate: <metric>
  2. ...
Dual-run: <N weeks>, sync: <mechanism>, cutover: <trigger>
Rollback: trigger: <condition>, steps: <high-level>, data: <reconciliation>
```

## Phase 5 — Decomposition

```
| Order | Plan   | Scope   | Depends on |
|-------|--------|---------|------------|
| 1     | <slug> | <scope> | —          |
| 2     | <slug> | <scope> | 1          |
```

Ask: "Create plan files?" → stubs with `Status: blocked-by-architecture`.

## Self-Check (BLOCKING — do NOT emit completion until every item is ✅)

Run this audit before the final output. If ANY item is unchecked → STOP, fix, re-check.

- [ ] **Problem framing** (Phase 1): pain quantified, constraints justified, success measurable, `Contexts` filled.
- [ ] **Options** (Phase 2): ≥2 viable, trade-offs honest per dimension, failure modes (detection + recovery) per option, dependencies identified.
- [ ] **Decision** (Phase 3): rationale traces to trade-offs, rejected options have reasons, `Contracts:` invariants per boundary (or "no boundary changes").
- [ ] **Migration** (Phase 4): phases independently deployable, each with rollback, realistic dual-run, objective cutover.
- [ ] **Decomposition** (Phase 5): dependency-ordered, no cycles, first plan unblocked. Plan count: __.

If ALL checked → save, emit "Run the review-system skill."
