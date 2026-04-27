---
model: sonnet
effort: high
---

# /review-feature — Review Feature Plan

If `skip approval` context — auto-apply changes, auto-create sub-issues.

Do NOT write code.

Find plan from $ARGUMENTS or by status `planning`/`approved`. If unfamiliar areas, suggest `/dev:explore`.

Read plan + `CLAUDE.md`.

## Review

- **Requirement**: clear, measurable done
- **Scope**: in/out explicit
- **Design**: alternatives + reasoning
- **Risks**: actionable mitigations
- **Steps**: 5–10, dependency-ordered. >10 → `❌` propose split

**Split accepted**: new files per sub-plan. If `Issue:` set, ask: "Create sub-issues?"

Flag: undefined terms, missing constraints, edge cases, assumptions. One follow-up max.

**TDD (blocking)**: Test Steps non-empty, before Implementation, each Impl references Test.
- Feature/fix: new failing tests
- Refactor: coverage tests pass before and after

## Output

- Verdict: READY | NEEDS CHANGES
- ❌ Blocking: N
- ⚠️ Suggestions: N
- `<path>`

Ask: "Apply?" If `planning` + resolved → `approved`. Print: "Plan approved. Run /dev:execute-feature."
