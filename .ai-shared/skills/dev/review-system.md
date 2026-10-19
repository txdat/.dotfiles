# /review-system — Review an Architecture Design

Review a `draft` architecture document independently under [plan.md — Review](plan.md#review), against [design-system.md](design-system.md).

Check the recommendation against the Goal and constraints, simpler viable alternatives, the actual boundary contracts, and failure and compatibility risks. Check that migration gates and rollbacks are executable. Trace every changed `CT-n` to a `DC-n` entry with an owning future plan, an observable obligation, and a verification route; producer and consumer responsibilities must agree, without dependency cycles or speculative work. Missing ownership or unverifiable obligations block; application plans need not exist yet.

Report located findings with consequences, and `READY` or `NEEDS CHANGES`. The user approves a READY document by setting `Status: approved`.
