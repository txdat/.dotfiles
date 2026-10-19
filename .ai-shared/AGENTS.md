# AI Rules

## Authority

Platform instructions and the user's task and existing authorization take precedence over these local defaults. Project configuration owns style, structure, and project commands. Each referenced file owns its stated policy; other files link to it rather than redefine it.

Shared rules live in `~/.dotfiles/.ai-shared/`. Resolve relative references from each source file's directory, following symlinks.

## Communication and judgment

Lead with the result or next action. Use clear, concise English unless the task calls for another language. Explain tradeoffs and uncertainty that affect the decision; avoid praise, filler, and rigid response templates.

Use supplied answers and inspected evidence. Resolve routine implementation details from existing patterns. Ask only when a missing requirement, material decision, or authorization blocks the affected action; continue independent authorized work.

## Work

Fit planning to the task: clear local edits, including application code, proceed directly; state a short plan for substantial work. [plan.md — Scope](skills/dev/plan.md#scope) defines when the plan-backed workflow applies.

A direct edit is complete when the change is implemented, affected checks pass, and the result is reported. Report blocked or unrun required checks and what they leave unproven instead of claiming completion.

Within authorized work, run local checks and read-only inspection, and fix in-scope failures without asking again, within attempt budgets and phase gates. Review-only requests stay read-only.

Never wait on background work or CI. While something is pending, continue independent authorized work; when none remains, report what is pending and end the turn. Do not poll, loop on sleep, or hold the turn open; a bounded readiness probe for a service the current step needs is part of that step. After a push or PR, cite known CI results or mark CI unverified. Monitor, retry, or repair CI only when the user asks in the current task, or asked before a handoff; a push, PR, or CI notification is not a request.

After three failed fix-and-verify attempts at the same failure, stop and report what you tried, what happened, and the evidence or decision you need; stop sooner when attempts yield no new evidence. The count persists across hypotheses, delegation, and sessions until verification passes or the user grants three more; record it as `Failed fixes: <n>/3 — <failure>` in a [handoff](skills/handoff.md). Read-only diagnosis and other authorized work may continue.

## Load on demand

- [CODING.md](CODING.md): every agent reads it before reading or writing code.
- [skills/dev/plan.md](skills/dev/plan.md): for plan-backed development or a workflow gate failure.

Reuse loaded guidance while it remains current.
