# /ship-feature — Full Feature Cycle

**explore → design-feature → review-feature → execute → review-code → recap → pr**

`$ARGUMENTS`: `<requirement>` — append `from <step>` to resume.

Read project AI config files before starting.

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

## Phase Gate (BLOCKING)

Each phase's own skill owns its `## Self-Check` — do NOT re-audit it here. A phase is complete only when its skill emitted its completion line (explore: `## Exploration` report; design-feature: "Plan drafted…"; review-feature: verdict; execute-feature: "Implementation complete…"; review-code: verdict; recap: status `recapped`; create-pr: PR URL + status `archived`). No completion line, or the skill stopped on a gate → do NOT proceed; fix that phase first.

## Phases

Once the plan file exists, pass its explicit `docs/plans/<file>.md` path to every sub-skill invocation (design-feature, review-feature, execute-feature, review-code, recap, create-pr) so each gates the same plan — never rely on implicit resolution.

1. **explore** → explore skill
2. **plan** → no plan file → design-feature skill (draft), then review-feature skill only if `Open Questions:` is empty / design-feature emitted "Plan drafted. Run the review-feature skill."; plan with status `planning`/`blocked-by-architecture` → review-feature skill only if `Open Questions:` is empty. **Approval:** once review-feature returns verdict READY, use the phase PAUSE — print the verdict + a plan summary (requirement, mode, slices, TC/step counts, deviational risks) and ask **"Approve plan? (sets `Status: approved`)"**. Only on the user's confirmation does ship-feature flip `Status: approved` (it remains the only skill that flips it; standalone review-feature never does). Declined → treat as NEEDS CHANGES feedback, route back. Must reach `approved` before execute.
3. **execute** → **entry gate (BLOCKING):** plan `Status:` must be `approved`/`in-progress`, else STOP (covers `from execute` on an un-approved plan). Then execute-feature skill (RED→GREEN→BLUE).
4. **review-code** → review-code skill — if rework needed, fix inline and re-review
5. **recap** → recap skill
6. **pr** → create-pr skill — print PR URL, finish
