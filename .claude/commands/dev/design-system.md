---
model: opus
effort: high
---

# /design-system — Architecture Design

Cross-cutting changes: polling→events, sync→async, monolith→services, new integrations.

Feature-level → `/dev:design-feature`. `skip approval` → auto-approve. No code.

Filename: `docs/architecture/<date>_<slug>.md`. Read `CLAUDE.md`.

## Phase 1 — Problem Framing

Clarify: pain, constraints, scale, team capacity. Up to 3 rounds.

```
# Architecture: <name>
Status: draft | Date: <date>
Current: <how it works>
Pain: <issue> → <impact>
Constraints: <what> — <why non-negotiable>
Success: <metric> <target> (baseline: <current>)
```

## Phase 2 — Options Analysis

Generate 2-4 options:

```
## Option <N>: <name>
<description>

| Dimension  | L/M/H | Notes |
|------------|-------|-------|
| Complexity |       |       |
| Migration  |       |       |
| Ops cost   |       |       |
| Team fit   |       |       |
| Rollback   |       |       |

Failure modes: <failure> → <detection> → <recovery>
Dependencies: <system>: <change>
```

## Phase 3 — Decision

Ask: "Agree with recommendation?"

```
Chosen: Option <N> — <1-2 sentence rationale>
Trade-offs accepted: <trade-off> — <why>
Rejected: <Option X> — <reason>
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

Save. Print: path, chosen option, plan count. Output: "Run /dev:review-system."
