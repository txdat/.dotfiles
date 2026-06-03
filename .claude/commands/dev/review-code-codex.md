---
model: haiku
description: "Delegate code review to Codex. Use instead of /dev:review-code when you prefer Codex for review."
---

Delegate this entire task to Codex using the `codex:rescue` skill.
The target Codex skill is `dev-review-code` (reads `~/.ai-shared/skills/dev/review-code.md`).
Pass the full user request and working directory context to Codex.
