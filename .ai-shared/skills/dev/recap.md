# /recap — Session Insights & Memory Capture

Resolve the session's active plan (ship cycle: status `reviewed`): an explicit `docs/plans/<file>.md` (or its slug) in $ARGUMENTS pins it; otherwise the session's pinned plan, else the lone active plan. 0 or 2+ active and none named → STOP, ask which. Resolve `<base>` per CORE. Run `git diff <base> --stat` and `git log <base>..HEAD --oneline`. PR is created after recap in the ship-feature flow; if a PR already exists, capture the PR URL via `gh pr view --json url -q .url` (chain → one per branch; none → omit). Ask: "Anything to capture?"

## Categories

- **📌 Facts**: project decision, non-reusable
- **🔁 Patterns**: technique that worked — phrase as imperative
- **⛔ Anti-patterns**: approach that failed — phrase as "Do NOT..."
- **💡 Concepts**: what X is, when to use, trade-off

Disambiguation: Fact (decision) vs Pattern (reusable technique) vs Concept (explanation) vs Anti-pattern (failed approach).

## Routing

- Patterns/Anti-patterns → `<repo>/project config file (CLAUDE.md/CODEX.md/GEMINI.md/AGENTS.md)` only
- Facts/Concepts → recap file only
- Command improvements → new command file or note

Present extraction. Ask: "Does this look right?" Apply before writing.

Append under section headers — never overwrite.

Save to `docs/recaps/<basename>_<date>.md`: task, PR URL if available, insights, plan path. Update plan to `recapped`.

## Self-Check (BLOCKING — do NOT emit completion until every item is ✅)

Run this audit before the final output. If ANY item is unchecked → STOP, fix, re-check.

- [ ] **Plan status**: status `reviewed`. Current: __.
- [ ] **Diff reviewed** (top): `git diff <base> --stat` and `git log <base>..HEAD --oneline` captured.
- [ ] **Categories correct** (`## Routing`): Facts/Concepts → recap only; Patterns/Anti-patterns → project config only. No cross-contamination.
- [ ] **User approved**: extraction presented, user confirmed "Does this look right?"
- [ ] **Sections appended**: appended under existing headers — nothing overwritten.
- [ ] **File saved**: `docs/recaps/<basename>_<date>.md` with task, PR URL (if any), insights, plan path.

If ALL checked → update plan to `recapped`. Print: task, PR URL if available, plan path, counts. Print: "Recap complete. Run the create-pr skill."
