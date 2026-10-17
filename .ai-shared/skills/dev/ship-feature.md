# /ship-feature — Delivery Router

Read [PROCESS.md](../../PROCESS.md). Start from the supplied requirement or resolve the exact plan under [plan.md](plan.md). Use framing or exploration when needed. ship-feature routes one plan; to run a phase over a whole `After:` chain, invoke that phase on the chain directly ([chain runs](reference/related-plans.md#chain-runs)).

| Live status | Next action |
|---|---|
| No plan | design-feature |
| planning | Resolve requirements and run review-feature on the plan and every predecessor in its `After:` chain still in `planning` ([chain review](review-feature.md#chain-review)); on READY, stop until the user sets `approved` |
| planning, with a bundled goal from design or `NEEDS SPLIT` from review | frame-goal; then design-feature for a narrowed plan, or review-feature if the user keeps the goal whole |
| approved | execute-feature |
| implemented | review-code |
| reviewed | create-pr |
| Tracked in the main root | Stop: delivery has ended; report the published record |

Pass the exact plan path to each phase and verify its completion conditions before advancing. State transitions and the end of delivery belong to [plan.md — Lifecycle](plan.md#lifecycle); required phases belong to [PROCESS.md — Delivery](../../PROCESS.md#delivery). An explicit starting phase cannot bypass prerequisites.

Handle corrections and re-review under [plan.md — Changes](plan.md#changes) and [independence.md](independence.md). For split requirements, deliver one confirmed goal at a time; deferred goals remain in the parent issue.
