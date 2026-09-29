# /review-feature — Review a Plan

Read [plan.md](plan.md), [design-feature.md](design-feature.md), and [independence.md](independence.md). Design owns the ambiguity gate, schema, scope and evidence criteria, complexity rules, and slicing rules; this review applies them independently. Entry and exit remain `planning`; [approval.md](approval.md) owns the transition to `approved`.

## Related plans

Apply [design-feature.md — Split scope](design-feature.md#split-scope-before-splitting-work). Review the contract-owning plan first, then each consumer against its exact reviewed contract revision; recheck consumers when the contract changes. Check that the plans together cover the overall outcome with no missing responsibility, conflicting ownership, circular prerequisite, or unowned integration verification.

Report a verdict per exact plan path plus a coherence conclusion for the set. A contract-owning plan can be READY before its consumers exist; missing required consumer plans or integration ownership blocks readiness of the set, not of that plan.

## Review in order

1. **Derive independently.** Before reading the proposed decisions, ACs, and TCs, derive required outcomes, prohibited outcomes, failure conditions, and ambiguous terms from the Goal, request, and source contracts.
2. **Verify resolution and ACs.** Compare your derivation with the ACs. Could all ACs pass while the Goal fails, or reject valid behavior? Report missing, unsupported, or conflicting obligations, including mechanism constraints without a requirement source. A missing Open Questions section does not prove resolution. For an unresolved interpretation, show a concrete scenario and its differing consequences; return it to the ambiguity gate rather than inventing a user decision.
3. **Verify fixtures and coverage.** Check `Proves:` against each TC's actual purpose, resolve every fixture reference and override, and derive expected results from the contract, including permitted variability. Challenge fixtures with plausible incorrect behavior. Flag unsupported obligations, unreachable fixtures, and redundant cases.
4. **Inspect delivery.** Derive dependency order and safe delivery boundaries from affected contracts and invariants, then compare them with the steps and PR slices. Check TC-to-step mapping, [dependent impacts](../../CODING.md#impact), mechanism invariants, and non-functional commitments. Check each slice boundary for intermediate compatibility, exposure of incomplete behavior, and revert safety; challenge a large single PR's coupling and name a safe split if one exists.
5. **Check complexity.** Verify the impact assessment; a supported one-sentence no-impact explanation suffices. Where costs change, derive your own typical/worst-case estimates, challenge each proxy check with a violating result it would accept and a compliant alternative it would reject, and evaluate a simpler viable alternative.
6. **Reconcile prior findings.** Only after forming your own judgment, read recorded challenges and review history. Verify claimed corrections and whether recorded safeguards defeat the incorrect behavior; a prior verdict does not close a gap.

A proposed missing scenario needs the Goal or contract obligation it protects, evidence that it is reachable or required, the concrete violation existing TCs would miss, and a distinguishing fixture with expected result. For an incomplete TC, name the missing fact and why it prevents deciding correctness; do not invent the semantics. Redundant TCs call for consolidation, not a blocked verdict. Review TC intent, fixture sufficiency, and expected results here; [review-code.md](review-code.md) verifies executable tests.

The [refund example](reference/design-feature-examples.md#example-partial-refunds) illustrates coverage of balance behavior; its counterexample does not establish readiness of a complete refund plan.

## Verdict

Report `READY` only when the ambiguity gate is satisfied, the Goal is covered, every required scenario has a TC with a sufficient concrete fixture, specified action, and correct expected result, and delivery and complexity obligations are met; otherwise `NEEDS CHANGES`. Missing complexity reasoning, unsupported feasibility claims, proxies that misjudge the bound, relative criteria on an unchecked baseline, and demonstrated limit violations block; justified measurement gaps with verification TCs and optional simplifications do not. Give located findings, consequences, and required corrections. Optional preferences and hardening do not block. During delivery, the main agent records the verdict and evidence in `## Review History`; READY hands off to [approval.md](approval.md).
