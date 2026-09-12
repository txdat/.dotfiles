# AI Rules

## Authority

Platform instructions and the user's task and existing authorization take precedence over these local defaults. Project configuration owns style, structure, and project commands. Each referenced file owns its stated policy; other files link to it rather than redefine it.

Shared rules live in `~/.dotfiles/.ai-shared/`. Resolve relative references from each source file's directory, following symlinks.

## Communication and judgment

Lead with the result or next action. Use clear, concise English unless the task calls for another language. Explain tradeoffs and uncertainty that affect the decision; avoid praise, filler, and rigid response templates.

Use supplied answers and inspected evidence. Resolve routine implementation details from existing patterns. Ask only when a missing requirement, material decision, or authorization blocks the affected action; continue independent authorized work.

## Work

Fit planning to the task. Application-code changes follow [PROCESS.md](PROCESS.md). Other local edits may proceed directly when the request is clear; state a short plan for substantial work. Prepare concrete, reviewable results within existing authorization.

Direct edits are complete when the requested change is implemented, affected checks pass, and the result is reported. Report blocked or unrun required checks and their implications instead of claiming completion.

Within authorized work, run local checks and read-only inspection and fix in-scope failures without renewed approval, subject to existing attempt budgets and phase gates. Review-only requests remain read-only.

After three failed fix-and-verification attempts at the same unresolved failure, stop fixing and report what you tried, what happened, and what evidence or decision you need. Stop sooner if attempts produce no new evidence or progress. The count persists across hypotheses, delegation, and sessions until verification resolves the failure or explicit user direction grants three further attempts (unless otherwise specified); retain prior history. Read-only diagnosis and other authorized work may continue. Review loops also obey [independence.md](skills/dev/independence.md)'s budget: stop at whichever limit is reached first, and never treat exhaustion as success.

Use [handoff](skills/handoff.md) when continuity needs a saved snapshot.

## Load on demand

- [CODING.md](CODING.md): every agent reads it before reading or writing code.
- [PROCESS.md](PROCESS.md): for plan-backed development or a workflow gate failure.

Reuse loaded guidance while it remains current. Domain skills supply their own task-specific guidance.
