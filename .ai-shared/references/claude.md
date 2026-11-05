# Claude Code

Rules symlink: `~/.claude/CLAUDE.md` → `~/.dotfiles/.ai-shared/CORE.md`.

**skills** — create `~/.claude/skills/<name>/SKILL.md` from the [Claude template](#claude-template), taking name, description, effort, and model from [skills](../README.md#skills).

**agents** — create `~/.claude/agents/<name>.md` from the [Claude agent template](#claude-agent-template), taking name, description, tools, and md file from [agents](../README.md#agents).

**hooks** — in `~/.claude/settings.json`, register `~/.dotfiles/.ai-shared/bin/gate-check.sh` for `PreToolUse` with matcher `Skill` (model-invoked skills) and for `UserPromptSubmit` (user-typed `/dev-*` commands, which bypass the Skill tool).

**marketplace** — add the local marketplace at `~/.dotfiles/.claude/marketplace/` with `claude plugin marketplace add <path>`, then install plugins via `/plugin`.

## Claude template

```
---
name: <name>
description: "<description>"
model: <Claude Code model>
effort: <effort>
---

Read <absolute-path-to-md-file> and follow all instructions exactly.
```

## Claude agent template

Only Claude Code takes `tools`; elsewhere the md file's rules restrict the agent.

```
---
name: <name>
description: "<description>"
tools: <tools>
---

Read <absolute-path-to-md-file> and follow all instructions exactly.
```
