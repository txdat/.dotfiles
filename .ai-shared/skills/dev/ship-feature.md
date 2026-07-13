# /ship-feature — Gated Delivery Router

Flow: explore → design-feature → review-feature → spec approval → execute-feature → review-code → create-pr. Read project AI config. `$ARGUMENTS`: `<requirement> [from <phase>]`.

## Route

Use an explicit `from` phase or the active plan's live state:

| Status | Next |
|---|---|
| no plan | explore, then design-feature |
| `planning` | review-feature after Open Questions are empty |
| `planning`, review returned READY | `approval.md` spec pause |
| `approved` / `in-progress` | execute-feature |
| `implemented` | review-code |
| `reviewed` | create-pr |
| `archived` | STOP — already shipped |

Once a plan exists, pass its explicit path to every downstream phase. A phase is complete only when its owner passes its self-check.

## Approval

Read and follow `approval.md` (single source). ship-feature runs its pause; it never adds an exception to it.

## Rework

A contradiction or blocking plan defect found during execution or review returns the plan to `planning`, through review-feature, and back to the approval pause. Cosmetic observations do not.

## Self-Check (BLOCKING)

- [ ] **Route:** live status and the explicit plan path select the correct next phase.
- [ ] **Approval:** `Status: approved` came from an explicit human answer at `approval.md`'s pause, never from me; re-planning got fresh review and a fresh pause.
- [ ] **Completion:** each owning phase completed before advancing; shipping ends only with PR URL(s) and `archived` status.
