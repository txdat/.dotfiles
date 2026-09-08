# /design-system — Architecture Design

Use for changed service boundaries, communication patterns, or cross-system integrations. Ordinary application features belong in [design-feature.md](design-feature.md). Read [PROCESS.md](../../PROCESS.md), project context, and [CODING.md — Impact](../../CODING.md#impact).

Write `docs/architecture/<date>_<slug>.md` with `Status: draft`. Include:

- **Goal and constraints:** current pain, affected boundaries, measurable success, and baseline or a phase to establish it.
- **Options and recommendation:** compare viable choices against the same constraints, including a simpler starting system. Justify complexity with current needs and explain material tradeoffs.
- **Contracts:** ownership, data/call flow, compatibility, and relevant delivery/failure semantics using [PROCESS.md — Repository conventions](../../PROCESS.md#repository-conventions). Account for actual consumer dependencies.
- **Migration, when needed:** ordered phases with concrete change, verification gate, rollback and its limits. Include synchronization, cutover, and reconciliation where relevant; identify irreversible steps honestly.
- **Decomposition:** assign every changed contract to a named future application plan, with dependencies and delivered outcomes. For each, record the contract/invariant that will become an AC source, the observable obligation, and the scenario or verification route its TCs must cover. Include both producers and consumers where the contract crosses plans. A single plan needs only one entry; actual AC/TC IDs are assigned during application design after architecture approval.

Finish when the recommendation meets the stated constraints, contracts have owners, and migration/decomposition can deliver the measured outcome. Hand off to [review-system.md](review-system.md). Create feature plans only after [approval.md](approval.md)'s architecture decision, then assess the final outcome against the baseline.
