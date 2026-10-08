# /design-feature — Plan Application Work

Read [PROCESS.md](../../PROCESS.md) and [plan.md](plan.md). Design proposes behavior; [approval.md](approval.md) owns approval. Use [frame-goal.md](frame-goal.md) for material ambiguity, [design-system.md](design-system.md) for changed system boundaries, and [frontend-design.md](frontend-design.md) for UI work.

Inspect the relevant code, contracts, and project conventions. Confirm a concrete base branch. Complete the ambiguity gate below before drafting or creating a new `docs/plans/<area>_<date>_<type>_<slug>.md`, where area is a short label grouping related plans (repository, module, or issue number) and type is `feature`, `fix`, or `refactor`.

Before drafting, select the plan language under [language.md](language.md).

## Resolve ambiguity before writing

Resolve ambiguities that materially affect the requested outcome, an affected contract, or the chosen design before writing the plan. Establish **why each factor exists, what problem it resolves, and how it is obtained or derived**. Identify the source and meaning of requirements, domain terms, values, and proposed mechanisms; define data meaning, derivation, and edge cases that meet [Scope and evidence](#scope-and-evidence). For example, “rank by percentage” must define both the entity being ranked and the percentage's numerator and denominator. Treat a fix or mechanism the issue or request proposes as a hypothesis unless the user states it as an explicit constraint: reduce it to the outcome it protects and design only for the part no other obligation already delivers. Before dropping or narrowing a stated item, stop and obtain the user's decision; record it in `## Design Decisions` with the obligation that covers the item's outcome.

Resolve questions from the user's existing answers, authoritative contracts, and inspected evidence first. Existing code establishes current behavior, not necessarily intended behavior. Resolve routine technical choices within those constraints using project conventions and engineering judgment. If intended behavior or scope still admits competing interpretations, present a concrete scenario and their differing consequences and obtain the missing decision from the user; do not silently select product semantics. Investigation and candidate AC/fixture sketches may proceed in clarification notes; the plan must not be drafted around unresolved assumptions or TBDs. Implementation details that do not change the agreed contract or design may remain for execution.

Carry resolved behavioral semantics into the ACs. Record decision rationale, sources, and derivations in `## Design Decisions` where needed, referencing them from ACs/TCs instead of duplicating them. If ambiguity emerges while drafting or reviewing, stop dependent plan work, resolve it, then revise the affected ACs, fixtures, TCs, and steps. Verification uncertainty may remain as an Open Risk only when intended behavior and its expected result are already settled.

## Split scope before splitting work

Separate the goal into API-contract, backend (BE/server), and frontend (FE/client) responsibilities before slicing work. Include only affected scopes; reference unchanged contracts.

- **API contract** owns shared boundary semantics: relevant requests, responses, errors, authorization obligations, data meaning, compatibility, and contract examples/fixtures. Identify the authoritative contract artifact and how it will be validated.
- **BE** owns server implementation, persistence, side effects, and verification of conformance to the contract.
- **FE** owns client integration, user interactions and states, and verification of conformance to the same contract.

When BE and FE both change, give each its own plan with `be` and `fe` slug suffixes; sections or PR slices inside one plan do not satisfy this separation. A changed contract belongs to the plan that implements its producer, normally BE: define it there in Design Decisions or a referenced contract artifact, prove it through that plan's ACs/TCs, and ship artifact changes in the slice that implements them. A contract change with no implementing code is documentation under [PROCESS.md — Scope](../../PROCESS.md#scope). Design and review the contract first; the consumer plan derives from its reviewed revision and may not silently redefine it. Contract changes reopen affected consumer decisions under [approval.md](approval.md).

In `## Related Plans`, record the overall outcome, exact sibling paths, the contract source and revision, and dependency conditions. Use path-qualified IDs for cross-plan references and reference authoritative semantics and fixtures instead of copying them. A shared issue can connect the plans; an executable umbrella plan is unnecessary.

Check that the plans together cover the overall outcome without conflicting ownership. Assign cross-scope integration verification to an explicit owning plan and TC with concrete prerequisite state and expected results; contract-based mocks may unblock FE work but do not prove integration with BE. Record development, merge, and release dependencies where they differ. Each plan keeps its own review and approval.

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

A chain lists one row per slice:

```text
## PR Pattern (provisional)
Type: chain
| # | Branch | Parent | Steps | Summary |
|---|---|---|---|---|
| 1 | feat/example-1 | <base> | 1 | <outcome> |
| 2 | feat/example-2 | feat/example-1 | 2 | <outcome> |
```

Each TC names exactly one AC, includes a concrete fixture, action, and expected result, and belongs to an implementation step. Shared fixtures may live in `## Test Fixtures` with explicit IDs; each TC names its fixture and any overrides and states its own expected result. Fixtures are language-neutral example data, not executable setup code. Use explicit IDs rather than ID ranges in traceability references. Item counts follow the behavior the Goal requires; there are no quotas.

Fixtures specify enough relevant data and state to derive the expected result without inventing semantics during execution; large or generated datasets may use a precise construction rule. Use exact values for deterministic results; for permitted variability, define the allowed set, tolerance, invariant, or measurable bound from the contract.

Add only useful sections: `## Context`, `## Design Decisions`, `## Test Fixtures`, `## Affected Existing Tests`, or `## Open Risks`. Route unresolved questions that materially affect the requested outcome, an affected contract, or the chosen design through the ambiguity gate instead of parking them in Assumptions or Open Questions. Apply the same criterion to an existing plan's `Open Questions:` field; optional follow-up questions do not block readiness. Open Risks are verification uncertainties assigned to existing TCs, not permission to change behavior.

Later phases add `## Review History`, `## Deviations`, `## Discovered Scope`, and `## Coverage Gaps` when needed. Execution records proof/results and fills test references; review finalizes the PR Pattern.

Use [PROCESS.md — Repository conventions](../../PROCESS.md#repository-conventions) for design notation and [CODING.md — Impact](../../CODING.md#impact) for affected contracts and shared state. Investigate the rationale before removing an existing guard or observable behavior. Record material compatibility risks and required decisions.

## Derive and challenge the spec

### Scope and evidence

Derive ACs from the Goal, explicit constraints, and affected contracts. Derive TCs to prove those obligations under realistic conditions. An edge or failure case belongs when an explicit requirement demands it or a reachable input, state, or failure in the supported workflow could violate an obligation. Ground reachability in inspected validation, data constraints, callers, dependency behavior, or the proposed design; a prior incident is not required. For non-obvious cases, briefly name that basis and the consequence beside the TC or in Design Decisions.

Do not invent product capabilities, unsupported operating modes, impossible states, or arbitrary limits to create coverage. Synthetic fixtures are valid when they represent reachable conditions. Malformed or adversarial inputs belong at boundaries that can receive them, even when the inputs are invalid; downstream duplication needs a distinct failure risk. Low frequency alone does not exclude a reachable case with a material consequence. Do not assume a guard exists to dismiss a case; inspect it or include it in the design.

Use a focused set of scenarios that distinguish materially different required behavior or credible failure mechanisms. Add combinations only when their interaction changes the result or risk. Reuse or strengthen a fixture before adding redundant TCs, while keeping each scenario easy to understand; do not fill a category matrix or add a case solely because it is imaginable. Optional hardening outside the Goal and affected contracts may be suggested as follow-up work, not added as a new AC or readiness blocker. Ask about an edge case only when the unresolved behavior materially affects in-scope correctness.

### Derivation

1. **Preserve the outcome.** Identify actors, triggers, required results, constraints, and prohibited outcomes from the Goal and inspected contracts. Make subjective requirements decidable through observable measures or concrete scenarios; ask when the intended threshold or behavior is unresolved.
2. **Derive ACs before tests.** Give each AC one coherent, observable outcome and its source. Success and Failure must be decidable without consulting a TC. Specify implementation-independent behavior unless a particular mechanism is an explicit constraint.
3. **Check Goal completeness.** Could every AC pass while the Goal remains unmet? Add or correct the missing obligation before deriving TCs. Do not let convenient tests determine the requirement.
4. **Cover each obligation.** Derive TC intents with concrete fixtures, actions, and expected results for distinct required behavior, including required side effects and prohibited mutations. Select scenarios under Scope and evidence. Feature/fix TCs distinguish the requested change; refactor TCs preserve affected existing behavior. Compute expected results from the resolved contract, independently of the proposed implementation; show the calculation when it determines the outcome. Executable setup and assertion code belong to execution, but fixture data and expected results must be settled during design.
5. **Challenge adequacy.** Check whether a plausible incorrect implementation could pass the TCs, or whether an AC would reject valid behavior. Use counterexamples that meet Scope and evidence, varying only inputs or modes relevant to the suspected gap. For material gaps or non-obvious safeguards, record the target, concrete incorrect behavior, and the AC/TC with a distinguishing fixture that defeats it or the correction needed. A test that merely repeats an AC's wording does not establish coverage. When existing fixtures already distinguish the failure, no additional TC is needed.
6. **Connect obligations to delivery.** Order steps by dependencies and map them to TCs. For new state or mechanisms, record the operational invariant, initialization/identity conditions, and relevant transition or boundary scenario under Design Decisions. Map performance, security, and other non-functional commitments to measurable ACs/TCs and steps; identify the owner and verification for any operational prerequisite outside application implementation.
7. **Estimate complexity and justify the approach.** Apply [Complexity and simpler alternatives](#complexity-and-simpler-alternatives) before finalizing the design. If the selected approach changes, revisit steps 4–6 and reconcile affected fixtures, TCs, implementation steps, and PR slices with that approach. Changes to intended behavior or scope return to the ambiguity gate and affected ACs first.

For worked illustrations of fixture coverage and ambiguity resolution, see [design examples](reference/design-feature-examples.md).

### Complexity and simpler alternatives

Scale analysis to impact. When neither computational/resource cost nor implementation complexity changes meaningfully, one sentence suffices; otherwise record the analysis in Design Decisions.

For affected computational/resource costs, derive typical- and worst-case time and space from operations, input sizes, allocation scope, and material I/O. Support the typical workload with evidence, or label it unknown and give conditional estimates; report an unbounded worst case and do not invent workload limits. Analytical estimates need no code. When practical limits need validation, use measurements, query plans, or targeted experiments, naming their workload and environment and whether they reproduce production selection such as query plans cached across inputs. Big-O does not establish latency or bytes, and a benchmark does not prove a worst-case bound. Justified measurement gaps may remain Open Risks with verification TCs; missing requirements return to the ambiguity gate.

State cost criteria as the bound itself; for data access, name what limits the examined range and how work scales with it. A proxy such as an index name or plan shape qualifies only if it cannot pass while the bound is violated or fail while it holds; otherwise verify the bound directly and record the establishing evidence, such as index scan ranges. Before using a relative criterion ("no regression", "same plan"), check the baseline against the bound: a violating baseline is not a success reference. Report it and, unless the Goal already requires the fix, resolve its scope through the ambiguity gate.

Assess abstraction, dependency, state, and coordination complexity separately from runtime cost. When cost threatens required limits or complexity outweighs its benefit, warn with cause and consequence, compare a simpler viable alternative's costs and maintenance tradeoffs, and recommend one, or explain why none preserves the requirements. Record the selected approach and rationale; changes to agreed behavior follow [approval.md](approval.md).

For each decision that materially adds abstraction, dependency, state, or coordination, record a necessity check; a decision an AC directly requires needs only `required by AC-n`. The check names:

- **Residual failure:** the failure reachable without the decision, its consequence, and what limits its frequency or impact.
- **Cost:** the ACs, TCs, Open Risks, and failure modes that exist only because of the decision.
- **Narrower variant:** whether one, such as a shorter timeout, bounds that failure.

Keep the decision only when its residual failure outweighs its cost and no narrower variant suffices. Evaluate removals one at a time and recheck the remaining decisions after each, because overlapping safeguards each look unnecessary while the other remains. If a removal leaves a dropped stated item's outcome uncovered, return that item to the ambiguity gate. When review findings repeatedly trace to one decision, recheck its necessity before repairing it again.

## PR slicing

Slice each plan by behavior and dependencies after [scope separation](#split-scope-before-splitting-work); scope separation implies neither one PR per scope nor a BE-to-FE branch chain. Plan prerequisites are not Git parents.

Use one branch when the change is small enough to review as a coherent unit. When review would require reasoning about several separable changes at once, use `Type: chain` with a focused review purpose for each slice. Assess review burden from distinct behaviors, affected contracts, and migration risks; line count alone is insufficient. Each slice must be correct and safe to merge after its recorded parent without later slices, but need not deliver the complete user-facing outcome. Keep incomplete behavior unexposed and preserve compatibility between slices. Plan reverts in reverse dependency order, accounting for persistent state where affected. If a large change cannot be split safely, record the coupling that requires it to stay together.

Every row records its explicit Parent and owned steps. Row 1's Parent is Base, or the unmerged branch this work extends; later rows normally parent on the previous slice's branch. Assign each TC to one slice that includes its tests and the implementation needed to pass them without later slices; shared fixtures may be inherited from a parent. Chain order is dependency order, PR creation order, and the intended maintainer merge order.

## Issue and completion

Link the supplied issue, including a shared parent issue, or create one from the Goal and scope. Verify a named issue matches the work and is open. Preserve sibling goals in shared issues; update only this goal's information. Record `Issue: #N` before handoff.

Finish when the ambiguity gate is satisfied and the Goal is covered by decidable ACs, meaningful TCs with concrete fixtures and expected results, ordered steps, and valid PR slices. Save the planning artifact and hand it to [review-feature.md](review-feature.md).
