# /fix-bug — Diagnose, Propose, Route

Diagnose a bug from runtime evidence, propose a fix, and route it. Diagnosis makes no lasting change: it writes only in its scratch and under `/tmp`.

Establish expected behavior, actual behavior, and any tracking issue. For a comparison base without a plan, use [dev-utils.sh](../../bin/dev-utils.sh) `diagnostic-base`.

## Reproduce

Reproduce the bug where it was reported — test, CLI, API, or UI — before ranking causes. If it does not reproduce, build the trigger, narrow the conditions, or add logging until it does; ask the user only for a surface you cannot reach. If it never reproduces, say so: later claims are unconfirmed.

Write the reproduction test and any logging in [dev-worktree.sh](../../bin/dev-worktree.sh) `scratch bug-<slug> <ref>` at the reported commit or the diagnostic base, or, for a bug in uncommitted tracked changes, at `HEAD`, run from the worktree holding the changes (the main root or a plan's worktree), with `git diff --binary HEAD` saved under `/tmp` as the patch; run `isolate-dep` before changing a dependency. Throwaway scripts go under `/tmp`. Run a command that would write to a shared environment or data only when the user allows, naming the access it needs. When diagnosis ends, keep the test as `scratch-diff <scratch> -- <test path>`, then run `scratch-remove <scratch>`.

## Diagnose

Rank plausible causes and test the strongest with focused runtime evidence. If causality stays uncertain, run the next discriminating check, or name it and the access it needs. Propose no root-cause fix until the mechanism is supported; ongoing impact may justify a labeled containment step such as a rollback or flag-off.

## Proposal

- **Fix options:** one to three, ranked by correctness (removes the root cause, leaves no way back in), then blast radius, rollout risk, and effort. Each names where it changes and why it ranks there; the first is the recommendation. Label mitigations as such.
- **Regression test:** the reproduction as a test, with its level, its `scratch-diff` patch, and its failing output; below the reported surface it must still exercise the failure.
- **Sibling defects:** other paths with the same faulty pattern. Fix them only when the request covers them.
- **Remediation:** data, state, or user impact the fix will not repair, such as a backfill or cache purge. Live operations go in a separate [design-infra.md](design-infra.md) runbook.
- **Route:** direct edit for a contained change; plan-backed when the fix crosses modules or contracts or carries rollout risk.

With ongoing impact, containment comes first; remediation follows whatever stops new damage.

## Route

Without a fix request, end with the proposal and the decision needed. The user's request decides the route: an approved fix plan goes to [execute-feature.md](execute-feature.md); a requested plan-backed fix starts [design-feature.md](design-feature.md) with `Type: fix`; any other fix is a direct edit under [AGENTS.md — Work](../../AGENTS.md#work), using the option the user confirms. A direct fix applies the regression test from its patch, shows it failing then passing, and reruns the original reproduction on the same surface; one it cannot reach is reported as unrun. Ask first when the user named no option, or when the request leaves the route open and the proposal recommends plan-backed.
