# /review-feature — Review a Plan

Read [plan.md](plan.md), [design-feature.md](design-feature.md)'s schema and slicing rules, and [independence.md](independence.md). Entry is `planning` with no unresolved requirements.

## Review in order

1. **Derive independently.** Read the Goal, request, and source contracts before the proposed ACs and TCs. Identify required outcomes, prohibited outcomes, and failure conditions from that evidence.
2. **Compare ACs.** Check that every required outcome is represented and Success/Failure is decidable. Could all ACs pass while the Goal fails? Could an invalid implementation satisfy an AC as written, or would it reject valid behavior? Report missing, unsupported, or conflicting obligations, including mechanism constraints without a requirement source. An unresolved user decision is a question, not a value for the reviewer to invent.
3. **Inspect scenarios and delivery.** Trace every distinct AC obligation to a TC scenario that would exercise it, including side effects, boundaries, and relevant interactions. Check the named `Proves:` against the scenario's actual purpose. Apply [design-feature.md — Derive and challenge the spec](design-feature.md#derive-and-challenge-the-spec) to challenge plausible incorrect implementations. Then check steps, [dependent impacts](../../CODING.md#impact), mechanism invariants, and non-functional commitments against the scope and project conventions. Verify that slices pass and merge in their recorded order without later work.
4. **Reconcile prior findings.** After forming your own judgment, read recorded challenges and review history. Verify claimed corrections and whether recorded safeguards actually defeat the incorrect behavior; a prior verdict is not evidence that a gap is closed.

Record material counterexamples with their target and consequence, or the evidence that defeats them. No fixed attack count or repeated checklist is required. Review TC intent here; [review-code.md](review-code.md) verifies executable arrangements, production entry points, and assertions.

Report `READY` only when the Goal is covered, required scenarios and delivery obligations are accounted for, and no material requirement remains unresolved; otherwise `NEEDS CHANGES`. Give located findings, consequences, and required corrections. Optional preferences do not block. During delivery, the main agent records the verdict/evidence in `## Review History`; READY hands off to [approval.md](approval.md), never directly to implementation.
