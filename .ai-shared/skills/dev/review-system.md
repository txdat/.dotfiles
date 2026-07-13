# /review-system — Architecture Review

Resolve the `draft` document from `$ARGUMENTS` or latest `docs/architecture/`; read it, relevant source, and project AI config. Independently challenge the decision, not field presence. Review the chain: goal and constraints → options → recommendation → contracts → reversible phases → measured outcome.

## Review

- **Outcome:** the user goal is preserved; pain, constraints, boundaries, target, and baseline or measurement phase are credible.
- **Options:** viable alternatives were compared, or hard constraints genuinely eliminate them; trade-offs, dependencies, coupling, and critical failure handling are credible. Re-attempt the simpler-option counterexample.
- **Recommendation:** evidence supports the choice; alternatives are represented fairly; contracts cover the relevant ownership, compatibility, delivery, and failure semantics without prescribing unnecessary internals.
- **Migration:** phases are dependency-ordered and independently deployable; every Change/Verify/Rollback gate is workable; destructive steps, synchronization, reconciliation, and cutover are handled honestly.
- **Handoff:** decomposition is acyclic and initially actionable; every contract has an owning plan and phase; observable contract behavior reaches AC/TC proof while feature Goals remain user outcomes.

Blocking examples: lost user goal, unmeasurable success, no baseline or measurement phase, decorative alternatives, ignored simpler option, undefined or ownerless contract, missing critical failure handling, unverifiable phase, dishonest rollback, unowned contract, or dependency cycle. Warnings: oversized phase without a checkpoint, unfamiliar technology, or operational burden without an owner.

## Self-Check (BLOCKING)

- [ ] **Outcome/options:** goal and measurable outcome hold; alternatives or eliminations were independently challenged. Issues: __.
- [ ] **Contracts/failures:** boundaries and required semantics are sufficient; critical failures have detection and recovery. Missing: __.
- [ ] **Migration:** Change/Verify/Rollback gates are credible; destructive steps and applicable cutover/reconciliation hold. Issues: __.
- [ ] **Handoff:** plan graph is actionable; contract↔plan↔phase ownership is complete; AC/TC mapping preserves feature Goals. Issues: __.

Report verdict, blocking findings with required revisions, warnings, strengths, and author questions.

Any blocking finding → `NEEDS REVISION`; leave `Status: draft` and name the required revisions. Otherwise report `READY`, show the recommendation, decisive trade-offs, phases, and plan decomposition, then ask: **`Approve this architecture? Reply "approve", or name what to revise.`** Pause. Only explicit approval sets `Status: approved`; revisions return through design-system and review-system. Any later semantic change returns the document to `draft` and requires fresh review and approval.
