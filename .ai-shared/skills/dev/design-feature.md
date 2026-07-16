# /design-feature — Plan a Feature, Fix, or Refactor

Warn if another plan is active; unfamiliar area → suggest explore. Read project AI config. Scope that creates or changes a system boundary, communication pattern, service decomposition, or cross-system integration belongs to design-system first. A decomposed plan cites the approved architecture document and phase in Context, preserves the user Goal, and carries assigned contracts as sources, constraints, or invariants whose observable behavior is covered by ACs and TCs. No approval decisions, and no code — neither written to the repo nor embedded in the plan (see Planning Rules).

Write `docs/plans/<basename>_<date>_<type>_<slug>.md`, where type is feature/fix/refactor.

## Plan Schema

Clarify scope, constraints, edge cases, and done in up to three rounds. Keep the plan as short as the change is small — a section with nothing to say is omitted, not padded. Application plans contain:

```text
# Task: <name>
Status: planning | Type: feature|fix|refactor | Issue: | Worktree:
## Goal                        # preserve the user's requested outcome; do not replace it with TCs
## Requirement                 # problem, why, measurable done
## Context                     # current behavior; dependencies and ordering
## Scope                       # In / Out
## Assumptions & Open Questions
## Impact Analysis
### Affected Components        # file/module/service and change
### API / Contract Changes     # breaking/additive, with details
### Data / Schema              # migration and rollback
### Non-functional             # performance budget, security, observability
## Design Decisions            # decision / options / chosen / reason
## Mechanism Invariants        # conditional; structure / invariant / guard / boundary TC
## Risk Flags                  # risk / mitigation
## Acceptance Criteria         # AC-N observable outcome + Source / Success / Failure
## Test Cases                  # TC-N scenario + Proves / Given / When / Then
## Affected Existing Tests     # test + reachability reason + still passes/needs update
## Implementation Steps        # Step N + action + explicit satisfying TC IDs
## Out of Scope                # item + reason
## PR Pattern (provisional)    # type plus branch / steps / summary table
```

Item shape:

```text
AC-1 — <one observable outcome>
  Source: <user goal quote, contract, domain rule, or specification>
  Success: <observable result>
  Failure: <result that violates this AC>

TC-1 — <one scenario>
  Proves: AC-1
  Given: <setup>
  When: <action>
  Then: <observable result>
```

Design-feature proposes behavior; it never approves it. `approval.md` (single source) owns that decision.

## Goal → AC Derivation

1. Preserve the user's original outcome in `## Goal`; separate later interpretation under Requirement/Assumptions.
2. Decompose the Goal into atomic actors, triggers, observable outcomes, constraints, prohibited outcomes, failure behavior, and measurable non-functional results.
3. Convert each atomic outcome into one implementation-independent AC. Unsupported expected behavior is an Open Question, never an invented AC.
4. Cite the source for every AC. Replace subjective terms (`fast`, `safe`, `correct`) with observable measures or ask the user.
5. Derive TCs only after the AC set is complete. Each TC has exactly one `Proves: AC-N`; an AC may own multiple positive, negative, boundary, failure, concurrency, or security scenarios.
6. Attempt the counterexample: "Can an implementation pass all proposed TCs while violating this AC or the Goal?" If yes, refine ACs/TCs before handoff.

## Planning Rules

- **A plan carries design, not implementation — everything in it is language-neutral design notation.** Contract *declarations* — a signature, an endpoint shape, a schema change, an event payload — are design: state them exactly, but as notation (`apply(tx) → receipt | reject(reason)`), never in target-language syntax. Implementation *bodies* never appear: no function bodies, no procedural code, nothing the executor would paste instead of write. Pseudo-code is allowed only when the structure is itself the decision (an algorithm, a state machine, a protocol). Quoting existing source as evidence is citation, not implementation. Target-language text in a plan anchors the executor and hides behavior gaps behind premature detail.
- Open Questions must be empty before handoff; move settled answers into assumptions or their owning section.
- Use dependency-ordered steps, as few as the change needs; >10 → split. Verify symbols named by steps against their target type/module.
- Goal → AC ↔ TC ↔ Step traceability is complete: every AC has ≥1 TC, every TC names exactly one AC and appears by ID in ≥1 step, and every step names ≥1 TC. Enumerate IDs; never write ranges such as `TC-1 through TC-4`.
- Feature/fix TCs describe initially failing observable behavior; refactor TCs pin behavior that passes before and after. Tests must not mirror the proposed implementation.
- Derive Affected Components from exploration or direct inspection. Answer every impact category; map code-requiring Non-functional commitments to steps or mark `ops-only`.
- For every affected component, external dependency, and contract, ask *what happens when this fails* — down, timeout, crash mid-operation, partial write, retry/duplicate. New or changed failure behavior → failure AC/TC; accepted risk → Risk Flag; no credible answer → Open Question. Existing handling the change doesn't touch needs no artifact.
- Find Affected Existing Tests semantically, then by targeted search. Predict `still passes` or `needs update` with reason; empty only for isolated new code.
- A new structure requires its operational invariant, initialization/identity guard, and boundary TC using the same key after zero/full/exhausted/evicted state.
- For orthogonal behavior axes, cover each non-trivial combination with a TC or justify it under Out of Scope.

## PR Pattern

Draft after the issue decision. One deployable unit → single branch `<type>/<slug>`. Otherwise chain independently mergeable slices, ordered by dependencies; migrations isolate first, shared architecture precedes behavior, and service slices include all their layers. The table partitions every step exactly once and keeps every TC wholly within one slice.

Show name, type, requirement, AC/TC/step counts, and path. Ask for design changes, then offer issue creation; declining defers but does not waive the execution gate. Never ask for spec approval here — that pause belongs to `approval.md`, after review-feature returns READY.

## Self-Check (BLOCKING)

- [ ] **Schema and questions:** every section that applies is filled; Open Questions empty; `Status: planning`.
- [ ] **Goal and ACs:** Goal is preserved; each AC is atomic, observable, sourced, pass/fail decidable, and implementation-independent; counterexample attempt found no known way to pass while violating the Goal.
- [ ] **Approach/impact:** requirement and scope are measurable; components/contracts/data/non-functional effects and decisions are concrete; every affected component, dependency, and contract has its failure behavior answered.
- [ ] **BDD/TDD:** every TC has Proves/Given/When/Then, one owning AC, and correct fail/pass intent; Goal → AC ↔ TC ↔ Step mapping is complete; affected existing tests are reasoned.
- [ ] **Conditional rigor:** each new structure has guard/invariant/boundary TC; behavior-axis combinations are covered or excluded with reason.
- [ ] **Execution shape:** steps are dependency-ordered, each names the TC it satisfies, and are ≤10 (else split); provisional PR Pattern partitions steps and does not split a TC.
- [ ] **Altitude:** the plan is language-neutral design notation throughout — contracts declared as notation, never in target-language syntax; no function bodies or procedural code; pseudo-code marks structural decisions only.

All checked → emit: `Plan drafted. Run the review-feature skill.`
