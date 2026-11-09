# Pi

Rules symlink: `~/.pi/agent/AGENTS.md` → `~/.dotfiles/.ai-shared/CORE.md`. Also symlink `~/.pi/agent/extensions` → `~/.dotfiles/.pi/agent/extensions`, and `~/.pi/agent/themes` → `~/.dotfiles/.pi/agent/themes`.

**skills** — Pi reuses the Claude skills; set `"skills": ["~/.claude/skills"]` in `settings.json`.

**mcp** — Pi reuses Claude MCP servers; set `"imports": ["claude-code"]` in `mcp-adapter.json`.

**phase loading and gates** — to enter a development phase, use Pi's `read` tool on the phase's Claude `SKILL.md` wrapper or on the shared `.ai-shared/skills/dev/<phase>.md` instructions. The [gate extension](../../.pi/agent/extensions/gate-check.ts) checks that read against its phase arguments: the text of the assistant message that issued it when that text names a plan, and otherwise the latest user message; where the phase requires it, those arguments must give the exact plan path.

The extension gates recognized reads, not phase execution. It cannot distinguish an audit read from invocation, and shell reads or previously loaded instructions are outside its interception, so documentation-only inspection may read source without invoking a phase, which grants no authority to execute it. It also permits reads on timeout, process failure, or invalid output. Treat it as a workflow aid rather than comprehensive enforcement: agents must still establish the phase prerequisites under [skills/dev/plan.md](../skills/dev/plan.md). Stronger enforcement would require a separate phase-entry operation.

**guards** — Claude Code's `Bash`, `Edit`, `Write`, and `MultiEdit` hooks have a Pi equivalent in the same extension: its `tool_call` event sends gate-check.sh the PreToolUse JSON for a `bash`, `edit`, or `write` call and blocks each call it refuses under [plan.md — Changes](../skills/dev/plan.md#changes). Before a Bash call gate-check.sh snapshots the plans of the current repository, and the extension's `tool_result` event on that call sends the PostToolUse JSON and adds its report to the call's own output, so the model learns what was restored. It is a guardrail against mistakes and shortcuts, not a sandbox.

**dev-stack** — the [extension](../../.pi/agent/extensions/dev-stack.ts) ports the Claude `dev-stack` plugin's `/dev-stack-*` commands over the same `dev-stack.sh`. Pi runs a command even mid-turn, so a write (`review`, `stop`, `resume`, `reopen`) waits for the turn to end before it changes a plan or its stack's log. Pi commands are user-initiated, so the Claude plugin's refusal of plugin-, SDK-, and agent-issued writes has no Pi equivalent.

**types** — the extensions are TypeScript 7 under [tsconfig.json](../../.pi/agent/extensions/tsconfig.json); `bash ~/.dotfiles/.pi/agent/extensions/typecheck.sh` checks them against the installed Pi release, whose API types they import.
