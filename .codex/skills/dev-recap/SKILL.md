---
name: dev-recap
description: "Capture reusable insights and archive session outcomes after implementation."
model: gpt-5.3-codex
effort: medium
---


# /dev:recap — Session Insights & Memory Capture

If `skip approval` context — skip "Anything to capture?" and "Does this look right?", apply automatically.

Find active plan in `docs/plans/`. Run `git diff main --stat` and `git log main..HEAD --oneline`. Ask: "Anything to capture?"

## Categories

- **📌 Facts**: project decision, non-reusable
- **🔁 Patterns**: technique that worked — phrase as imperative
- **⛔ Anti-patterns**: approach that failed — phrase as "Do NOT..."
- **💡 Concepts**: what X is, when to use, trade-off

Disambiguation: Fact = decision; Pattern = technique. Pattern = rule; Concept = explanation. Pattern = success; Anti-pattern = failure.

## Routing

- Patterns/Anti-patterns → `<repo>/CODEX.md` only
- Facts/Concepts → recap file only
- Command improvements → new command file or note

Present extraction. Ask: "Does this look right?" Apply before writing.

Append under section headers — never overwrite.

Save to `docs/recaps/<basename>_<date>.md`: task, PR URL, insights, plan path. Update plan to `archived`.

Print: task, PR URL, plan path, counts.
