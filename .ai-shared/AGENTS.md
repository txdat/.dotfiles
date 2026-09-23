# AI Rules

## Authority

Platform instructions and the user's task and existing authorization take precedence over these local defaults. Project configuration owns style, structure, and project commands. Each referenced file owns its stated policy; other files link to it rather than redefine it.

Shared rules live in `~/.dotfiles/.ai-shared/`. Resolve relative references from each source file's directory, following symlinks.

## Communication and judgment

Lead with the result or next action. Use clear, concise English unless the task calls for another language. Explain tradeoffs and uncertainty that affect the decision; avoid praise, filler, and rigid response templates.

Use supplied answers and inspected evidence. Resolve routine implementation details from existing patterns. Ask only when a missing requirement, material decision, or authorization blocks the affected action; continue independent authorized work.

## Work

Fit planning to the task. Application-code changes follow [PROCESS.md — Scope](PROCESS.md#scope). Other local edits may proceed directly when the request is clear; state a short plan for substantial work. Prepare concrete, reviewable results within existing authorization.

Direct edits are complete when the requested change is implemented, affected checks pass, and the result is reported. Report blocked or unrun required checks and their implications instead of claiming completion.

Within authorized work, run local checks and read-only inspection and fix in-scope failures without renewed approval, subject to existing attempt budgets and phase gates. Review-only requests remain read-only.

For background jobs, agents must use returned responses, completion notifications, and user input to determine the next action. While a job is pending, continue independent authorized work; when none remains, report the pending work and end the turn. Do not wait, poll status or logs, run sleep/check loops, or hold the turn open for a notification. Resume dependent work only when a result supplies the required evidence or user input changes the task. Pending is not completion. If notifications are unavailable, report that limitation and yield. A bounded readiness check with a timeout, such as a port or health probe for a service the current step depends on, is part of that step rather than waiting on a job.

Commit pushes never wait for CI: agents must finish remaining authorized work, report the push results, and end the turn. This applies to standalone pushes, existing PR updates, and PR creation, including workflows with several pushes. Use already-known CI results or mark CI unverified; do not fetch CI status or logs solely for the final report. Required local checks still apply.

CI monitoring or repair requires an explicit user request covering that work; an earlier request in the same task counts, including one made before a handoff or resume. Without that authorization, do not poll CI, run watchers such as `gh pr checks --watch` or `gh run watch`, launch or delegate background CI monitoring, or retry or repair failed CI checks. A push, PR publication, or CI notification alone grants no such authorization. Authorized CI work still follows the background-job rule above.

Plan-backed PR publication ends under [create-pr.md — Complete](skills/dev/create-pr.md#complete).

After three failed fix-and-verification attempts at the same unresolved failure, stop fixing and report what you tried, what happened, and what evidence or decision you need. Stop sooner if attempts produce no new evidence or progress. The count persists across hypotheses, delegation, and sessions until verification resolves the failure or explicit user direction grants three further attempts (unless otherwise specified); retain prior history. Read-only diagnosis and other authorized work may continue. This failed-fix counter is independent of [independence.md](skills/dev/independence.md)'s repair/re-review counter per artifact and review phase. Both limits apply during review loops; stop when either is exhausted, and never treat exhaustion as success.

Use [handoff](skills/handoff.md) when continuity needs a saved snapshot.

## Load on demand

- [CODING.md](CODING.md): every agent reads it before reading or writing code.
- [PROCESS.md](PROCESS.md): for plan-backed development or a workflow gate failure.

Reuse loaded guidance while it remains current. Domain skills supply their own task-specific guidance.
