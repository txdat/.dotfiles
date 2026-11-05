# OpenCode

Rules symlink: `~/.config/opencode/AGENTS.md` → `~/.dotfiles/.ai-shared/CORE.md`. OpenCode V2 recognizes `AGENTS.md` only and does not fall back to `CLAUDE.md`.

**skills** — reuse the Claude skills. OpenCode discovers `~/.claude/skills` as a global compatibility source, so do not create native skill wrappers: keep `~/.config/opencode/skills` absent, because a native skill with the same ID would take precedence over the Claude wrapper. OpenCode ignores the Claude `model` and `effort` fields and uses the session's selected model.

**agents** — create `~/.config/opencode/agents/<name>.md` from the [OpenCode agent template](#opencode-agent-template), taking name, description, and md file from [agents](../README.md#agents). OpenCode does not discover `~/.claude/agents`, so these must be native. The file name supplies the agent ID, and the template's `mode: subagent` exposes the agent only to the parent agent's `subagent` tool.

**phase loading and gates** — OpenCode has no `gate-check.sh` hook here, so phase entry relies on the skill's own prerequisites under [skills/dev/plan.md](../skills/dev/plan.md). Loading a phase skill grants no authority to execute it.

## OpenCode agent template

```
---
description: "<description>"
mode: subagent
---

Read <absolute-path-to-md-file> and follow all instructions exactly.
```
