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

## Test Steps
- [ ] Test 1: <what> — verifies <invariant>

## Implementation Steps
- [ ] Step 1: <what> — makes Test 1 pass

## Out of Scope
- <item>: <why>
```

Rules: 5–10 steps, dependency-ordered, Tests before Impl, every Impl refs a Test. >10 → propose split.

**TDD gate** (blocking): Test Steps non-empty, all Impl refs Test. Feature/fix → failing tests; refactor → coverage tests.

Save. Show: name, type, requirement, counts, path.

Ask: "Changes?" then "Create issue?" → `gh issue create`, update `Issue:` field.

Output: "Plan drafted. Run the review-feature skill."
