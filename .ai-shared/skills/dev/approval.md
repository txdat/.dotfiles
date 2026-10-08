# Approval and Changes

Owns consent, amendments, deviations, scope decisions, and abandonment. Plan identity and lifecycle follow [plan.md](plan.md).

## Approve

After feature review reports READY, present the Goal, complete AC/TC text including fixtures, actions, and expected results, PR slices, and material risks. Include referenced shared fixtures once with their TC-specific overrides so the approval does not omit required data. Ask for approval of that concrete spec or the items to revise. Record explicit acceptance and set `Status: approved`. Acceptance of the same reviewed spec in native plan mode counts; preserve it on resume. A general instruction given before the spec was presented does not approve its details.

After recording `Status: approved` and before [execute-feature.md](execute-feature.md) starts, post the plan's `## Design Decisions` to its `Issue: #N` as one comment (`gh issue comment <N> --body-file <file>`), headed by the plan file stem so a shared issue stays attributable to this goal. Post at approval, not at the READY verdict: READY is not consent, and the user may revise decisions while approving. Skip the comment when the section is absent. Check the body for sensitive content first and fetch the comment afterward to verify it. When reapproval follows a semantic amendment, post a new comment that names the decisions it supersedes; do not edit earlier comments.

Architecture approval follows a READY system review: present the recommendation, tradeoffs, migration, and decomposition. Explicit acceptance sets that document to `approved`; each resulting application plan still needs its own spec approval.

## Changes

- **Editorial:** meaning and verification obligations are unchanged. Correct the text and record the correction in `## Review History`; retain spec approval and still-applicable review evidence. An editorial correction alone does not invalidate code review. If required review evidence is missing or stale, return a reviewed plan to `implemented` until verified and reviewed again; the unchanged spec remains approved.
- **Deviation:** implementation means change while approved behavior and scope remain intact. Record `Plan said / Doing instead / Why / Tradeoff` in `## Deviations`. Proceed with routine changes; obtain a decision for material dependency, cost, security, data-integrity, external-effect, or reversibility changes.
- **Semantic amendment:** an outcome, scenario, constraint, or verification obligation changes. Set the plan to `planning`, record affected IDs and why, revise, and repeat feature review and approval for the affected spec and dependencies. Architecture amendments similarly return to `draft` for review and approval.
- **PR Pattern change:** changing slice boundaries, Parents, or TC ownership while ACs, TCs, and scope stay intact is a Deviation that needs a user decision, because it changes what maintainers review and merge. Record it in `## Deviations` and re-verify the affected slices. A change that also alters an AC or TC is a semantic amendment.
- **New scope:** record the work in `## Discovered Scope` and ask whether to include, separate, or skip it before implementing it.

Fixture changes follow the same classification: changing an approved scenario's meaning, distinguishing conditions, expected result, or verification obligation is a semantic amendment. Equivalent setup refactoring or incidental identifier changes that preserve those properties are routine implementation changes. Repairing a test to match its approved fixture or expectation does not itself require spec reapproval. Check every referencing TC when a shared fixture changes.

Investigate uncertain equivalence before classifying a change. When a verification obligation fails, recheck it against its source requirement and the raw evidence, and seek a solution that meets the requirement, before proposing to relax or drop the obligation. Relaxing or dropping it is a semantic amendment, not a Deviation; correcting an obligation that wrongly rejects a compliant solution leaves the source requirement in force. If intended behavior remains ambiguous, stop affected work and use [design-feature.md — Resolve ambiguity before writing](design-feature.md#resolve-ambiguity-before-writing) before revising the spec. Preserve unaffected commits and evidence. After reapproval, replace invalidated proof through [verification.md — Test-first proof](verification.md#test-first-proof), rerun affected checks, and review against the current spec. Do not reset history to conceal earlier work.

## Abandon

Only explicit user direction abandons a plan. If it has a worktree, apply [plan.md — Worktree operations](plan.md#worktree-operations)'s removal checks; report refusal rather than force removal. Preserve branches with unpublished work unless their deletion is explicitly authorized. After successful removal (or when no worktree exists), set `Status: abandoned`, clear `Worktree:`, and record the reason in the retained root plan.

For a shared issue, mark only this goal's checklist item completed and annotate it `abandoned`, so deferred-goal tracking remains accurate. Terminal handling follows [plan.md](plan.md).
