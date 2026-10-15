# Complexity and Simpler Alternatives

Load when a design meaningfully changes computational/resource cost or adds abstraction, dependency, state, or coordination. [design-feature.md](../design-feature.md) applies it while designing and records the analysis in Design Decisions; [review-feature.md](../review-feature.md) applies it independently.

## Cost

For affected computational/resource costs, derive typical- and worst-case time and space from operations, input sizes, allocation scope, and material I/O. Support the typical workload with evidence, or label it unknown and give conditional estimates; report an unbounded worst case and do not invent workload limits. Analytical estimates need no code. When practical limits need validation, use measurements, query plans, or targeted experiments, naming their workload and environment and whether they reproduce production selection such as query plans cached across inputs. Big-O does not establish latency or bytes, and a benchmark does not prove a worst-case bound. Justified measurement gaps may remain Open Risks with verification TCs; missing requirements return to the [ambiguity gate](../design-feature.md#resolve-ambiguity-before-writing).

State cost criteria as the bound itself; for data access, name what limits the examined range and how work scales with it. A proxy such as an index name or plan shape qualifies only if it cannot pass while the bound is violated or fail while it holds; otherwise verify the bound directly and record the establishing evidence, such as index scan ranges. Before using a relative criterion ("no regression", "same plan"), check the baseline against the bound: a violating baseline is not a success reference. Report it and, unless the Goal already requires the fix, resolve its scope through the ambiguity gate.

## Structure

Assess abstraction, dependency, state, and coordination complexity separately from runtime cost. When cost threatens required limits or complexity outweighs its benefit, warn with cause and consequence, compare a simpler viable alternative's costs and maintenance tradeoffs, and recommend one, or explain why none preserves the requirements. Record the selected approach and rationale; changes to agreed behavior follow [approval.md](../approval.md).

### Necessity check

For each decision that materially adds abstraction, dependency, state, or coordination, record a necessity check; a decision an AC directly requires needs only `required by AC-n`. The check names:

- **Residual failure:** the failure reachable without the decision, its consequence, and what limits its frequency or impact.
- **Cost:** the ACs, TCs, Open Risks, and failure modes that exist only because of the decision.
- **Narrower variant:** whether one, such as a shorter timeout, bounds that failure.

Keep the decision only when its residual failure outweighs its cost and no narrower variant suffices. Evaluate removals one at a time and recheck the remaining decisions after each, because overlapping safeguards each look unnecessary while the other remains. If a removal leaves a dropped stated item's outcome uncovered, return that item to the ambiguity gate. When review findings repeatedly trace to one decision, recheck its necessity before repairing it again.

## Review

Derive your own typical/worst-case estimates where costs change, and challenge each proxy check with a violating result it would accept and a compliant alternative it would reject. Compare the design with your independent sketch: each decision the sketch omits needs a necessity check naming a reachable failure the sketch would suffer. A narrower variant shown to meet the same ACs at lower cost blocks until the plan adopts it or records why it does not suffice.
