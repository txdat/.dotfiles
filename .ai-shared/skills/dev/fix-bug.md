# /fix-bug — Diagnose, Propose, Route

Diagnose a bug read-only, propose a fix, and route it. This skill edits nothing.

Establish expected behavior, actual behavior, reproduction, and any tracking issue. For a comparison base without a plan, use [dev-utils.sh](../../bin/dev-utils.sh) `diagnostic-base`. Rank plausible causes and test the strongest with focused read-only evidence. If causality stays uncertain, run the next discriminating read-only check, or name it and the access it needs. Propose no root-cause fix until the mechanism is supported; ongoing impact may justify a labeled containment step such as a rollback or flag-off.

## Proposal

- **Fix options:** one to three, ranked by correctness (removes the root cause, leaves no way back in), then blast radius, rollout risk, and effort. Each names where it changes and why it ranks there; the first is the recommendation. Label mitigations as such.
- **Regression test:** a scenario that fails before the fix and passes after, and its test level.
- **Sibling defects:** other paths with the same faulty pattern. Fix them only when the request covers them.
- **Remediation:** data, state, or user impact the fix will not repair, such as a backfill or cache purge. Live operations go in a separate [design-infra.md](design-infra.md) runbook.
- **Route:** direct edit for a contained change; plan-backed when the fix crosses modules or contracts or carries rollout risk.

With ongoing impact, containment comes first; remediation follows whatever stops new damage.

## Route

Without a fix request, end with the proposal and the decision needed. The user's request decides the route: an approved fix plan goes to [execute-feature.md](execute-feature.md); a requested plan-backed fix starts [design-feature.md](design-feature.md) with `Type: fix`; any other fix is a direct edit under [AGENTS.md — Work](../../AGENTS.md#work), with its regression test, using the option the user confirms. Ask first when the user named no option, or when the request leaves the route open and the proposal recommends plan-backed.
