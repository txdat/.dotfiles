# /review-feature — Review a Plan

Read [plan.md](plan.md), [design-feature.md](design-feature.md), and [independence.md](independence.md). Design and the references it applies own the ambiguity gate, schema, scope and evidence criteria, and complexity rules; this review applies them independently. Entry and exit remain `planning`; only the user sets `approved`.

Verify the plan against code at its `Snapshot:` commit in every round; the [gate](../../bin/gate-check) blocks review without a valid one. Code changes after the Snapshot are not findings, because execution rechecks preconditions. When the plan advances its Snapshot, recheck what the changes between the two commits affect. Apply [design-feature.md — Stable references](design-feature.md#stable-references) to every section of the plan, without checking the values of facts it excludes: report an incidental one for removal as a non-blocking note, and require conversion to a precondition for one the design depends on.

When scopes split across plans or the plan has an `After:` line, also apply [related plans](reference/related-plans.md). When the invocation names several plans, such as an ordered split linked by `After:` (not a `Type: chain` PR Pattern), follow [Chain review](#chain-review).

## Chain review

Collect every `docs/plans/<file>.md` path in the user's message and the invocation, including `@`-mentions and paths in pasted tables or lists; never list or glob `docs/plans/` to fill gaps. Name them all in one invocation; the [gate](../../bin/gate-check) checks each and reports the first that fails. Name only plans in `planning`. A predecessor past `planning`, or published, is read through `After:`; one still in `planning` must be named, and the gate blocks a plan whose predecessor is not.

Order the plans by `After:`, producer first. Before reviewing, stop on a cycle, two plans after the same plan, or an order that conflicts with one the message states: report it with the plans involved and no verdicts. Plans that no `After:` links are reviewed independently.

One reviewer reviews the whole chain under [independence.md — Reviewer](independence.md#reviewer). It reviews each plan in chain order and in full under the steps below, with its own findings and verdict, applying [related plans — Review](reference/related-plans.md#review) to each later plan.

Then combine the verdicts along each `After:` chain:

- A plan is `READY` only if every named predecessor is `READY`. Otherwise its verdict is `NEEDS CHANGES`, with the predecessor it waits on as a blocking finding beside its own findings.
- `NEEDS SPLIT` on a plan gives every later plan `NEEDS SPLIT` too, naming that plan, and returns them to [frame-goal.md](frame-goal.md) together. Report findings already produced for the later plans; plans outside that chain keep their own verdicts.
- A repair to an earlier plan reopens later plans under [plan.md — Changes](plan.md#changes). One [re-review](independence.md#re-review) round covers it and every plan it reopened.

Report one verdict line per plan in chain order, then each plan's findings.

## Review in order

1. **Derive independently.** Before reading the proposed decisions, ACs, and TCs, derive required outcomes, prohibited outcomes, failure conditions, and ambiguous terms from the Goal, request, and source contracts, reducing each proposed fix that is not an explicit constraint to the outcome it protects. Then sketch the simplest design that meets them, reusing existing code that implements the same concepts.
2. **Check goal boundaries.** Apply [design-feature.md — PR slicing](design-feature.md#pr-slicing)'s bundled-goal check to your derivation and the plan. If it finds a boundary without a recorded user decision to keep the goal whole, report `NEEDS SPLIT` with the proposed goals and the ACs each owns, and stop: the plan returns to [frame-goal.md](frame-goal.md), where the user decides the split.
3. **Verify resolution and ACs.** Compare your derivation with the ACs. Could all ACs pass while the Goal fails, or reject valid behavior? Report missing, unsupported, or conflicting obligations, including mechanism constraints without a requirement source and stated items dropped or narrowed without a recorded user decision and covering obligation. A plan without parked questions has not thereby resolved them. For an unresolved interpretation, show a concrete scenario and its differing consequences; return it to the ambiguity gate rather than inventing a user decision. Every design choice in the decisions, ACs, TCs, and steps must trace to a DD; an untraced one, including a mechanism a step adopts implicitly, blocks and returns to the ambiguity gate with its options. Do not accept a choice on the user's behalf or relitigate a DD; verify the plan applies it consistently.
4. **Verify fixtures and coverage.** Check `Proves:` against each TC's actual purpose, resolve every fixture reference and override, and derive expected results from the contract, including permitted variability. Challenge fixtures with plausible incorrect behavior. Flag unsupported obligations, unreachable fixtures, and redundant cases.
5. **Inspect delivery.** Derive dependency order from affected contracts and invariants, then compare it with the steps. Check TC-to-step mapping, step preconditions (each holds at the Snapshot once earlier steps apply or is established by the earlier plan named in `After:`, sits on the first step that relies on it, and has a Check that fails when the fact is false), [dependent impacts](../../CODING.md#impact), mechanism invariants, and non-functional commitments. PR slices are the user's choice and are not reviewed.
6. **Check complexity.** Verify the impact assessment; a supported one-sentence no-impact explanation suffices. Otherwise apply [complexity analysis](reference/complexity.md#review) against your step-1 sketch. Where the plan reimplements a concept your sketch reuses, or extends shared code to serve a different concept, apply the [reuse rule](design-feature.md#complexity-and-simpler-alternatives).

Round 1 applies every step to the whole plan in depth. A re-review follows [independence.md — Re-review](independence.md#re-review); its scope includes any Snapshot advance.

A proposed missing scenario needs the Goal or contract obligation it protects, evidence that it is reachable or required, the concrete violation existing TCs would miss, and a distinguishing fixture with expected result. For an incomplete TC, name the missing fact and why it prevents deciding correctness; do not invent the semantics. Redundant TCs call for consolidation, not a blocked verdict. Review TC intent, fixture sufficiency, and expected results here; [review-code.md](review-code.md) verifies executable tests.

The [refund example](reference/design-feature-examples.md#example-partial-refunds) illustrates coverage of balance behavior; its counterexample does not establish readiness of a complete refund plan.

## Verdict

Report `READY` only when the ambiguity gate is satisfied, the Goal is covered, every required scenario has a TC with a sufficient concrete fixture, specified action, and correct expected result, and the plan meets every mandatory rule of design-feature and the references it applies, other than the PR slices the user chooses; `NEEDS SPLIT` under step 2; otherwise `NEEDS CHANGES`. A violated mandatory rule blocks. Optional simplifications, preferences, hardening, redundant TCs, incidental volatile facts, and justified measurement gaps with verification TCs do not.

Classify each finding by whether the plan or execution must catch it. A defect in the contract or design blocks: a missing, conflicting, or undecidable obligation, a fixture that cannot reach its action, an invalid precondition, or a plausible incorrect implementation that every TC would accept. An implementation detail that could go wrong but would fail an existing TC during test-first execution is an execution risk: report it as non-blocking with the TC that catches it.

A required correction that drops or narrows a stated item returns to the [ambiguity gate](design-feature.md#resolve-ambiguity-before-writing) for the user's decision. Except after `NEEDS SPLIT`, complete every review step after the first blocking finding and report all findings in one round, so the author can repair them as one batch. Give located findings, consequences, and required corrections. READY ends the review; the user approves by setting `Status: approved`.
