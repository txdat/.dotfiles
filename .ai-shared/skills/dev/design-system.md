# /design-system — Architecture Design

Use only when work creates or changes a system boundary, communication pattern, service decomposition, or cross-system integration; feature-local design belongs to design-feature. No code. Write `docs/architecture/<date>_<slug>.md` after reading project AI config. Heavy analysis may be delegated to `architecture-strategist`; the main agent owns the document and the later human decision.

Architecture is not proved by up-front BDD/TDD. Its falsifiable chain is **goal and constraints → options → recommendation → boundary contracts → reversible phases → measured outcome**. Feature plans then prove observable behavior through Goal → AC → TC → RED → GREEN → BLUE.

## Design Schema

### 1. Frame

Clarify the user outcome, current pain, constraints, scale, team capacity, affected boundaries, current integration, and measurable success. Up to three rounds.

```text
# Architecture: <name>
Status: draft | Date: <date>
Current: <flow> | Pain: <issue → impact>
Constraints: <constraint — why>
Contexts: <affected boundaries and integration>
Success: <metric target> | Baseline: <current measurement, or unavailable — first measurement phase>
```

Success must be measurable after the final phase. If no baseline exists, the first phase establishes it; subjective goals such as “cleaner” or “more scalable” need an observable measure.

### 2. Compare viable options

Compare 2–3 viable options when they exist. If hard constraints leave one, show which alternatives they eliminate instead of inventing decorative choices. For each viable option, cover complexity, migration, operations, team fit, rollback, coupling, dependencies, and critical failure → detection → recovery paths. For the recommendation, attempt the counterexample: *could a simpler option meet the same goal and constraints?*

### 3. Recommend

Recommend one option with rationale tied to the goal, constraints, and evidence. State trade-offs and rejection reasons. Define each changed boundary contract as `<producer> → <consumer>: <event/call> — invariant`; include ownership, compatibility/versioning, timeout or delivery semantics, and failure handling when relevant. Record `no boundary changes` when true. Do not ask for approval here: review-system independently challenges the draft before the human decides.

### 4. Migrate safely

Define dependency-ordered, independently deployable phases. Each phase is a falsifiable gate:

```text
Phase <n>: <deliverable> (~duration)
Change:   <what becomes true>
Verify:   <objective pass/fail check — metric, query, probe, or test>
Rollback: <concrete restoration steps, or not applicable — reason>
```

State dual-run/synchronization, cutover trigger, and reconciliation when applicable. A destructive or irreversible step requires explicit containment and recovery; never label it rollbackable when it is not.

### 5. Decompose

List feature plans by name, owning phase, dependencies, delivered outcome, and assigned contracts. No cycles; at least one plan must be initially actionable. Do not create plan files here: design-feature creates each plan when its dependencies permit.

**BDD handoff:** every changed contract is assigned to a plan and cited there as a source, constraint, or invariant. Its observable behavior must be covered by an AC and TC; internal topology is not itself an AC. Each plan preserves its user Goal and cites this document and phase in Context. A contract no plan owns is unimplemented; a plan no phase needs is scope creep. After the final phase ships, measure Success against the baseline and record the result.

## Self-Check (BLOCKING)

- [ ] **Outcome:** goal, pain, success, baseline or measurement phase, constraints, and boundaries are concrete.
- [ ] **Options:** viable choices or constraint-based eliminations are honest; trade-offs and critical failures are covered; the simpler-option counterexample was attempted.
- [ ] **Recommendation/contracts:** rationale follows evidence; costs are explicit; relevant ownership, compatibility, delivery, and failure semantics are defined.
- [ ] **Migration:** phases are ordered and independently deployable; each has Change/Verify/Rollback; destructive steps, cutover, synchronization, and reconciliation are handled where relevant.
- [ ] **Handoff:** decomposition is acyclic and actionable; every contract has a plan, every plan has a phase, and observable contract behavior is assigned to AC/TC proof without replacing the plan Goal.

All checked → save and emit: `Run the review-system skill.`
