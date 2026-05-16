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
```

Rules: 5–10 Implementation Steps, dependency-ordered. Every Impl refs ≥1 TC-N; every TC referenced by ≥1 Impl. >10 → propose split. Symbols cited in Impl steps must be verified members of their target type/module before the step is written — see GUIDELINES `Verify symbol membership`.

**TDD gate** (blocking):
- Feature/fix: ≥1 TC; every TC has all four fields (Given/When/Then/Verifies); TCs describe new behavior that will initially fail.
- Refactor: TCs pin existing behavior to preserve (must pass before and after); Given/When/Then describe current behavior, Verifies cites the invariant kept intact.
- Bidirectional refs: every Impl → ≥1 TC-N; every TC → ≥1 Impl.

Save. Show: name, type, requirement, counts, path.

Ask: "Changes?" then "Create issue?" → `gh issue create`, update `Issue:` field.

Output: "Plan drafted. Run the review-feature skill."
