# /ship-feature — Full Feature Cycle

**explore → plan → execute → review-code → recap → pr**

`$ARGUMENTS`: `<requirement>` — append `from <step>` to resume.

Read project config file (CLAUDE.md/CODEX.md/GEMINI.md/AGENTS.md) before starting.

## Entry Point

Determine starting phase from `from <step>` or auto-detect from the active plan in `docs/plans/`:

| Plan status | Start from |
|-------------|------------|
| none / not found | explore |
| planning / blocked-by-architecture | plan |
| approved / in-progress | execute |
| implemented | review-code |
| reviewed | recap |
| recapped | pr |
| pr-created | **STOP** — PR already created |
| archived | **STOP** — already shipped |

## Flow Control

PAUSE after each phase — ask the user to confirm before proceeding.

## Phases

1. **explore** → explore skill
2. **plan** → no plan file → design-feature skill (draft), then review-feature skill only if `Open Questions:` is empty / design-feature emitted "Plan drafted. Run the review-feature skill."; plan with status `planning`/`blocked-by-architecture` → review-feature skill only if `Open Questions:` is empty. Must reach status `approved` before execute.
3. **execute** → execute-feature skill (RED→GREEN→BLUE)
4. **review-code** → review-code skill — if rework needed, fix inline and re-review
5. **recap** → recap skill
6. **pr** → create-pr skill — print PR URL, finish
