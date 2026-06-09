# /recap — Session Insights & Memory Capture

If `skip approval` context — skip "Anything to capture?" and "Does this look right?", apply automatically.

Find active plan in `docs/plans/` (ship cycle: status `pr-created`). Resolve `<base>` per GUIDELINES. Run `git diff <base> --stat` and `git log <base>..HEAD --oneline`. Capture the PR URL via `gh pr view --json url -q .url` (chain → one per branch; none → omit). Ask: "Anything to capture?"

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

Save to `docs/recaps/<basename>_<date>.md`: task, PR URL, insights, plan path. Update plan to `archived`.

Print: task, PR URL, plan path, counts.
