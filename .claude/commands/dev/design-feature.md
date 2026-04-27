---
model: sonnet
effort: high
---

# /design-feature — Feature/Fix/Refactor Planning

`skip approval` → auto-approve. Warn if active plan exists. Unfamiliar area → suggest `/dev:explore`.

Filename: `docs/plans/<basename>_<date>_<type>_<slug>.md`. Type: feature/fix/refactor.

Read `CLAUDE.md`. No code.

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

## Test Steps
- [ ] Test 1: <what> — verifies <invariant>

## Implementation Steps
- [ ] Step 1: <what> — makes Test 1 pass

## Out of Scope
- <item>: <why>
```

Rules: 5–10 steps, dependency-ordered, Tests before Impl, every Impl refs a Test. >10 → propose split.

**TDD gate**: Test Steps non-empty, all Impl refs Test.

Save. Show: name, type, requirement, counts, path.

Ask: "Changes?" then "Create issue?" → `gh issue create`, update `Issue:` field.

## Review

Checks: requirement measurable, scope explicit, design has alternatives, risks actionable, steps ordered.

**TDD (blocking)**: feature/fix → failing tests; refactor → coverage tests.

Flag ambiguities. One round max. Show: Verdict, Blocking N, Suggestions N.

Ask: "Apply?" → set `approved`, print path.
