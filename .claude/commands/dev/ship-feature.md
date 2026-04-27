---
model: sonnet
effort: high
---

# /ship-feature — Full Feature Cycle

**explore → design → execute → review → recap → pr**

`$ARGUMENTS`: `<requirement>` — append `from <step>` to resume, `skip approval` for unattended run.

Read `CLAUDE.md` before starting.

## Entry Point

Determine starting phase from `from <step>` or auto-detect from existing plan file (`.plan.md`, `PLAN.md`, etc.):

| Plan status | Start from |
|-------------|------------|
| none / not found | explore |
| planning | plan |
| approved / in-progress | execute |
| implemented | review |
| reviewed | recap |
| pr-created | **STOP** — PR already exists |

## Flow Control

**Normal mode**: PAUSE after each phase — ask user to confirm before proceeding.

**`skip approval` mode**: No pauses. Auto-approve internal prompts (issue creation, plan changes, fixes). Proceed to next phase immediately.

## Phases

1. **explore** → `/dev:explore`
2. **plan** → existing plan? `/dev:review-feature` : `/dev:design-feature`
3. **execute** → `/dev:execute-feature` (RED→GREEN→BLUE)
4. **review** → `/dev:review-code` — if rework needed, fix inline and re-review
5. **recap** → `/dev:recap`
6. **pr** → `/dev:create-pr` — print PR URL and finish
