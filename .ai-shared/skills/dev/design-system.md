# /design-system — Architecture Design

Use for changed service boundaries, communication patterns, or cross-system integrations. Ordinary application features belong in [design-feature.md](design-feature.md). Read [PROCESS.md](../../PROCESS.md), project context, and [CODING.md — Impact](../../CODING.md#impact).

Before drafting, select the design language under [language.md](language.md).

Write `docs/architecture/<date>_<slug>.md` with `Status: draft`; every ID follows [ids.md](ids.md). Include:

- **Goal and constraints** (`## Goal and Constraints`): current pain, affected boundaries, and each measurable success criterion as `SC-n` with its baseline or the `PH-n` that establishes it.
- **Options and recommendation** (`## Options`): record each viable choice as `OP-n` and cite the recommended one; compare viable choices against the same constraints, including a simpler starting system. Justify complexity with current needs and explain material tradeoffs.
- **Contracts** (`## Contracts`): each changed contract as `CT-n` with ownership, data/call flow, compatibility, and relevant delivery/failure semantics using [PROCESS.md — Repository conventions](../../PROCESS.md#repository-conventions). Account for actual consumer dependencies.
- **Migration, when needed** (`## Migration`): ordered `PH-n` phases with concrete change, verification gate, rollback and its limits. Include synchronization, cutover, and reconciliation where relevant; identify irreversible steps honestly.
- **Decomposition** (`## Decomposition`): as `DC-n` entries, assign every changed `CT-n` to a named future application plan, with dependencies and delivered outcomes. For each, record the contract/invariant that will become an AC source, the observable obligation, and the scenario or verification route its TCs must cover. Include both producers and consumers where the contract crosses plans, ordered producer first to match each plan's `After:` chain. A single plan needs only one entry; actual AC/TC IDs are assigned during application design after architecture approval.

Finish when the recommendation meets the stated constraints, contracts have owners, and migration/decomposition can deliver the measured outcome. Hand off to [review-system.md](review-system.md). Create feature plans only after the user sets the document `Status: approved`, then assess the final outcome against the baseline. An approved document is not edited: a needed change goes to the user with options, tradeoffs, and one recommendation; if the user chooses to revise, set `draft`, revise, re-review, and wait for the user to set `approved`.
