# /design-system — Architecture Design

Use for changed service boundaries, communication patterns, or cross-system integrations; ordinary features use [design-feature.md](design-feature.md). Assess impact under [CODING.md — Impact](../../CODING.md#impact).

Write `docs/architecture/<date>_<slug>.md` with `Status: draft`, in the language [plan.md — Artifact](plan.md#artifact) prescribes, with these sections:

- **`## Goal and Constraints`:** current pain, affected boundaries, and each measurable success criterion as `SC-n`, with its baseline or the `PH-n` that establishes it.
- **`## Options`:** each viable choice as `OP-n`, compared against the same constraints, including a simpler starting system. Cite the recommended one and justify its complexity by current needs.
- **`## Contracts`:** each changed contract as `CT-n`: owner, data and call flow, compatibility, delivery and failure semantics. Account for actual consumers.
- **`## Migration`** (when needed): ordered `### PH-n — <outcome>` phases, each with its change, verification gate, rollback and its limits. Cover synchronization, cutover, and reconciliation where relevant; mark irreversible steps.
- **`## Decomposition`:** `DC-n — <future plan> — CT-n — <obligation>` entries assigning every changed contract to a future application plan, with the observable obligation and how its TCs will verify it. Where a contract crosses plans, list the producer plan first; the consumer stacks on it.

Declare each ID at the start of a line in its section, outside code fences; cite another artifact's ID as `<path>#ID`.

Finish when the recommendation meets the constraints, every contract has an owner, and migration and decomposition can deliver the measured outcome. Hand off to [review-system.md](review-system.md). Feature plans start only after the user sets `Status: approved`. An approved document is frozen: a needed change goes to the user with options and a recommendation, then back to `draft`, review, and approval.
