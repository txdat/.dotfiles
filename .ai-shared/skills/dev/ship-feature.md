# /ship-feature — Full Feature Cycle

**explore → plan → execute → review-code → pr → recap**

`$ARGUMENTS`: `<requirement>` — append `from <step>` to resume, `skip approval` for unattended run.

Read project config file (CLAUDE.md/CODEX.md/GEMINI.md/AGENTS.md) before starting.

## Entry Point

Determine starting phase from `from <step>` or auto-detect from the active plan in `docs/plans/`:

| Plan status | Start from |
|-------------|------------|
| none / not found | explore |
| planning / blocked-by-architecture | plan |
| approved / in-progress | execute |
| implemented | review-code |
| reviewed | pr |
| pr-created | recap |
| archived | **STOP** — already shipped |

## Flow Control

**Normal mode**: PAUSE after each phase — ask user to confirm before proceeding.

**`skip approval` mode** (per GUIDELINES): no pauses; auto-approve internal prompts (issue creation, plan changes, fixes); proceed to next phase immediately.

## Phases

1. **explore** → explore skill
2. **plan** → no plan file → design-feature skill (draft); plan exists with status `planning`/`blocked-by-architecture` → review-feature skill
3. **execute** → execute-feature skill (RED→GREEN→BLUE)
4. **review-code** → review-code skill — if rework needed, fix inline and re-review
5. **pr** → create-pr skill — print PR URL
6. **recap** → recap skill — finish
