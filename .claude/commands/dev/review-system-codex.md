---
model: haiku
description: "Delegate architecture review to Codex. Use instead of /dev:review-system when you prefer Codex for review."
---

Delegate this entire task to Codex using the `codex:rescue` skill.
The target Codex skill is `dev-review-system` (reads `~/.ai-shared/skills/dev/review-system.md`).
Pass the full user request and working directory context to Codex.
