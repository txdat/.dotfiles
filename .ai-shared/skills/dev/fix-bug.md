# /fix-bug — Diagnose, Propose, and Route a Fix

Use `fix-bug <symptom>` for read-only diagnosis, a fix proposal, and routing; this skill edits nothing. A requested fix follows [Route](#route).

Read [CODING.md](../../CODING.md) and project configuration. Establish expected behavior, actual behavior, reproduction, and any tracking issue. For planless comparisons, use [PROCESS.md](../../PROCESS.md)'s diagnostic base rule.

Rank plausible causes and test the strongest with focused, read-only evidence. Report the supported failure mechanism and affected paths. If reproduction or causality remains uncertain, run the next discriminating check when it is read-only and available; otherwise name it and the access or input it needs. Propose no root-cause fix until the mechanism is supported; ongoing impact may justify proposing a labeled containment step such as a rollback or flag-off.

## Proposal

From a supported mechanism, propose:

- **Fix options**: one to three, ranked by correctness (removes the root cause, leaves no reopen path), then blast radius, rollout risk, and effort. Each names its change location and the criterion that decides its rank; the first is the recommendation. Label any mitigation per [CODING.md — Changes and evidence](../../CODING.md#changes-and-evidence).
- **Regression test**: a scenario that fails before the fix and passes after, and its test level.
- **Sibling defects**: other paths with the same faulty pattern, each marked verified or unchecked. Include them in the fix only when the request covers them.
- **Remediation**: existing data, state, or user impact the fix will not repair, such as a backfill, cache purge, or replay; otherwise none. Propose live operations as a separate [design-infra.md](design-infra.md) runbook; neither this skill nor a direct-edit fix runs them.
- **Prevention**: optional follow-up guard (validation, type, lint rule, alert) only if it would have caught this class of bug.
- **Route**: direct edit for a contained change; recommend plan-backed when the fix crosses modules or contracts, or carries rollout risk.

Rank only fix options; sequence the rest. With ongoing impact, containment comes first. Remediation follows whichever step stops new damage, so repaired data is not corrupted again.

Without a fix request, end with the proposal and the decision needed.

## Route

The user's request decides the route; the proposal only recommends it. An existing approved fix plan goes to [execute-feature.md](execute-feature.md); a requested plan-backed fix starts at [design-feature.md](design-feature.md) with `Type: fix`, carrying the proposal into its design; any other fix is a direct edit under [AGENTS.md — Work](../../AGENTS.md#work) with its regression test, using the option the user confirms; unless the user already named one, present the ranked options with tradeoffs and a recommendation first. Ask first, too, when the request leaves the mode open and the proposal recommends plan-backed.
