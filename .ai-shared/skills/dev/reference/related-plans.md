# Related Plans

Load when a goal changes more than one of the API contract, backend, and frontend, or when a plan has `## Related Plans`. [design-feature.md](../design-feature.md) applies it while designing; [review-feature.md](../review-feature.md) applies it independently.

## Split scope

- **API contract** owns shared boundary semantics: relevant requests, responses, errors, authorization obligations, data meaning, compatibility, and contract examples/fixtures. It includes producer behavior a consumer replicates locally, such as offline application or optimistic updates of producer mutations. Identify the authoritative contract artifact and how it will be validated.
- **BE** owns server implementation, persistence, side effects, and verification of conformance to the contract.
- **FE** owns client integration, user interactions and states, and verification of conformance to the same contract.

When BE and FE both change, give each its own plan with `be` and `fe` slug suffixes; sections or PR slices inside one plan do not satisfy this separation. A changed contract belongs to the plan that implements its producer, normally BE: define it there in Design Decisions or a referenced contract artifact, prove it through that plan's ACs/TCs, and ship artifact changes in the slice that implements them. A contract change with no implementing code is documentation under [PROCESS.md — Scope](../../../PROCESS.md#scope). Design and review the contract first; the consumer plan derives from its reviewed revision and may not silently redefine it. Contract changes reopen affected consumer decisions under [approval.md](../approval.md).

In `## Related Plans`, record the overall outcome, exact sibling paths, the contract source and revision, and dependency conditions. Use path-qualified IDs for cross-plan references and reference authoritative semantics and fixtures instead of copying them. A consumer that replicates producer behavior proves parity against the producer's contract fixtures. A shared issue can connect the plans; an executable umbrella plan is unnecessary.

Assign cross-scope integration verification to an explicit owning plan and TC with concrete prerequisite state and expected results; contract-based mocks may unblock FE work but do not prove integration with BE. Each plan keeps its own review and approval.

## Dependencies

Record development, merge, and release dependencies where they differ. A step precondition whose fact a sibling plan establishes names that plan and the condition that establishes it, such as a merged slice or a reviewed contract revision, in `## Related Plans`. Its Check may fail at the Snapshot; design and review confirm that the sibling's reviewed revision establishes the fact, and [execute-feature.md](../execute-feature.md) runs the Check before the step as usual.

## Review the set

Review the contract-owning plan first, then each consumer against its exact reviewed contract revision; recheck consumers when the contract changes. Check that the plans together cover the overall outcome with no missing responsibility, conflicting ownership, circular prerequisite, or unowned integration verification.

Report a verdict per exact plan path plus a coherence conclusion for the set. A contract-owning plan can be READY before its consumers exist; missing required consumer plans or integration ownership blocks readiness of the set, not of that plan.
