# /review-feature — Review a Feature Plan

No code and no approval decisions. Design remains open: independently challenge the WHAT and HOW rather than ratifying fields. Resolve the active plan per CORE; entry status is `planning`. `gate-check` blocks entry on unresolved Open Questions; the Goal/AC/TC/Step graph is yours to verify, not a parser's.

## Independence

If this session drafted the plan, do not review it here: delegate to one fresh agent with no conversation inheritance (EXECUTION_CORE `Subagent context`). The packet names only the plan path, project AI config, and this skill file — never drafting rationale, exploration notes, or a conversation summary. The reviewer reports findings, counterexamples, and READY/NEEDS CHANGES; the main agent relays them verbatim, and plan edits or status changes stay with the main agent. A session that did not draft the plan reviews directly. Isolation unavailable → review in-session, treating memory of the drafting as untrusted: re-derive every judgment from the plan file and source reads.

## Independent Semantic Review

Avoid anchoring on the proposed tests:

1. Read `## Goal`, relevant user/domain sources, and existing contracts first.
2. Before inspecting proposed TCs, independently list the observable outcomes and failure conditions required by the Goal.
3. Compare that list with the proposed ACs. Identify missing, invented, ambiguous, mechanism-coupled, or conflicting criteria.
4. Only then inspect TCs and search adversarially for counterexamples.

Challenge every AC/TC graph with:

- Can every TC pass while its AC fails?
- Can every AC pass while the original Goal fails?
- What invalid implementation could satisfy the proposed Then assertions?
- What valid implementation would the tests incorrectly reject?
- Is each expected result sourced, or merely repeated from the planner's assumption?
- Are relevant negative, boundary, failure, retry, concurrency, security, and partial-result cases represented?
- Does any test assert a proposed mechanism instead of observable behavior?

Undefined or unsupported expected behavior is blocking and becomes an Open Question for the user. Use concrete competing examples when asking; never silently choose a product/domain outcome.

## System and Execution Review

- **Approach:** simplest correct solution; alternatives and assumptions challenged.
- **System fit:** components, contracts, boundaries, compatibility, blast radius, rollback, and dependency/deployment order inspected.
- **Completeness:** error/failure modes, concurrency, scale, security, observability, edge cases, and Non-functional mappings.
- **Traceability:** every Goal outcome has an AC; every AC has ≥1 TC; every TC has exactly one `Proves: AC-N` and an explicit step reference; every step names ≥1 TC. Nothing mechanical checks this — read it.
- **Execution:** ordered steps; PR slices partition steps, follow dependencies, are independently mergeable, and never split a TC.
- **Altitude:** the plan is language-neutral design notation throughout — contracts (signatures, endpoint shapes, schemas) declared as notation, never in target-language syntax; no function bodies or procedural code; pseudo-code only where the structure is itself the decision; quoted existing source is citation, not a violation. Target-language text or embedded implementation is blocking: it anchors the executor and substitutes detail for behavior.
- **TDD:** feature/fix scenarios fail first for absent/wrong behavior; refactor scenarios pin passing behavior; assertions do not mirror implementation.
- **Conditional rigor:** new structures have invariants, guards, and boundary TCs; non-trivial behavior-axis combinations are covered or excluded with reason.

## Readiness

`READY` means the behavior is ready for the human's decision, not approved. Leave `Status: planning` — review never approves. The spec pause in `approval.md` follows, driven by ship-feature or by the user directly.

## Self-Check (BLOCKING)

- [ ] **Independence:** the review ran in a context without drafting memory (fresh agent, or a session that did not draft); fallback in-session review re-derived every judgment from the plan file and source. Context: __.
- [ ] **Mode/questions:** eligibility or full schema verified; no Open Questions surfaced. Issues: __.
- [ ] **Independent outcomes:** expected outcomes were derived from Goal/sources before TC inspection; missing/invented ACs resolved. Issues: __.
- [ ] **Adversarial behavior:** every AC/TC faced counterexample, invalid-pass, and valid-rejection challenges; failure/edge axes are sufficient. Gaps: __.
- [ ] **Approach/system fit:** alternatives, boundaries, compatibility, order, blast radius, rollback, and Non-functional effects are sound. Issues: __.
- [ ] **Traceability/TDD:** Goal → AC ↔ TC ↔ Step graph, fail/pass intent, meaningful observable assertions, and affected tests hold. Gaps: __.
- [ ] **Execution shape:** steps are dependency-ordered, ≤10, and each names its TC; the PR partition is independently mergeable and splits no TC; the plan stays at design altitude — language-neutral notation only, no target-language syntax or implementation bodies. Issues: __.

Report summary, independently derived outcomes, blocking findings, counterexamples attempted, suggestions, and `READY` or `NEEDS CHANGES`.

`NEEDS CHANGES`: offer plan fixes and wait; design rethink routes to design-feature. `READY`: leave the status unchanged and print: `Plan READY. Run approval.md's spec pause — approval is the user's, not mine.`
