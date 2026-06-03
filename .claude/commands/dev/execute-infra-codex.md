---
model: haiku
description: "Delegate infrastructure config writing to Codex. Use instead of /dev:execute-infra when you prefer Codex for execution."
---

Delegate this entire task to Codex using the `codex:rescue` skill.
The target Codex skill is `dev-execute-infra` (reads `~/.ai-shared/skills/dev/execute-infra.md`).
Pass the full user request and working directory context to Codex.
