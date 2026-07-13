# Spec Approval — Single Source

Owns the human decision on *what the code should do* for application plans (`Type: feature|fix|refactor`). Read by ship-feature and review-feature; binding on every skill that touches an approved plan.

One decision, one pause. After review-feature returns `READY`:

1. Show the Goal, then every AC and TC by ID — each on its own line, full text, no summarizing. Add slice/step counts, key risks, and issue state.
2. Ask: **`Approve this spec? Reply "approve", or name the AC/TC IDs to revise or drop.`**
3. Pause. Only an explicit approval sets `Status: approved`.

A response that names IDs is a revision: apply the edit, delete a dropped item outright (git history is the audit trail — do not keep tombstones), and route back through review-feature before asking again.

Silence, a general "proceed", prior agreement on the Goal, urgency, and a bug report are **not** approvals. Neither is your own confidence. Nothing else in the flow may set `Status: approved`.

## Changing an approved spec

Any later change to the Goal, an AC, or a TC — during execution, review, or re-planning — returns `Status: approved` to `planning` and takes the plan back through review-feature and this pause. Never edit approved behavior in place.

This is not a deviation. A **deviation** is a different *means* to the same approved behavior: log it under `## Deviations` per CORE #5 and keep going. A change to the *behavior itself* comes back here. If you cannot tell which one you are looking at, it is this one.

## What is enforced, and what is not

`gate-check` blocks execution unless `Status: approved` is set. That is the whole mechanical guarantee — it cannot tell who set it. Nothing stops an agent from approving its own plan, and no parser can check that an AC is the right AC.

So the pause is the enforcement, and the judgment lives in review-feature's adversarial self-check: can a TC pass while its AC fails, can every AC pass while the Goal fails. Treat a plan that reached `approved` without a human answering the question above as unapproved, whatever the file says.
