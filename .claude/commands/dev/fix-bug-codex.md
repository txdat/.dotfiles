---
model: haiku
description: "Delegate bug diagnosis and fix to Codex. Use instead of /dev:fix-bug when you prefer Codex for execution."
---

Delegate this entire task to Codex using the `codex:rescue` skill.
The target Codex skill is `dev-fix-bug` (reads `~/.ai-shared/skills/dev/fix-bug.md`).
Pass the full user request and working directory context to Codex.
