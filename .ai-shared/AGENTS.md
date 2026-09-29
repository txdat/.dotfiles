# AI Rules

## Authority

Platform instructions and the user's task and existing authorization take precedence over these local defaults. Project configuration owns style, structure, and project commands. Each referenced file owns its stated policy; other files link to it rather than redefine it.

Shared rules live in `~/.dotfiles/.ai-shared/`. Resolve relative references from each source file's directory, following symlinks.

## Communication and judgment

Lead with the result or next action. Use clear, concise English unless the task calls for another language. Explain tradeoffs and uncertainty that affect the decision; avoid praise, filler, and rigid response templates.

Use supplied answers and inspected evidence. Resolve routine implementation details from existing patterns. Ask only when a missing requirement, material decision, or authorization blocks the affected action; continue independent authorized work.

## Work

Fit planning to the task. Local edits, including application code, proceed directly when the request is clear; state a short plan for substantial work. [PROCESS.md — Scope](PROCESS.md#scope) defines entry into the plan-backed development workflow.

Direct edits are complete when the requested change is implemented, affected checks pass, and the result is reported. Report blocked or unrun required checks and their implications instead of claiming completion.

Within authorized work, run local checks and read-only inspection and fix in-scope failures without renewed approval, subject to attempt budgets and phase gates. Review-only requests remain read-only.

Never wait on background work. While a job is pending, continue independent authorized work; when none remains, report what is pending and end the turn. Resume dependent work only when a result or user input arrives. Do not poll, run sleep/check loops, or hold the turn open. A bounded readiness probe for a service the current step needs is part of that step.

Never wait for CI after a push, including PR creation or update: finish the remaining authorized work, report the results, and end the turn; cite already-known CI results or mark CI unverified. Monitoring, retrying, or repairing CI requires an explicit user request in the current task, including one made before a handoff; a push, PR, or CI notification is not such a request.

After three failed fix-and-verification attempts at the same failure, stop fixing and report what you tried, what happened, and the evidence or decision you need; stop sooner when attempts yield no new evidence. The count persists across hypotheses, delegation, and sessions until verification resolves the failure or the user grants three more attempts. Record `Failed fixes: <n>/3 — <failure>` where the work is tracked — the active plan's `## Review History`, otherwise a [handoff](skills/handoff.md) — keeping prior history. Read-only diagnosis and other authorized work may continue.

## Load on demand

- [CODING.md](CODING.md): every agent reads it before reading or writing code.
- [PROCESS.md](PROCESS.md): for plan-backed development or a workflow gate failure.

Reuse loaded guidance while it remains current.
