# /ship-feature — Full Feature Cycle

**explore → plan → execute → review → recap → pr**

`$ARGUMENTS`: `<requirement>` — append `from <step>` to resume, `skip approval` for unattended run.

Read project config file (CLAUDE.md/CODEX.md/GEMINI.md/AGENTS.md) before starting.

## Entry Point

Determine starting phase from `from <step>` or auto-detect from existing plan file (`.plan.md`, `PLAN.md`, etc.):

| Plan status | Start from |
|-------------|------------|
| none / not found | explore |
| planning / blocked-by-architecture | plan |
| approved / in-progress | execute |
| implemented | review |
| reviewed | recap |
| pr-created | **STOP** — PR already exists |

## Flow Control

**Normal mode**: PAUSE after each phase — ask user to confirm before proceeding.

**`skip approval` mode** (per GUIDELINES): no pauses; auto-approve internal prompts (issue creation, plan changes, fixes); proceed to next phase immediately.

## Phases

1. **explore** → explore skill
2. **plan** → existing plan? review-feature skill : design-feature skill
3. **execute** → execute-feature skill (RED→GREEN→BLUE)
4. **review** → review-code skill — if rework needed, fix inline and re-review
5. **recap** → recap skill
6. **pr** → create-pr skill — print PR URL and finish
