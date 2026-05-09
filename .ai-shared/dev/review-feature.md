# /review-feature — Review Feature Plan

If `skip approval` context — auto-apply changes, auto-create sub-issues.

Do NOT write code.

Find plan from $ARGUMENTS or by status `planning`/`approved`/`blocked-by-architecture`. If unfamiliar areas, suggest the explore skill.

Read plan + project config file (CLAUDE.md/CODEX.md/GEMINI.md/AGENTS.md).

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

Ask: "Apply?" If `planning` or `blocked-by-architecture` + resolved → `approved`. Print: "Plan approved. Run the execute-feature skill."
