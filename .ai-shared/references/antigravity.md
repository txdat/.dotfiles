# Antigravity

Rules symlinks: `~/.gemini/config/GEMINI.md` and `~/.gemini/GEMINI.md` → `~/.dotfiles/.ai-shared/CORE.md`.

**skills** — create `~/.gemini/config/skills/<name>/SKILL.md` from the [Antigravity template](#antigravity-template), or register its path in `~/.gemini/config/skills.json`, taking name, description, and effort from [skills](../skills/README.md) and the model [skills](../skills/README.md) assigns.

**agents** — create `~/.gemini/config/agents/<name>/agent.md` from the [Antigravity agent template](#antigravity-agent-template), or register its path in `~/.gemini/config/agents.json`, taking name, description, and md file from [agents](../agents/README.md).

## Model mapping

| Claude Code model | Antigravity model |
| ----------------- | ----------------- |
| haiku | `gemini-4-hydrogen` |
| sonnet | `gemini-4-hydrogen` |
| opus | `gemini-4-argon` |
| fable | `gemini-4-carbon` |

**hooks** — in `~/.gemini/config/hooks.json`, register `~/.dotfiles/.ai-shared/bin/gate-check.sh` for `PreToolUse` with matcher `.*` and `PostToolUse` with matcher `run_command`. On `read_file` of a dev skill it gates the phase; on `run_command`, `edit_file`, and `write_file` it applies the refusals of [plan.md — Changes](../skills/dev/plan.md#changes), with `run_command` as the shell call. Also register `~/.dotfiles/.ai-shared/bin/test-serial-check.sh` for `PreToolUse` with matcher `run_command`; it blocks a command that names a test runner listed in its `SERIAL_FLAG` table without that runner's serial flag under [CODING.md — Tests](../CODING.md#tests).

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
