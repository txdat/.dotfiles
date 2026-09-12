# /design-feature — Plan Application Work

Read [PROCESS.md](../../PROCESS.md) and [plan.md](plan.md). Design proposes behavior; [approval.md](approval.md) owns approval. Use [frame-goal.md](frame-goal.md) for material ambiguity, [design-system.md](design-system.md) for changed system boundaries, and [frontend-design.md](frontend-design.md) for UI work.

Inspect the relevant code, contracts, and project conventions. Confirm a concrete base branch. Complete the ambiguity gate below before drafting or creating a new `docs/plans/<basename>_<date>_<type>_<slug>.md`, where type is `feature`, `fix`, or `refactor`.

## Resolve ambiguity before writing

All ambiguous factors in the intended behavior, scope, and design must be resolved before writing the plan. Establish **why each factor exists, what problem it resolves, and how it is obtained or derived**. Identify the source and meaning of requirements, domain terms, values, and proposed mechanisms; define data meaning, derivation, and relevant edge cases. For example, “rank by percentage” must define both the entity being ranked and the percentage's numerator and denominator.

Resolve questions from the user's existing answers, authoritative contracts, and inspected evidence first. Existing code establishes current behavior, not necessarily intended behavior. Resolve routine technical choices within those constraints using project conventions and engineering judgment. If intended behavior or scope still admits competing interpretations, present a concrete scenario and their differing consequences and obtain the missing decision from the user; do not silently select product semantics. Investigation and candidate AC/fixture sketches may proceed in clarification notes; the plan must not be drafted around unresolved assumptions or TBDs. Implementation details that do not change the agreed contract or design may remain for execution.

Carry resolved behavioral semantics into the ACs. Record decision rationale, sources, and derivations in `## Design Decisions` where needed, referencing them from ACs/TCs instead of duplicating them. If ambiguity emerges while drafting or reviewing, stop dependent plan work, resolve it, then revise the affected ACs, fixtures, TCs, and steps. Verification uncertainty may remain as an Open Risk only when intended behavior and its expected result are already settled.

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
  Fixture: <concrete inputs, identities/relationships, and relevant starting state; inline or exact shared fixture reference>
  Action: <operation or event sequence>
  Expected: <precise observable result and relevant final state, including prohibited mutations>
  Test: <path::name, filled during execution>
## Implementation Steps
Step 1 — <change and files/symbols> — satisfies TC-1
## PR Pattern (provisional)
Type: single
| # | Branch | Parent | Steps | Summary |
|---|---|---|---|---|
| 1 | feat/example | <base> | 1 | <outcome> |
```

Each TC names exactly one AC, includes a concrete fixture, action, and expected result, and belongs to an implementation step. Shared fixtures may live in `## Test Fixtures` with explicit IDs; each TC names its fixture and any overrides and states its own expected result. Fixtures are language-neutral example data, not executable setup code. Use explicit IDs rather than ID ranges in traceability references. Item counts follow the behavior the Goal requires; there are no quotas.

Fixtures specify enough relevant data and state to derive the expected result without inventing semantics during execution; large or generated datasets may use a precise construction rule. Use exact values for deterministic results; for permitted variability, define the allowed set, tolerance, invariant, or measurable bound from the contract.

Add only useful sections: `## Context`, `## Design Decisions`, `## Test Fixtures`, `## Affected Existing Tests`, or `## Open Risks`. Route unresolved behavioral, scope, or design questions through the ambiguity gate instead of parking them in Assumptions or Open Questions, so execution proceeds from settled requirements. If an existing plan has an unresolved `Open Questions:` field, return to the ambiguity gate before continuing. Open Risks are verification uncertainties assigned to existing TCs, not permission to change behavior.

Later phases add `## Review History`, `## Deviations`, `## Discovered Scope`, and `## Coverage Gaps` when needed. Execution records proof/results and fills test references; review finalizes the PR Pattern.

Use [PROCESS.md — Repository conventions](../../PROCESS.md#repository-conventions) for design notation and [CODING.md — Impact](../../CODING.md#impact) for affected contracts and shared state. Investigate the rationale before removing an existing guard or observable behavior. Record material compatibility risks and required decisions.

## Derive and challenge the spec

1. **Preserve the outcome.** Identify actors, triggers, required results, constraints, and prohibited outcomes from the Goal and inspected contracts. Make subjective requirements decidable through observable measures or concrete scenarios; ask when the intended threshold or behavior is unresolved.
2. **Derive ACs before tests.** Give each AC one coherent, observable outcome and its source. Success and Failure must be decidable without consulting a TC. Specify implementation-independent behavior unless a particular mechanism is an explicit constraint.
3. **Check Goal completeness.** Could every AC pass while the Goal remains unmet? Add or correct the missing obligation before deriving TCs. Do not let convenient tests determine the requirement.
4. **Cover each obligation.** Derive TC intents with concrete fixtures, actions, and expected results for each distinct condition in an AC, including required side effects and prohibited mutations. Cover relevant valid, invalid, boundary, and failure scenarios, plus combinations that change behavior, such as retries after partial failure. Feature/fix TCs distinguish the requested change; refactor TCs preserve existing behavior. Compute expected results from the resolved contract, independently of the proposed implementation; show the calculation when it determines the outcome. Executable setup and assertion code belong to execution, but fixture data and expected results must be settled during design.
5. **Challenge adequacy.** For each AC, check whether a plausible incorrect implementation could pass its TCs, or whether the AC would reject valid behavior. Select fixtures where plausible competing interpretations produce different observable results: vary relevant identities, cardinalities, values, and interacting modes instead of using only uniform happy-path data. For material gaps or non-obvious safeguards, record the target, concrete incorrect behavior, and the AC/TC with a distinguishing fixture that defeats it or the correction needed. A test that merely repeats an AC's wording does not establish coverage; manufactured attacks and a separate counterexample quota are unnecessary.
6. **Connect obligations to delivery.** Order steps by dependencies and map them to TCs. For new state or mechanisms, record the operational invariant, initialization/identity conditions, and relevant transition or boundary scenario under Design Decisions. Map performance, security, and other non-functional commitments to measurable ACs/TCs and steps; identify the owner and verification for any operational prerequisite outside application implementation.
7. **Estimate complexity and justify the approach.** Apply [Complexity and simpler alternatives](#complexity-and-simpler-alternatives) before finalizing the design. If the selected approach changes, revisit steps 4–6 and reconcile affected fixtures, TCs, implementation steps, and PR slices with that approach. Changes to intended behavior or scope return to the ambiguity gate and affected ACs first.

Establish readiness from the completed AC/TC mapping, material challenge evidence, and impact-appropriate complexity assessment, with delivery steps and PR slices matching the selected approach. Keep each fact in one place.

### Complexity and simpler alternatives

Scale analysis to the change's impact across feature, fix, and refactor plans. When neither computational/resource cost nor implementation complexity changes meaningfully, a one-sentence explanation suffices. Otherwise record the relevant analysis in Design Decisions.

For affected computational/resource costs, derive typical-case and worst-case time and space estimates from operations and their interactions. State input sizes, allocation scope, assumptions, and material I/O costs. Support the typical workload with evidence, or label it unknown and give conditional estimates; report an unbounded worst case where applicable. Do not invent workload limits.

Analytical estimates do not require running code. Use measurements, query plans, or targeted experiments when practical limits need validation; identify their workload and environment. Big-O alone does not establish latency or memory usage in bytes, and a benchmark does not prove a worst-case bound. Justified measurement gaps may remain Open Risks with verification TCs when requirements are settled. Missing requirements return to the ambiguity gate; unknown workload observations alone are not unresolved product semantics.

Assess changes to abstractions, dependencies, state, and coordination separately from runtime cost. Warn with a concrete cause and consequence when cost threatens required limits or implementation complexity is disproportionate to its benefit. Compare a simpler viable alternative's affected costs and maintenance tradeoffs, including typical/worst-case estimates where relevant, and recommend one; explain when no simpler approach preserves the requirements. Record the selected approach and rationale. Changes to agreed behavior follow [approval.md](approval.md).

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
  Fixture: captured = 50; prior refunds = []; remaining = 50
  Action: request refund of 30
  Expected: accepted; append one refund of 30; remaining = 20
TC-2 — refund exactly the remaining 20; accept and leave 0
  Proves: AC-1
  Fixture: captured = 50; prior refunds = [30]; remaining = 20
  Action: request refund of 20
  Expected: accepted; refunds = [30, 20]; remaining = 0
TC-3 — after refunding 30 from a captured 50, another 30 is rejected and the ledger stays unchanged
  Proves: AC-2
  Fixture: captured = 50; prior refunds = [30]; remaining = 20
  Action: request another refund of 30
  Expected: rejected; refunds = [30]; remaining = 20; no ledger mutation
```

Rejecting every request satisfies rejection-only tests but violates AC-1. Checking against the original capture instead of the remaining balance fails TC-3. Checking only TC-3's rejection result would miss an erroneous ledger mutation.

### Example: discount ranking ambiguity

“Rank by percentage” leaves open whether the ranked entity is a record, an occurrence, or a `(record, product)` pair. Percentage-only fixtures can hide this difference. Resolve the identity and discount derivation before writing ACs; do not infer them from this example.

Suppose the confirmed contract ranks eligible `(record, product)` pairs by descending `100 × discount amount / product price`, breaking ties by ascending record ID, then product ID. A distinguishing fixture has products A = 100 and B = 200 (same currency, quantity one each), fixed-discount record F = 30 per eligible product, and percentage record P = 20%, both eligible for A and B. Ranking these pairs must yield `[F/A, P/A, P/B, F/B]`, with scores `[30%, 20%, 20%, 15%]`. This fixture exposes reusing one percentage for F across products; a fixture containing only P would not. It does not distinguish pair identity from occurrence identity; if repeated occurrences are relevant, derive a separate fixture for that distinction.

## PR slicing

Default to one branch. Use `Type: chain` only for coherent, independently mergeable and revertible units. Every row records its explicit Parent and owned steps. Assign each TC to one code slice that includes its tests and the implementation needed to pass them without later slices. Shared fixtures may be inherited from a parent.

For `Type: chain`, record a leading docs publication entry alongside the numbered code rows: branch, explicit Parent, owned plan paths, and documentation checks. Its Parent is Base, or the unmerged branch this work extends; the first code row parents on the docs branch. Later code rows normally parent on the previous code branch. The docs entry has no implementation steps or code-green claim. [plan.md — Approved snapshots](plan.md#approved-snapshots) owns its contents and preparation.

For a single code PR, its Parent normally equals Base, or the unmerged branch this work extends. Review and publication use the recorded parents. Chain order is dependency, PR-creation, and merge order; [create-pr.md](create-pr.md) publishes docs first, then code slices from first to last.

## Issue and completion

Link the supplied issue, including a shared parent issue, or create one from the Goal and scope. Verify a named issue matches the work and is open. Preserve sibling goals in shared issues; update only this goal's information. Record `Issue: #N` before handoff.

Finish when the ambiguity gate is satisfied and the Goal is covered by decidable ACs, meaningful TCs with concrete fixtures and expected results, ordered steps, and valid PR slices. Save the planning artifact and hand it to [review-feature.md](review-feature.md).
