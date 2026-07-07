# /design-feature — Feature/Fix/Refactor Planning

Warn if active plan exists. Unfamiliar area → suggest the explore skill.

Filename: `docs/plans/<basename>_<date>_<type>_<slug>.md`. Type: feature/fix/refactor.

Read project config file (CLAUDE.md/CODEX.md/GEMINI.md/AGENTS.md). Filling a `blocked-by-architecture` stub → also read its source `docs/architecture/` doc and honor its `Contracts:` boundary invariants; cite the doc in Design Decisions. No code.

## Mode

After clarify, classify the change. `Mode: lite` only when ALL hold — else `full`:

- ≤2 non-test files touched (predicted from Affected Components)
- no new data structure (type, schema/table, collection, map, cache, index, queue, state container)
- no API/contract change (breaking **or** additive) and no data/schema migration
- no security surface (authz, input validation, secrets, data exposure)

Record on the Status line. **Lite plan** keeps only: Requirement, Scope, Test Cases, Implementation Steps (1–3), PR Pattern (`Type: single` forced); Impact Analysis collapses to one line (`Impact: <files> — <why contained>`); Mechanism Invariants and Cross-dimension gates are auto-N/A (eligibility already excludes their triggers). The Open Questions gate and TDD gate apply unchanged — lite trims paperwork, never rigor.

**Escalation (any phase, one-way):** the moment any lite condition proves false — a third file, a hidden contract change, a new structure — STOP, flip `Mode: full`, backfill the full sections, re-run review-feature. Never widen a lite plan in place.

## Draft

Clarify: scope, constraints, edge cases, done. Up to 3 rounds.

```
# Task: <name>
Status: planning | Type: <type> | Mode: full|lite | Issue: | Worktree:

## Requirement
<problem and why>

## Context
Current state: <what exists today / current behavior the change builds on>
Dependencies: <external services, libs, feature flags, in-flight work — and ordering>

## Scope
In: <items>
Out: <items>

## Assumptions & Open Questions
Assumptions: <explicit assumptions the design relies on — challenged at review>
Open Questions: <unresolved unknowns — MUST be empty before handoff to review-feature>

## Impact Analysis
### Affected Components
- `<file/module/service>`: <what changes>

### API / Contract Changes
- Breaking: <yes/no — details>
- Additive: <yes/no — details>

### Data / Schema
- Migration needed: <yes/no — details>
- Rollback plan: <yes/no — details>

### Non-functional
- Performance: <impact / budget>
- Security: <authz, data exposure>
- Observability: <logs / metrics / alerts>

## Design Decisions
| Decision | Options | Chosen | Reason |

## Mechanism Invariants
<only when the change introduces a new data structure — type, schema/table, collection, map, cache, index, queue, state container>
- `<structure>`: <invariant that must hold across every operation on it — ordering, uniqueness, referential integrity, bounds/capacity, lifecycle (init/cleanup/eviction), concurrency/visibility>
  - Maintained by: <the design mechanism that preserves it — name the initialization/identity guard (how a key/slot is first created vs. matched on revisit) and its boundary behavior>
  - Verifies: TC-N

## Risk Flags
- [ ] <risk>: <mitigation>

## Test Cases
- [ ] TC-1 `<test_fn_name>`: <scenario>
  - Given: <preconditions / inputs>
  - When: <action under test>
  - Then: <expected output / behavior>
  - Verifies: <invariant from Requirement>

## Affected Existing Tests
- [ ] `<test_file>::<test_fn>`: <why this change could affect it — symbol/contract it exercises>
  - Expected: still passes (behavior preserved) | needs update (<what & why>)

## Implementation Steps
- [ ] Step 1: <what> — satisfies TC-1[, TC-2]

## Out of Scope
- <item>: <why>

## PR Pattern (provisional)
Type: single | chain
| # | Branch | Steps | Summary |
|---|--------|-------|---------|
| 1 | <type>/<slug> | 1–N | <summary> |
```

Rules: 5–10 Implementation Steps (lite: 1–3), dependency-ordered. Every Impl refs ≥1 TC-N; every TC referenced by ≥1 Impl. >10 → propose split. Symbols cited in Impl steps must be verified members of their target type/module before the step is written — see CORE `Verify symbol membership`.

**Impact Analysis:** populate Affected Components from explore Key Files/Entry Points/Data Flow if available; scan only if no explore output exists. Affected Components ≥1 entry; API/Contract Changes, Data/Schema, and Non-functional must each be answered. Each Non-functional commitment that requires code maps to an Implementation Step (mark `ops-only` if it needs none) — else execute never builds it.

**Affected Existing Tests:** derive from Affected Components — for each changed file/module/symbol, find the existing tests exercising it via explore output → LSP find-references/call-hierarchy → `rg -l '<symbol>' <test-dirs>` (semantic first, textual fallback). Each row: *why* the change reaches it + a predicted outcome — `still passes` (behavior preserved — regression guard) or `needs update` (contract intentionally changed; note how, and an Implementation Step must update it). Predictions only, no runs; execute-feature runs them and root-causes any failure. Empty only when the change is isolated new code no existing test touches; else ≥1 entry.

**Open Questions gate** (blocking): `## Assumptions & Open Questions` → Open Questions MUST be empty before handoff. Any unresolved → resolve inline within the clarify rounds, or ask the user; the draft may still be saved, but never hand off to review-feature while any remain. Settled answers move to Assumptions or fold into the relevant section.

**TDD gate** (blocking):
- Feature/fix: ≥1 TC; every TC has all four fields (Given/When/Then/Verifies); TCs describe new behavior that will initially fail.
- Refactor: TCs pin existing behavior to preserve (must pass before and after); Given/When/Then describe current behavior, Verifies cites the invariant kept intact.
- Bidirectional refs: every Impl → ≥1 TC-N; every TC → ≥1 Impl.

**Mechanism Invariants gate** (blocking, conditional): triggers whenever Impact Analysis introduces a new data structure (Data/Schema migration, or an Affected Component adding a type/collection/map/cache/index/queue/state container). For each, `## Mechanism Invariants` MUST hold ≥1 entry — a structural property the mechanism silently depends on *beyond* the Requirement's stated behavior. Each entry names its init/identity guard and cites a TC-N obeying the TDD gate. Canonical TC: drive the structure to its boundary state (exhausted / zero / full / evicted), then operate again on the *same* key, asserting it does NOT reset, re-init, or corrupt. Empty only when no new data structure is introduced.

**Cross-dimension coverage gate** (blocking): when the plan spans N orthogonal axes (e.g. role × resource-type, limit-reached × fallback-path), the combination matrix MUST be covered — ≥1 TC per non-trivial cross-product, or the combo listed in `## Out of Scope` with a reason. Uncovered, unjustified combination → gate not met.

Save. Show: name, type, requirement, counts, path.

Ask: "Changes?" then "Create issue?" → if yes, `gh issue create`, update `Issue:` field.

**PR Pattern (final step).** After the issue decision, draft the provisional `## PR Pattern` — it records slicing intent and is finalized at review-code time (scope may shift during implementation).

**Single vs. chain:** each slice must be independently mergeable without breaking the app. One deployable unit → `Type: single` (branch `<type>/<slug>`). Otherwise → `Type: chain` (branches `<type>/<slug>-k`, k = 1…N).

**Service boundary:** N independent services → one slice per service, all its layers included. Shared infrastructure → extract as a leading `arch` slice.

**Split axes** (natural boundaries):
- **migration** — DB migration scripts; always isolated (deployment-order sensitive)
- **arch** — structural code, no behaviour: DTOs, interfaces, base types, config
- **feat** — behaviour on top of arch: repositories, services, controllers
- **l10n** — string/translation-only changes
- **test** — test-only additions or refactors
- **chore** — config, deps, tooling

Enumerate every slice upfront — branch + `Steps` + one-line summary each — so the full chain is known before any PR exists. Slice order respects `## Context` Dependencies (external/in-flight work, deployment order). Each Implementation Step belongs to exactly one slice (the `Steps` columns partition all steps), AND no TC spans slices — every step satisfying a given TC sits in the same slice, so each slice's TCs pass within that slice alone. execute-feature runs each slice's RED→GREEN over those steps' TCs. Save.

## Self-Check (BLOCKING — do NOT emit completion until every item is ✅)

Run this audit before the final output. If ANY item is unchecked → STOP, fix the plan, re-check. Lite plans (`Mode: lite`): only the **Mode**, **Open Questions**, both **TDD**, and **PR Pattern** items apply.

- [ ] **Mode** (`## Mode`): all four lite conditions re-verified against the drafted plan — any false → `Mode: full` with full sections. Mode: __.
- [ ] **Open Questions** (`Open Questions gate`): `Open Questions:` empty. Count: __.
- [ ] **TDD — Test Cases** (`TDD gate`): ≥1 TC, each with all four fields filled.
- [ ] **TDD — Bidirectional refs** (`TDD gate`): every Impl → ≥1 TC; every TC → ≥1 Impl. Orphan TCs: __ / Impls: __.
- [ ] **Mechanism Invariants** (`Mechanism Invariants gate`, conditional): new data structure → ≥1 entry per structure, init/identity guard + boundary TC. N/A if none.
- [ ] **Cross-dimension coverage** (`Cross-dimension coverage gate`): every non-trivial combo of orthogonal axes has ≥1 TC or sits in `## Out of Scope`. Uncovered: __.
- [ ] **PR Pattern** (`PR Pattern (final step)`): `## PR Pattern (provisional)` present; Impl Steps partitioned across slices; no TC spans slices.
- [ ] **Non-functional mapping** (`Impact Analysis`): each code-requiring Non-functional item maps to an Impl Step (or `ops-only`). Unmapped: __.

If ALL checked → emit "Plan drafted. Run the review-feature skill."
