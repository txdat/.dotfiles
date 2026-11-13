# Claude Code

Rules symlink: `~/.claude/CLAUDE.md` → `~/.dotfiles/.ai-shared/CORE.md`.

**skills** — create `~/.claude/skills/<name>/SKILL.md` from the [Claude template](#claude-template), taking name, description, effort, and model from [skills](../skills/README.md).

**agents** — create `~/.claude/agents/<name>.md` from the [Claude agent template](#claude-agent-template), taking name, description, tools, and md file from [agents](../agents/README.md).

**hooks** — in `~/.claude/settings.json`, register `~/.dotfiles/.ai-shared/bin/gate-check.sh` for `PreToolUse` with matcher `Skill|Bash|Edit|Write|MultiEdit`, for `PostToolUse` and `PostToolUseFailure` with matcher `Bash`, and for `UserPromptSubmit` (user-typed `/dev-*` commands, which bypass the Skill tool). On `Skill` it gates the phase; on the others it applies the refusals of [plan.md — Changes](../skills/dev/plan.md#changes), with the Bash call as the shell call. Also register `~/.dotfiles/.ai-shared/bin/test-serial-check.sh` for `PreToolUse` with matcher `Bash`; it blocks a command that names a test runner listed in its `SERIAL_FLAG` table without that runner's serial flag under [CODING.md — Tests](../CODING.md#tests).

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
