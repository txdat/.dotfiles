# /review-feature — Review Feature Plan

Do NOT write code.

**Owns:** the WHAT and HOW. Design is still OPEN here — this is the last gate to change direction. Step back to the system level; do not just validate the document's fields.

Resolve the session's active plan: an explicit `docs/plans/<file>.md` (or its slug) in $ARGUMENTS pins it; otherwise the session's pinned plan, else the lone active plan. Never auto-pick among multiple active plans — 0 or 2+ and none named → STOP, ask which. Expects status `planning`/`blocked-by-architecture`. If unfamiliar areas, suggest the explore skill. If the active plan is already `approved`, STOP and run execute-feature.

Read plan + project config file (CLAUDE.md/CODEX.md/GEMINI.md/AGENTS.md).

## Precondition (blocking)

`## Assumptions & Open Questions` → Open Questions MUST be empty. Any unresolved → STOP, verdict NEEDS CHANGES, route back to design-feature. Never review an under-specified plan.

## Systemic Review

Step back from the document to the system:

- **Approach**: is this the simplest correct solution? Are the Design Decisions' alternatives credible, or does a better one exist? Challenge the choice — don't ratify it.
- **System fit**: read the plan's `## Context` and Affected Components to ground this — interactions with existing components, shared contracts, and boundaries; backward compatibility; cross-service deployment & migration ordering (PR Pattern must honor `## Context` Dependencies); blast radius; rollback. If `blocked-by-architecture`, read its source `docs/architecture/` doc and verify the plan honors that doc's `Contracts:` — violation → `❌`.
- **Completeness**: missing error modes, concurrency, scale, security, observability, edge cases.
- **Assumptions**: challenge each in `## Assumptions & Open Questions`; an unsound assumption → `❌`.

## Structural Review

- **Requirement**: clear, measurable done
- **Scope**: in/out explicit
- **Non-functional**: `### Non-functional` answered; each code-requiring item maps to an Implementation Step (or marked `ops-only`). Unmapped → `❌`
- **Risks**: actionable mitigations
- **Steps**: 5–10 Implementation Steps, dependency-ordered. >10 → `❌` propose split
- **PR Pattern**: present; `Steps` partitions all Implementation Steps (each step in exactly one slice) AND no TC spans slices (every step satisfying a TC is in the same slice → each slice independently green). Gap, overlap, or TC-spanning slice → `❌` (breaks chain execution)

**Split accepted**: new files per sub-plan. If `Issue:` set, ask: "Create sub-issues?"

Flag undefined terms inline. One follow-up max.

**TDD (blocking)**:
- Test Cases non-empty and listed before Implementation Steps.
- Each TC has all four fields (Given/When/Then/Verifies) filled.
- Bidirectional refs: every Impl → ≥1 TC-N; every TC → ≥1 Impl. Orphan TC or unreferenced Impl → `❌`.
- Feature/fix: TCs describe new behavior (will fail until implemented).
- Refactor: TCs pin existing behavior (must pass before and after).

**Mechanism Invariants (blocking, conditional)**: if Impact Analysis introduces a new data structure (Data/Schema migration, or an Affected Component adds a type/collection/map/cache/index/queue/state container), `## Mechanism Invariants` MUST exist with ≥1 entry per new structure. Each entry names the init/identity guard and cites a boundary TC (drive to boundary — exhausted/zero/full/evicted — then operate on the same key, asserting no reset/re-init/corruption). Missing section, missing structure, unnamed guard, or no boundary TC → `❌`. Don't just confirm the fields are filled — judge whether the stated invariant is the *right* one and whether the TC actually violates-then-preserves it.

**Cross-dimension coverage (blocking)**: when the plan spans N orthogonal axes (e.g. role × resource-type, limit-reached × fallback-path), the combination matrix must be covered — ≥1 TC per non-trivial cross-product, or the combo listed in `## Out of Scope` with a reason. Uncovered, unjustified combination → `❌`.

## Self-Check (BLOCKING — do NOT emit verdict until every item is ✅)

Run this audit before the final output. If ANY blocking item is unchecked → verdict is NEEDS CHANGES.

- [ ] **Open Questions gate** (`## Precondition`): Open Questions empty. Count: __.
- [ ] **Approach** (Systemic Review): simplest correct solution? alternatives credible? Better one: yes/no (__).
- [ ] **System fit** (Systemic Review): components/contracts/boundaries; deployment & migration order vs `## Context` Dependencies; `blocked-by-architecture` → honors doc `Contracts:`. Issues: __.
- [ ] **Completeness** (Systemic Review): error modes, concurrency, scale, security, observability, edge cases. Gaps: __.
- [ ] **Assumptions challenged** (Systemic Review): each assumption validated. Unsound: __.
- [ ] **Non-functional mapping** (Structural Review): each code-requiring item maps to an Impl Step (or `ops-only`). Unmapped: __.
- [ ] **TDD — TCs complete** (TDD): non-empty, before Impl Steps, each with Given/When/Then/Verifies. Orphans: __.
- [ ] **TDD — Bidirectional refs** (TDD): every Impl → ≥1 TC; every TC → ≥1 Impl. Orphan TCs: __ / Impls: __.
- [ ] **TDD — Correct mode** (TDD): feature/fix TCs fail-first; refactor TCs pass before + after.
- [ ] **Mechanism Invariants** (conditional, that gate): new data structure → ≥1 entry per structure, init/identity guard + boundary TC; judge the invariant is the *right* one. Missing: __.
- [ ] **Cross-dimension coverage** (conditional, that gate): N orthogonal axes → ≥1 TC per non-trivial cross-product, or combo in `## Out of Scope`. Uncovered: __.
- [ ] **PR Pattern** (Structural Review): present; partitions all Impl Steps; no TC spans slices. Gaps/overlaps: __.
- [ ] **Steps count** (Structural Review): 5–10 Impl Steps; >10 → split proposed. Count: __.

If ANY ❌ → verdict NEEDS CHANGES. If all ✅ → verdict READY.

## Output

```
## Plan Review Report
### Summary
(2–3 sentences: approach soundness, system risk, verdict rationale)
### ❌ Blocking (N)
- <section> — issue — why it breaks
### ⚠️ Suggestions (N)
- <section> — improvement
### Verdict: READY | NEEDS CHANGES — `<path>`
```

- **NEEDS CHANGES** (any ❌): offer to apply blocking fixes to the plan (wait for approval); design-level rethink → route back to design-feature. Status unchanged until cleared.
- **READY**: ask "Apply suggestions?"; on apply or skip → **leave the status unchanged** (`planning`/`blocked-by-architecture`). Do NOT set `approved` — approval is the human's manual action (the sole exception is ship-feature, which approves itself). Print: "Plan READY — approve it manually (set `Status: approved` in the plan), then run the execute-feature skill."
