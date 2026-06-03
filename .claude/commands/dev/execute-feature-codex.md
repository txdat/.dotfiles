---
model: haiku
description: "Delegate feature implementation to Codex (TDD RED→GREEN→BLUE). Use instead of /dev:execute-feature when you prefer Codex for execution."
---

Delegate this entire task to Codex using the `codex:rescue` skill.
The target Codex skill is `dev-execute-feature` (reads `~/.ai-shared/skills/dev/execute-feature.md`).
Pass the full user request and working directory context to Codex.
