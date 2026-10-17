# /review-system — Review Architecture

Read the exact architecture document, [design-system.md](design-system.md)'s design requirements, and [independence.md](independence.md). Entry is `draft`.

Check the recommendation against the Goal and constraints, viable simpler alternatives, actual boundary contracts, and failure/compatibility risks. Test whether migration gates and rollback are executable and whether decomposition covers every changed contract without dependency cycles or speculative work.

Trace each changed `CT-n` through [design-system.md](design-system.md)'s `DC-n` decomposition: owning future plan, source contract/invariant, observable obligation, and verification route. Check that producer/consumer responsibilities and cross-plan dependencies agree. Missing ownership or unverifiable obligations block readiness; application plans and their AC/TC IDs need not exist before architecture approval.

Report located findings with consequences and `READY` or `NEEDS CHANGES`. Optional stylistic preferences do not block. Review does not approve; the user approves a READY document by setting `Status: approved`.
