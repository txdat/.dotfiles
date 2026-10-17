# Related Plans

Load when a goal changes more than one of the API contract, backend, and frontend, or when a plan has an `After:` line. [design-feature.md](../design-feature.md) applies it while designing; [review-feature.md](../review-feature.md) applies it independently.

## Split scope

- **API contract** owns shared boundary semantics: relevant requests, responses, errors, authorization obligations, data meaning, compatibility, and contract examples/fixtures. It includes producer behavior a consumer replicates locally, such as offline application or optimistic updates of producer mutations. Identify the authoritative contract artifact and how it will be validated.
- **BE** owns server implementation, persistence, side effects, and verification of conformance to the contract.
- **FE** owns client integration, user interactions and states, and verification of conformance to the same contract.

When BE and FE both change, give each its own plan with `be` and `fe` slug suffixes; sections or PR slices inside one plan do not satisfy this separation. A changed contract belongs to the plan that implements its producer, normally BE: define it there in Design Decisions or a referenced contract artifact, prove it through that plan's ACs/TCs, and ship artifact changes in the slice that implements them. A contract change with no implementing code is documentation under [PROCESS.md — Scope](../../../PROCESS.md#scope).

## Order

Plans of one goal are ordered, producer first. Design a later plan against the earlier plan's spec, approved or still in `planning`, assuming the earlier plans are implemented as specified. Plans still in `planning` together are reviewed as a [chain](../review-feature.md#chain-review); later phases can run over the chain too ([chain runs](#chain-runs)). Record the immediately earlier plan as `After: docs/plans/<file>.md` below the Status line, before the first section. A plan enters execute-feature, review-code, or create-pr only after its predecessor is past that phase or published; a [chain run](#chain-runs) runs the predecessor first. A shared issue connects them; no umbrella plan.

A plan cites no other plan's IDs. Restate each fact an earlier plan establishes, such as a contract shape or a behavior, as a `PC-n` precondition under the first step that relies on it, and derive fixtures from the restated contract rather than referencing them.

A later plan is a separate process that builds on the earlier plan's code, not its merge: PR-1's Parent is the earlier plan's last slice branch, or Base if that plan merged before this one is designed. Once the earlier plan is published and cleaned up, that branch may exist only as `origin/<Parent>`. Publication keeps the recorded Parent; retargeting after merges is the maintainer's. A precondition Check fails at the Snapshot only while that branch lacks the code; [execute-feature.md](../execute-feature.md) runs each Check before its step, and a failure follows [plan.md — Changes](../plan.md#changes).

Each plan owns integration verification for the behavior it delivers on top of the earlier plans: its integration TCs exercise the earlier plans' real code with concrete prerequisite state and expected results. Contract-based mocks do not prove integration.

## Review

Each plan has its own review and approval. Review checks each precondition an earlier plan establishes against that plan's approved spec, or its current spec when both are in one chain review, and, when its code exists, against the Parent branch. A revision of an earlier plan that falsifies a later plan's precondition reopens the later plan under [plan.md — Changes](../plan.md#changes).

## Chain runs

[execute-feature](../execute-feature.md#chain-execution), [review-code](../review-code.md#chain-code-review), and [create-pr](../create-pr.md#chain-publication) can each run over several plans of one `After:` chain in one invocation. This is unrelated to a `Type: chain` PR Pattern. Name every plan in the invocation as for a [chain review](../review-feature.md#chain-review); never list or glob `docs/plans/` to fill gaps.

The named plans must form one linear chain: each plan's `After:` names the plan before it, no two plans name the same one, and no plan between them is left out. The first plan's own predecessor must already be past the phase under [Order](#order). Every named plan must be at the phase's entry status or past it, and no plan may be past an earlier one. The [gate](../../../bin/gate-check) checks all of this and each plan's entry conditions, and names the plan that fails.

Run the phase on each plan in chain order, producer first, applying the skill's rules to it in full; a plan past the phase is skipped. The gate runs once, when the invocation starts, and earlier plans change later plans' state as the run proceeds, so recheck each plan's entry conditions before starting it. A plan that stops under [plan.md — Changes](../plan.md#changes) or fails its phase stops the chain there: report what completed, the plan that stopped and why, and the plans not started. Resume with the same invocation. Leave out plans that publication deleted.
