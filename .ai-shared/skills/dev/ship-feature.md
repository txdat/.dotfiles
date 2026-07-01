# /ship-feature — Full Feature Cycle

**explore → design-feature → review-feature → execute → review-code → recap → pr**

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
| archived | **STOP** — already shipped |

## Flow Control

PAUSE after each phase — ask the user to confirm before proceeding.

## Self-Check (BLOCKING — do NOT proceed to next phase until current phase is complete)

At the end of each phase, verify the phase's own self-check (from its skill file) is fully ✅ before asking the user to confirm the next phase.

- [ ] **Phase 1 explore**: `## Exploration` output present. Entry Points, Key Files, Data Flow, Patterns, Gotchas all populated.
- [ ] **Phase 2 plan**: review-feature verdict was READY, Open Questions empty, then ship-feature set status `approved` (ship-feature auto-approves; standalone review-feature does not).
- [ ] **Phase 3 execute**: Plan status is `implemented`. Plan's `Worktree:` field set and matches `git worktree list`. All GREEN steps passed coverage. No unlogged deviations or scope creep.
- [ ] **Phase 4 review-code**: Verdict is PASS (or PASS WITH NOTES with all Should Fix items resolved). PR Pattern finalized.
- [ ] **Phase 5 recap**: Plan status is `recapped`. Insights captured in docs/recaps/.
- [ ] **Phase 6 pr**: PR created + URL printed. Plan status is `archived`. Worktree removed, `Worktree:` field cleared.

If any phase's self-check fails → do NOT proceed. Fix the phase first.

## Phases

Once the plan file exists, pass its explicit `docs/plans/<file>.md` path to every sub-skill invocation (design-feature, review-feature, execute-feature, review-code, recap, create-pr) so each gates the same plan — never rely on implicit resolution.

1. **explore** → explore skill
2. **plan** → no plan file → design-feature skill (draft), then review-feature skill only if `Open Questions:` is empty / design-feature emitted "Plan drafted. Run the review-feature skill."; plan with status `planning`/`blocked-by-architecture` → review-feature skill only if `Open Questions:` is empty. **Auto-approve:** once review-feature returns verdict READY, ship-feature sets the plan's `Status: approved` itself — ship-feature is the *sole* auto-approver (standalone review-feature never flips status). Must reach `approved` before execute.
3. **execute** → **entry gate (BLOCKING):** plan `Status:` must be `approved`/`in-progress`, else STOP (covers `from execute` on an un-approved plan). Then execute-feature skill (RED→GREEN→BLUE).
4. **review-code** → review-code skill — if rework needed, fix inline and re-review
5. **recap** → recap skill
6. **pr** → create-pr skill — print PR URL, finish
