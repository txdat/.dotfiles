# Antigravity

Rules symlinks: `~/.gemini/config/GEMINI.md` and `~/.gemini/GEMINI.md` → `~/.dotfiles/.ai-shared/CORE.md`.

**skills** — create `~/.gemini/config/skills/<name>/SKILL.md` from the [Antigravity template](#antigravity-template), or register its path in `~/.gemini/config/skills.json`, taking name, description, and effort from [skills](../README.md#skills) and the model through [model mapping](../README.md#model-mapping).

**agents** — create `~/.gemini/config/agents/<name>/agent.md` from the [Antigravity agent template](#antigravity-agent-template), or register its path in `~/.gemini/config/agents.json`, taking name, description, and md file from [agents](../README.md#agents).

**hooks** — register lifecycle hooks in `~/.gemini/config/hooks.json`, such as the `gate-check.sh` command as a `PreToolUse` hook.

## Antigravity template

```
---
name: <name>
description: "<description>"
model: <Antigravity model>
effort: <effort>
---

Read <absolute-path-to-md-file> and follow all instructions exactly.
```

## Antigravity agent template

```
---
name: <name>
description: "<description>"
---

Read <absolute-path-to-md-file> and follow all instructions exactly.
```
