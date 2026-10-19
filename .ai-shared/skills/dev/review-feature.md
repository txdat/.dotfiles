# /review-feature — Try to Break the Plan

Review a `planning` plan independently under [plan.md — Review](plan.md#review), against the rules in [design-feature.md](design-feature.md). The goal is to find what would make a correct-looking plan deliver the wrong thing.

## 1. Derive first

Before reading the plan's decisions, ACs, and TCs, derive from the Goal, the request, and the source contracts: the required outcomes, prohibited outcomes, failure conditions, and ambiguous terms. Reduce any proposed fix that is not a stated constraint to the outcome it protects. Sketch the simplest design that meets them, reusing existing code for the same concepts.

## 2. Check the plan

- **Obligations.** Compare your derivation with the ACs. Could every AC pass while the Goal fails, or would an AC reject valid behavior? Report missing, unsupported, or conflicting obligations, and requested items dropped or narrowed without a DD. For an unresolved interpretation, show a concrete scenario where the readings differ; it goes back to the user, never to your own guess.
- **Decisions.** A choice that belongs to the user under [design-feature.md — Brief](design-feature.md#2-brief-the-user) without a DD blocks. Never relitigate a DD; check that the plan applies it consistently.
- **Tests.** Resolve each fixture, derive its expected result from the contract yourself, and check that `Proves:` matches the TC's real purpose. Challenge the set with plausible wrong implementations. To propose a missing scenario, name the obligation it protects, why it is reachable, the wrong behavior current TCs would accept, and a distinguishing fixture with its expected result. Redundant TCs call for consolidation, not a block.
- **Delivery.** Check step order against the contracts and invariants, step-to-TC mapping, and impacts under [CODING.md — Impact](../../CODING.md#impact). Each PC meets design-feature's PC rules (sections 3 and 6); run its Check yourself. For a stacked plan, check its contract PCs against the specs below it, and that it changes no file that a plan neither below nor above it changes. PR slices are the user's choice; do not review them.
- **Simplicity.** Compare with your sketch. A decision your sketch omits must name a reachable failure it prevents. A narrower variant that meets the same ACs blocks until the plan adopts it or records why it falls short. A reimplemented concept or shared code bent with flags is a finding.

## 3. Classify and report

A finding blocks when the defect is in the contract or design: a missing, conflicting, or undecidable obligation, a fixture that cannot reach its action, an invalid PC, an untraced user decision, or a wrong implementation that every TC accepts. An implementation mistake that an existing TC would catch during test-first execution is a non-blocking risk; name that TC. Optional hardening and redundant TCs never block.

Complete every check and report all findings in one round, each with location, consequence, and required correction. Verdict: `READY` when nothing blocks, otherwise `NEEDS CHANGES`. READY ends the review.
