# /design-feature — Plan Application Work

Read [PROCESS.md](../../PROCESS.md) and [plan.md](plan.md). Design proposes behavior; [approval.md](approval.md) owns approval. Use [frame-goal.md](frame-goal.md) for material ambiguity or bundled goals, [design-system.md](design-system.md) for changed system boundaries, and [frontend-design.md](frontend-design.md) for UI work.

Inspect the relevant code, contracts, and project conventions. Confirm a concrete base branch and record the inspected commit's SHA as `Snapshot:` ([Stable references](#stable-references)); the commit must be on Base or, when the plan extends an unmerged branch, on PR-1's Parent. Complete the ambiguity gate below before drafting or creating a new `docs/plans/<area>_<date>_<type>_<slug>.md`, where area is a short label grouping related plans (repository, module, or issue number) and type is `feature`, `fix`, or `refactor`.

Before drafting, select the plan language under [language.md](language.md). Every ID in the plan follows [ids.md](ids.md), and the IDs close as the [ID graph](#id-graph) requires.

## Resolve ambiguity before writing

Resolve ambiguities that materially affect the requested outcome, an affected contract, or the chosen design before writing the plan. Establish **why each factor exists, what problem it resolves, and how it is obtained or derived**. Identify the source and meaning of requirements, domain terms, values, and proposed mechanisms; define data meaning, derivation, and edge cases that meet [Scope and evidence](#scope-and-evidence). For example, “rank by percentage” must define both the entity being ranked and the percentage's numerator and denominator. Treat a fix or mechanism the issue or request proposes as a hypothesis unless the user states it as an explicit constraint: reduce it to the outcome it protects and design only for the part no other obligation already delivers. Before dropping or narrowing a stated item, stop and obtain the user's decision; record it in `## Design Decisions` with the obligation that covers the item's outcome.

Resolve questions from the user's existing answers, authoritative contracts, and inspected evidence first. Existing code establishes current behavior, not necessarily intended behavior. Resolve routine technical choices within those constraints using project conventions and engineering judgment. If intended behavior or scope still admits competing interpretations, present a concrete scenario and their differing consequences and obtain the missing decision from the user; do not silently select product semantics. Investigation and candidate AC/fixture sketches may proceed in clarification notes; the plan must not be drafted around unresolved assumptions or TBDs. Implementation details that do not change the agreed contract or design may remain for execution.

Carry resolved behavioral semantics into the ACs. Record decision rationale, sources, and derivations as `DD-n` entries in `## Design Decisions` where needed, citing those IDs from ACs/TCs instead of duplicating them. If ambiguity emerges while drafting or reviewing, stop dependent plan work, resolve it, then revise the affected ACs, fixtures, TCs, and steps. Verification uncertainty may remain as an Open Risk only when intended behavior and its expected result are already settled.

## Split scope before splitting work

Separate the goal into API-contract, backend (BE/server), and frontend (FE/client) responsibilities before slicing work. Include only affected scopes; reference unchanged contracts. When more than one scope changes, apply [related plans](reference/related-plans.md): BE and FE changes get separate plans, a changed contract belongs to its producer's plan, and integration verification has an explicit owner.

## Plan schema

```text
# Task: <name>
Status: planning | Type: feature|fix|refactor | Base: <branch> | Snapshot: <inspected commit SHA> | Issue: #N | Worktree:
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
ST-1 — <change and files/symbols> — satisfies TC-1
  PC-1 — <current-code fact the step relies on, if any> — Check: <search, inspection, or command that fails when the fact is false>
## PR Pattern (provisional)
Type: single
| PR | Branch | Parent | Steps | Summary |
|---|---|---|---|---|
| PR-1 | feat/example | <base> | ST-1 | <outcome> |
```

A chain lists one row per slice:

```text
## PR Pattern (provisional)
Type: chain
| PR | Branch | Parent | Steps | Summary |
|---|---|---|---|---|
| PR-1 | feat/example-1 | <base> | ST-1 | <outcome> |
| PR-2 | feat/example-2 | feat/example-1 | ST-2 | <outcome> |
```

Each TC includes a concrete fixture, action, and expected result. Shared fixtures may live in `## Test Fixtures` as `FX-n`; each TC names its fixture (`Fixture: FX-1 with <overrides>`) and states its own expected result. Fixtures are language-neutral example data, not executable setup code. Item counts follow the behavior the Goal requires; there are no quotas.

Fixtures specify enough relevant data and state to derive the expected result without inventing semantics during execution; large or generated datasets may use a precise construction rule. Use exact values for deterministic results; for permitted variability, define the allowed set, tolerance, invariant, or measurable bound from the contract.

Add only useful sections: `## Context`, `## Design Decisions`, `## Test Fixtures`, `## Affected Existing Tests` (how to find affected tests and the expected effect on them, not a list), or `## Open Risks`. The plan has no Assumptions or Open Questions section, and the gate rejects one: route questions that materially affect the requested outcome, an affected contract, or the chosen design through the ambiguity gate, and raise optional follow-up questions with the user outside the plan. Open Risks (`RK-n`) are verification uncertainties assigned to existing TCs, not permission to change behavior.

Later phases add `## Review History`, `## Deviations`, `## Discovered Scope`, and `## Coverage Gaps` when needed, with the IDs [ids.md](ids.md) assigns them. Execution fills each TC's `Test:` line and records its proof and results beneath it; review finalizes the PR Pattern.

Use [PROCESS.md — Repository conventions](../../PROCESS.md#repository-conventions) for design notation and [CODING.md — Impact](../../CODING.md#impact) for affected contracts and shared state. When an AC or decision imposes a rule on a class of entities or states, the impact includes every site that writes or reads that class: find them by search and make that search the `Check:` of a precondition, so a site added later fails it. Investigate the rationale before removing an existing guard or observable behavior. Record material compatibility risks and required decisions.

### ID graph

The plan's IDs must close; the [gate](../../bin/gate-check) checks this at review-feature and review-code:

- At least one AC, TC, ST, and PR exists, and the PR Pattern table has a `Steps` column.
- Every AC is named by some TC's `Proves:`.
- Every TC has exactly one `Proves:` line naming exactly one AC, and is cited by an ST.
- Every ST cites at least one TC and appears in exactly one PR row's `Steps` cell; other cells, such as Summary, do not assign ownership.
- Every FX is used by some TC.

Closure is shape, not correctness: whether each edge is right remains review judgment.

### Stable references

The plan must stay valid while other work merges into Base. Reference code by path and symbol, and describe required behavior, contracts, and decisions. Do not state facts that unrelated merges can falsify: line numbers; counts of lines, files, messages, fields, callers, or tests; exhaustive claims such as "the only caller" or "no other usages"; current configuration or constant values; and behavior of code the plan does not change.

When a decision, AC, TC, or step depends on such a fact, record it as a `PC-n` precondition under the first step that relies on it, one fact per line, with a `Check:` that fails when the fact is false. A precondition describes the code that step starts from, after earlier steps and parent slices apply; a fact a sibling plan establishes follows [related plans — dependencies](reference/related-plans.md#dependencies). This includes quoted source, impact evidence under [CODING.md — Impact](../../CODING.md#impact), and the facts behind decisions, such as why existing code cannot be reused or why a guard can be removed; the decision and its rationale stay in Design Decisions. Preconditions are design dependencies, not Open Risks.

Before every handoff to review, including after repairs, sweep every section of the plan for facts this section excludes; a revision can add new ones. For each, ask whether any decision, AC, TC, or step would change if it were false: if none would, delete it or restate it as required behavior; otherwise make it a precondition. Run each Check at the Snapshot. A Check may fail there only when an earlier step, a parent slice, or a declared sibling plan establishes its fact; confirm that the producer does. Any other failing Check means the fact or the design is wrong; correct the plan before handoff.

`Snapshot:` fixes the code that review verifies against. Advance it only when revising the plan against newer code. Changes after the Snapshot are caught by [execute-feature.md](execute-feature.md), which runs each precondition check before its step.

## Derive and challenge the spec

### Scope and evidence

Derive ACs from the Goal, explicit constraints, and affected contracts. Derive TCs to prove those obligations under realistic conditions. An edge or failure case belongs when an explicit requirement demands it or a reachable input, state, or failure in the supported workflow could violate an obligation. Ground reachability in inspected validation, data constraints, callers, dependency behavior, or the proposed design; a prior incident is not required. For non-obvious cases, briefly name that basis and the consequence beside the TC or in Design Decisions; a basis in current code is a step precondition under [Stable references](#stable-references).

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

Scale analysis to impact. When neither computational/resource cost nor implementation complexity changes meaningfully, one sentence suffices; otherwise apply [complexity analysis](reference/complexity.md), including a necessity check for each decision that materially adds abstraction, dependency, state, or coordination, and record it in Design Decisions.

Minimize implementation logic under [CODING.md — Changes and evidence](../../CODING.md#changes-and-evidence). Reuse existing code that implements the same concept (the same data meaning and contract, not merely similar steps), and name it in the implementation steps, or record in Design Decisions why it cannot serve; extending it makes its callers affected under [CODING.md — Impact](../../CODING.md#impact). Do not bend shared code with flags to serve a different concept; write separate code instead. Handle cases through one path when the contract treats them alike, and include only parameters, options, and special cases that an AC or reachable scenario requires. When the change supersedes existing code, name what it deletes or consolidates.

## PR slicing

Slice each plan by behavior and dependencies after [scope separation](#split-scope-before-splitting-work); scope separation implies neither one PR per scope nor a BE-to-FE branch chain. Plan prerequisites are not Git parents.

Use one branch when the change is small enough to review as a coherent unit. When review would require reasoning about several separable changes at once, use `Type: chain` with a focused review purpose for each slice. Assess review burden from distinct behaviors, affected contracts, and migration risks; line count alone is insufficient. Each slice must be correct and safe to merge after its recorded parent without later slices, but need not deliver the complete user-facing outcome. Keep incomplete behavior unexposed and preserve compatibility between slices. Plan reverts in reverse dependency order, accounting for persistent state where affected. If a large change cannot be split safely, record the coupling that requires it to stay together.

Every `PR-n` row records its explicit Parent and owned `ST-n` steps; each step belongs to exactly one row. PR-1's Parent is Base, or the unmerged branch this work extends; later rows normally parent on the previous slice's branch. Assign each TC to one slice that includes its tests and the implementation needed to pass them without later slices; shared fixtures may be inherited from a parent. Chain order is dependency order, PR creation order, and the intended maintainer merge order.

Slices divide review of one goal, not several goals. Before handoff, check for a bundled goal: a subset of ACs whose outcome is useful and acceptable without the rest under [frame-goal.md](frame-goal.md), even when it shares a layer, files, or a prerequisite with them. AC, TC, step, and Design Decision groups that reference none of each other are the usual signal; size alone is not. Return such a plan to frame-goal with the proposed boundary, unless `## Design Decisions` records the user's decision to keep it whole.

## Issue and completion

Link the supplied issue, including a shared parent issue, or create one from the Goal and scope. Verify a named issue matches the work and is open. Preserve sibling goals in shared issues; update only this goal's information. Record `Issue: #N` before handoff.

Finish when the ambiguity gate is satisfied and the Goal is covered by decidable ACs, meaningful TCs with concrete fixtures and expected results, ordered steps, and valid PR slices. Save the planning artifact, complete the [Stable references](#stable-references) sweep, and hand it to [review-feature.md](review-feature.md).
