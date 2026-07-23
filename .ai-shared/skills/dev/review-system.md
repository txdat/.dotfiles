# /review-system — Architecture Review

Resolve the `draft` document from `$ARGUMENTS` or latest `docs/architecture/`; read it, relevant source, project AI config, and the configs that invoke and host the system — scheduler cadence and jitter, retry and delivery semantics, concurrency, IAM — which are design surface, not deployment detail. Independently challenge the decision, not field presence. Review the chain: goal and constraints → options → recommendation → contracts → reversible phases → measured outcome.

## Independence

If this session drafted the document, delegate the review to one fresh `architecture-strategist` with no conversation inheritance (EXECUTION_CORE `Subagent context`): the packet names only the document path, project AI config, and this skill file — never drafting rationale or a conversation summary. The reviewer applies this file, not design-system.md, judges the document as written rather than redrafting it, and spawns nothing. It returns verdict, findings, and author questions; the approval prompt, its pause, and any `Status` change stay with the main agent. A session that did not draft reviews directly. Isolation unavailable → treat drafting memory as untrusted and re-derive every judgment from the document and source. A revision authored in-session is unreviewed text: re-review it as adversarially as the original, or delegate. After piecewise edits, re-read the whole document — a lexical consistency check catches stale identifiers, not a contradiction between two sections.

## Review

- **Outcome:** the user goal is preserved; pain, constraints, boundaries, target, and baseline or measurement phase are credible. Attack every success metric: name a change that hits the target without moving the outcome — if one exists the metric is gameable and needs a paired outcome guard or a second measurement.
- **Options:** viable alternatives were compared, or hard constraints genuinely eliminate them; trade-offs, dependencies, coupling, and critical failure handling are credible. Re-attempt the simpler-option counterexample.
- **Recommendation:** evidence supports the choice; alternatives are represented fairly; contracts cover the relevant ownership, compatibility, delivery, and failure semantics without prescribing unnecessary internals. Any contract that adds a constant, heuristic, or state store to compensate for absent data → prove the data is absent first: check the API's actual response and the codebase's own declared-but-unpopulated fields.
- **Migration:** phases are dependency-ordered and independently deployable; every Change/Verify/Rollback gate is workable; destructive steps, synchronization, reconciliation, and cutover are handled honestly.
- **Handoff:** decomposition is acyclic and initially actionable; every contract has an owning plan and phase; observable contract behavior reaches AC/TC proof while feature Goals remain user outcomes. For each contract, name the production entry point its AC/TC invokes — a proof that joins below the behavior it governs proves nothing; trace the real path (stub → adapter → parser → detector → ledger) to find where the test enters.

Blocking examples: lost user goal, unmeasurable or gameable success metric, no baseline or measurement phase, decorative alternatives, ignored simpler option, mechanism invented for data never confirmed absent, undefined or ownerless contract, missing critical failure handling, proof joining below the behavior it governs, unverifiable phase, dishonest rollback, or dependency cycle. Warnings: oversized phase without a checkpoint, unfamiliar technology, or operational burden without an owner.

## Self-Check (BLOCKING)

- [ ] **Independence:** the review ran in a context without drafting memory (fresh agent, or a session that did not draft); fallback in-session review re-derived every judgment from the document and source. Context: __.
- [ ] **Outcome/options:** goal and measurable outcome hold; each metric was attacked for gameability and every proxy is paired with an outcome guard; alternatives or eliminations were independently challenged. Issues: __.
- [ ] **Contracts/failures:** boundaries and required semantics are sufficient; critical failures have detection and recovery. Missing: __.
- [ ] **Migration:** Change/Verify/Rollback gates are credible; destructive steps and applicable cutover/reconciliation hold. Issues: __.
- [ ] **Handoff:** plan graph is actionable; contract↔plan↔phase ownership is complete; every contract's AC/TC is traced to the production entry point it invokes and none joins below the behavior it governs; AC/TC mapping preserves feature Goals. Issues: __.

Report verdict, blocking findings with required revisions, warnings, strengths, and author questions.

Any blocking finding → `NEEDS REVISION`; leave `Status: draft` and name the required revisions. Otherwise report `READY`, show the recommendation, decisive trade-offs, phases, and plan decomposition, then ask: **`Approve this architecture? Reply "approve", or name what to revise.`** Pause. Only explicit approval sets `Status: approved`; revisions return through design-system and review-system. Any later semantic change returns the document to `draft` and requires fresh review and approval.
