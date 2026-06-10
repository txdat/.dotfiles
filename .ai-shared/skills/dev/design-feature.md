# /design-feature — Feature/Fix/Refactor Planning

`skip approval` → auto-approve. Warn if active plan exists. Unfamiliar area → suggest the explore skill.

Filename: `docs/plans/<basename>_<date>_<type>_<slug>.md`. Type: feature/fix/refactor.

Read project config file (CLAUDE.md/CODEX.md/GEMINI.md/AGENTS.md). No code.

## Draft

Clarify: scope, constraints, edge cases, done. Up to 3 rounds.

```
# Task: <name>
Status: planning | Type: <type> | Issue:

## Requirement
<problem and why>

## Scope
In: <items>
Out: <items>

## Impact Analysis
### Affected Components
- `<file/module/service>`: <what changes>

### API / Contract Changes
- Breaking: <yes/no — details>
- Additive: <yes/no — details>

### Data / Schema
- Migration needed: <yes/no — details>
- Rollback plan: <yes/no — details>

## Design Decisions
| Decision | Options | Chosen | Reason |

## Risk Flags
- [ ] <risk>: <mitigation>

## Test Cases
- [ ] TC-1 `<test_fn_name>`: <scenario>
  - Given: <preconditions / inputs>
  - When: <action under test>
  - Then: <expected output / behavior>
  - Verifies: <invariant from Requirement>

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

Rules: 5–10 Implementation Steps, dependency-ordered. Every Impl refs ≥1 TC-N; every TC referenced by ≥1 Impl. >10 → propose split. Symbols cited in Impl steps must be verified members of their target type/module before the step is written — see CORE `Verify symbol membership`.

**Impact Analysis:** populate Affected Components from explore Key Files/Entry Points/Data Flow if available; scan only if no explore output exists. Affected Components ≥1 entry; API/Contract Changes and Data/Schema must each be answered.

**TDD gate** (blocking):
- Feature/fix: ≥1 TC; every TC has all four fields (Given/When/Then/Verifies); TCs describe new behavior that will initially fail.
- Refactor: TCs pin existing behavior to preserve (must pass before and after); Given/When/Then describe current behavior, Verifies cites the invariant kept intact.
- Bidirectional refs: every Impl → ≥1 TC-N; every TC → ≥1 Impl.

Save. Show: name, type, requirement, counts, path.

Ask: "Changes?" then "Create issue?" → `gh issue create`, update `Issue:` field.

**PR Pattern (final step).** After issue creation, draft the provisional `## PR Pattern` — it records slicing intent and is finalized at review-code time (scope may shift during implementation).

**Single vs. chain:** each slice must be independently mergeable without breaking the app. One deployable unit → `Type: single` (branch `<type>/<slug>`). Otherwise → `Type: chain` (branches `<type>/<slug>-k`, k = 1…N).

**Service boundary:** N independent services → one slice per service, all its layers included. Shared infrastructure → extract as a leading `arch` slice.

**Split axes** (natural boundaries):
- **migration** — DB migration scripts; always isolated (deployment-order sensitive)
- **arch** — structural code, no behaviour: DTOs, interfaces, base types, config
- **feat** — behaviour on top of arch: repositories, services, controllers
- **l10n** — string/translation-only changes
- **test** — test-only additions or refactors
- **chore** — config, deps, tooling

Enumerate every slice upfront — branch + `Steps` + one-line summary each — so the full chain is known before any PR exists. Each Implementation Step belongs to exactly one slice (the `Steps` columns partition all steps), AND no TC spans slices — every step satisfying a given TC sits in the same slice, so each slice's TCs pass within that slice alone. execute-feature runs each slice's RED→GREEN over those steps' TCs. Save.

Output: "Plan drafted. Run the review-feature skill."
