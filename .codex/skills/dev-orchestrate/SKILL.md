---
name: dev-orchestrate
description: "Run the end-to-end dev cycle: explore, plan, execute, review, recap, and PR."
model: gpt-5.3-codex
effort: high
---


# /dev:orchestrate — Full Development Cycle

**explore → plan → execute → review → recap → pr**

`$ARGUMENTS`: `<requirement>` — append `from <step>` to resume, `skip approval` for unattended run.

Read `CODEX.md` before starting. Do not run phases out of order unless resuming with `from <step>`.

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
2. **plan** → existing plan? `/dev:review-plan` : `/dev:make-plan`
3. **execute** → `/dev:execute-plan` (RED→GREEN→BLUE)
4. **review** → `/dev:review-code` — if rework needed, fix inline and re-review
5. **recap** → `/dev:recap`
6. **pr** → `/dev:create-pr` — print PR URL and finish
