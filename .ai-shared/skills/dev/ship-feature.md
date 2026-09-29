# /ship-feature — Delivery Router

Read [PROCESS.md](../../PROCESS.md). Start from the supplied requirement or resolve the exact plan under [plan.md](plan.md). Use framing or exploration when needed.

| Live status | Next action |
|---|---|
| No plan | design-feature |
| planning | Resolve requirements, review-feature, then approval.md |
| approved / in-progress | execute-feature |
| implemented | review-code |
| reviewed | create-pr |
| published / abandoned | Stop: delivery has ended; report the recorded state |

Pass the exact plan path to each phase and verify its completion conditions before advancing. State transitions and terminal handling belong to [plan.md — Lifecycle](plan.md#lifecycle); required phases belong to [PROCESS.md — Delivery](../../PROCESS.md#delivery). An explicit starting phase cannot bypass prerequisites.

Handle corrections and re-review under [approval.md](approval.md) and [independence.md](independence.md). For split requirements, deliver one confirmed goal at a time; deferred goals remain in the parent issue.
