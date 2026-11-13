# Codex

Rules symlink: `~/.codex/CODEX.md` → `~/.dotfiles/.ai-shared/CORE.md`. `CODEX.md` is the only setup-managed symlink. Never remove or modify other symlinks in `~/.codex`: Codex creates them for its runtime under `packages/` and `tmp/`.

**skills** — create `~/.codex/skills/<name>/SKILL.md` from the [Codex template](#codex-template), taking name, description, and effort from [skills](../skills/README.md) and the model from the [model mapping](#model-mapping) for the Claude Code model that [skills](../skills/README.md) assigns.

**agents** — create `~/.codex/agents/<name>.toml` from the [Codex agent template](#codex-agent-template), taking name, description, and md file from [agents](../agents/README.md).

## Model mapping

| Claude Code model | Codex model |
| ----------------- | ----------- |
| haiku | `gpt-6-luna` |
| sonnet | `gpt-6.1-terra` |
| opus | `gpt-6.1-sol` |
| fable | `gpt-6-astra` |

## Codex template

```
---
name: <name>
description: "<description>"
model: <Codex model>
effort: <effort>
---

Read <absolute-path-to-md-file> and follow all instructions exactly.
```

## Codex agent template

```toml
name = "<name>"
description = "<description>"

developer_instructions = """
Read <absolute-path-to-md-file> and follow all instructions exactly.
"""
```
```
