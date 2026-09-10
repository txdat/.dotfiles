# Approval and Changes

Owns consent, amendments, deviations, scope decisions, and abandonment. Plan identity and lifecycle follow [plan.md](plan.md).

## Approve

After feature review reports READY, present the Goal, complete AC/TC text including fixtures, actions, and expected results, PR slices, and material risks. Include referenced shared fixtures once with their TC-specific overrides so the approval does not omit required data. Ask for approval of that concrete spec or the items to revise. Record explicit acceptance and set `Status: approved`. Acceptance of the same reviewed spec in native plan mode counts; preserve it on resume. A general instruction given before the spec was presented does not approve its details.

Architecture approval follows a READY system review: present the recommendation, tradeoffs, migration, and decomposition. Explicit acceptance sets that document to `approved`; each resulting application plan still needs its own spec approval.

## Changes

- **Editorial:** meaning and verification obligations are unchanged. Correct the text and record the correction in `## Review History`; retain approval. Missing or stale review evidence returns a reviewed plan to `implemented` until verified and reviewed again.
- **Deviation:** implementation means change while approved behavior and scope remain intact. Record `Plan said / Doing instead / Why / Tradeoff` in `## Deviations`. Proceed with routine changes; obtain a decision for material dependency, cost, security, data-integrity, external-effect, or reversibility changes.
- **Semantic amendment:** an outcome, scenario, constraint, or verification obligation changes. Set the plan to `planning`, record affected IDs and why, revise, and repeat feature review and approval for the affected spec and dependencies. Architecture amendments similarly return to `draft` for review and approval.
- **New scope:** record the work in `## Discovered Scope` and ask whether to include, separate, or skip it before implementing it.

Fixture changes follow the same classification: changing an approved scenario's meaning, distinguishing conditions, expected result, or verification obligation is a semantic amendment. Equivalent setup refactoring or incidental identifier changes that preserve those properties are routine implementation changes. Repairing a test to match its approved fixture or expectation does not itself require spec reapproval. Check every referencing TC when a shared fixture changes.

Investigate uncertain equivalence before classifying a change. If intended behavior remains ambiguous, stop affected work and use [design-feature.md — Resolve ambiguity before writing](design-feature.md#resolve-ambiguity-before-writing) before revising the spec. Preserve unaffected commits and evidence. After reapproval, replace invalidated proof through [verification.md — Test-first proof](verification.md#test-first-proof), rerun affected checks, and review against the current spec. Do not reset history to conceal earlier work.

## Abandon

Only explicit user direction abandons a plan. If it has a worktree, apply [plan.md — Worktree operations](plan.md#worktree-operations)'s removal checks; report refusal rather than force removal. Preserve branches with unpublished work unless their deletion is explicitly authorized. After successful removal (or when no worktree exists), set `Status: abandoned`, clear `Worktree:`, and record the reason in the retained root plan.

For a shared issue, mark only this goal's checklist item completed and annotate it `abandoned`, so deferred-goal tracking remains accurate. Terminal handling follows [plan.md](plan.md).
