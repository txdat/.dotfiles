# AI Rules

## Authority

Platform instructions and the user's task and existing authorization take precedence over these local defaults. Project configuration owns style, structure, and project commands. Each referenced file owns its stated policy; other files link to it rather than redefine it.

Shared rules live in `~/.dotfiles/.ai-shared/`. Resolve relative references from each source file's directory, following symlinks.

## Communication and judgment

Lead with the result or next action. Use clear, concise English unless the task calls for another language. Explain tradeoffs and uncertainty that affect the decision; avoid praise, filler, and rigid response templates.

Use supplied answers and inspected evidence. Resolve routine implementation details from existing patterns. Ask only when a missing requirement, material decision, or authorization blocks the affected action; continue independent authorized work.

## Work

Fit planning to the task. Application-code changes follow [PROCESS.md](PROCESS.md). Other local edits may proceed directly when the request is clear; state a short plan for substantial work. Prepare concrete, reviewable results within existing authorization.

After three failed fix-and-verification attempts against the same unresolved failure, pause further fixes and report the attempts, results, and evidence or decision needed; stop earlier if attempts produce no new evidence or progress. Preserve the count across hypotheses, delegation, and sessions until verification resolves the failure or explicit user direction grants three further attempts (unless otherwise specified), retaining prior history. Read-only diagnosis and independent authorized work may continue; review loops also obey [independence.md](skills/dev/independence.md)'s budget, stopping at whichever limit is reached first, and exhaustion never means success.

Use [handoff](skills/handoff.md) when continuity needs a saved snapshot.

## Load on demand

- [CODING.md](CODING.md): every agent reads it before reading or writing code.
- [PROCESS.md](PROCESS.md): for plan-backed development or a workflow gate failure.

Reuse loaded guidance while it remains current. Domain skills supply their own task-specific guidance.
