# ai-shared

Shared agent rules, workflow skills, and helper scripts for every harness on this machine. Platform-specific wrappers are generated locally and point at the markdown files here. Paths assume the checkout is at `~/.dotfiles`.

[CORE.md](CORE.md) is the global rules file, which every harness loads through its rules symlink. [AGENTS.md](AGENTS.md) guides edits to these files; one file per harness under [references](references) wires it up.

Delegation runs in the four agents listed in [agents/README.md](agents/README.md): dev-inspector for bug diagnosis, dev-planner for delegated design and plan revision, dev-reviewer for reviews under [plan.md — Review](skills/dev/plan.md#review), and dev-executor for delegated implementation, where installed; other delegation uses platform-provided subagents with the owning skill.

| Harness | Rules symlink | Setup |
| ------- | ------------- | ----- |
| Claude Code | `~/.claude/CLAUDE.md` | [claude.md](references/claude.md) |
| Codex | `~/.codex/CODEX.md` | [codex.md](references/codex.md) |
| Antigravity | `~/.gemini/config/GEMINI.md`, `~/.gemini/GEMINI.md` | [antigravity.md](references/antigravity.md) |
| Pi | `~/.pi/agent/AGENTS.md` | [pi.md](references/pi.md) |
| dsh | `~/.dsh/AGENTS.md` | [dsh.md](references/dsh.md) |
| OpenCode | `~/.config/opencode/AGENTS.md` | [opencode.md](references/opencode.md) |

## Skills

[skills/README.md](skills/README.md) indexes the skills.

## Agents

[agents/README.md](agents/README.md) indexes the agents.
