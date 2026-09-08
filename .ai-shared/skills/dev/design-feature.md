# /design-feature — Plan Application Work

Read [PROCESS.md](../../PROCESS.md) and [plan.md](plan.md). Design proposes behavior; [approval.md](approval.md) owns approval. Use [frame-goal.md](frame-goal.md) for material ambiguity, [design-system.md](design-system.md) for changed system boundaries, and [frontend-design.md](frontend-design.md) for UI work.

Inspect the relevant code, contracts, and project conventions. Confirm a concrete base branch. Create a new `docs/plans/<basename>_<date>_<type>_<slug>.md`, where type is `feature`, `fix`, or `refactor`.

## Plan schema

```text
# Task: <name>
Status: planning | Type: feature|fix|refactor | Base: <branch> | Issue: #N | Worktree:
## Goal
<the user's intended outcome>
## Scope
<in / out>
## Acceptance Criteria
AC-1 — <observable outcome>
  Source: <goal, contract, or domain requirement>
  Success: <observable result>
  Failure: <violating result>
## Test Cases (intent)
TC-1 — <scenario and distinguishing condition>
  Proves: AC-1
  Test: <path::name, filled during execution>
## Implementation Steps
Step 1 — <change and files/symbols> — satisfies TC-1
## PR Pattern (provisional)
Type: single
| # | Branch | Parent | Steps | Summary |
|---|---|---|---|---|
| 1 | feat/example | <base> | 1 | <outcome> |
```

Each TC names exactly one AC and belongs to an implementation step. Use explicit IDs rather than ID ranges in traceability references. Item counts follow the behavior the Goal requires; there are no quotas.

Add only useful sections: `## Context`, `## Design Decisions`, `## Affected Existing Tests`, `## Assumptions & Open Questions`, or `## Open Risks`. Open Questions use an `Open Questions:` field; unresolved requirements block review. Open Risks are verification uncertainties assigned to existing TCs, not permission to change behavior.

Later phases add `## Review History`, `## Deviations`, `## Discovered Scope`, and `## Coverage Gaps` when needed. Execution records proof/results and fills test references; review finalizes the PR Pattern.

Use [PROCESS.md — Repository conventions](../../PROCESS.md#repository-conventions) for design notation and [CODING.md — Impact](../../CODING.md#impact) for affected contracts and shared state. Investigate the rationale before removing an existing guard or observable behavior. Record material compatibility risks and required decisions.

## Derive and challenge the spec

1. **Preserve the outcome.** Identify actors, triggers, required results, constraints, and prohibited outcomes from the Goal and inspected contracts. Make subjective requirements decidable through observable measures or concrete scenarios; ask when the intended threshold or behavior is unresolved.
2. **Derive ACs before tests.** Give each AC one coherent, observable outcome and its source. Success and Failure must be decidable without consulting a TC. Specify implementation-independent behavior unless a particular mechanism is an explicit constraint.
3. **Check Goal completeness.** Could every AC pass while the Goal remains unmet? Add or correct the missing obligation before deriving TCs. Do not let convenient tests determine the requirement.
4. **Cover each obligation.** Derive TC intents for each distinct condition in an AC, including required side effects and prohibited mutations. Cover relevant valid, invalid, boundary, and failure scenarios, plus combinations that change behavior, such as retries after partial failure. Feature/fix TCs distinguish the requested change; refactor TCs preserve existing behavior. Executable arrangements and assertions belong to execution.
5. **Challenge adequacy.** For each AC, check whether a plausible incorrect implementation could pass its TCs, or whether the AC would reject valid behavior. For material gaps or non-obvious safeguards, record the target, concrete incorrect behavior, and the AC/TC that defeats it or the correction needed. A test that merely repeats an AC's wording does not establish coverage; manufactured attacks and a separate counterexample quota are unnecessary.
6. **Connect obligations to delivery.** Order steps by dependencies and map them to TCs. For new state or mechanisms, record the operational invariant, initialization/identity conditions, and relevant transition or boundary scenario under Design Decisions. Map performance, security, and other non-functional commitments to measurable ACs/TCs and steps; identify the owner and verification for any operational prerequisite outside application implementation.

Use the completed AC/TC mapping and material challenge evidence to establish readiness; keep each fact in one place.

### Example: partial refunds

This abbreviated illustration covers balance behavior; an actual plan derives any other obligations from its own contracts.

```text
Goal: Support partial refunds without refunding more than the captured amount.
AC-1 — a positive refund up to the remaining balance succeeds
  Source: Goal — support partial refunds
  Success: accept the refund and debit exactly its amount
  Failure: reject a valid amount or debit a different amount
AC-2 — a refund above the remaining balance is rejected without changing the ledger
  Source: Goal — never refund more than captured
  Success: reject the refund and leave the ledger unchanged
  Failure: accept the refund or make any ledger change
TC-1 — refund 30 from a remaining 50; accept and leave 20
  Proves: AC-1
TC-2 — refund exactly the remaining 20; accept and leave 0
  Proves: AC-1
TC-3 — after refunding 30 from a captured 50, another 30 is rejected and the ledger stays unchanged
  Proves: AC-2
```

Rejecting every request satisfies rejection-only tests but violates AC-1. Checking against the original capture instead of the remaining balance fails TC-3. Checking only TC-3's rejection result would miss an erroneous ledger mutation.

## PR slicing

Default to one branch. Use `Type: chain` only for coherent, independently mergeable and revertible units. Every row records its explicit Parent and owned steps. A slice includes its tests and implementation and must pass without later slices. Never split a TC across slices.

The first Parent normally equals Base; work extending an unmerged PR instead records that PR's branch. Later rows normally parent on the previous branch. Review and publication use these recorded parents.

## Issue and completion

Link the supplied issue, including a shared parent issue, or create one from the Goal and scope. Verify a named issue matches the work and is open. Preserve sibling goals in shared issues; update only this goal's information. Record `Issue: #N` before handoff.

Finish when the Goal is covered by decidable ACs, meaningful TCs, ordered steps, valid PR slices, and no unresolved requirements. Save the planning artifact and hand it to [review-feature.md](review-feature.md).
