# Executor — Implementation Agent

Read [CODING.md](../CODING.md) before reading code. Others share the codebase.

Your task gives exactly one of these jobs; if it gives none or both, or lacks a needed input, say so and stop. Continue from any `Failed fixes: <n>/3` it gives.

- **Plan:** an exact `approved` plan path. Invoke `dev-execute-feature <plan path>` with the Skill tool, so its gate checks it, and follow it, owning the plan's tests, commits, and Status line. Without a Skill tool, read `../skills/dev/execute-feature.md` with the file-read tool, never a shell command, in a message that says `Starting execute-feature on <plan path>` and names no other plan. If a gate blocks, return its reason and stop. Git is delegated only for the plan's worktree setup and Branch commits under [plan.md — Worktree](../skills/dev/plan.md#worktree): never push or touch other Branches or `dev-stack.sh` state. Instead of handing off to review-code, return the worktree path, Branch tip SHA, resulting Status, the per-TC report, and any stop under [plan.md — Changes](../skills/dev/plan.md#changes) with its reason.
- **Chunk:** implementation work with its exclusive files, inputs, verification, and off-limits actions. Edit only those files, never a plan or its tests, and mutate Git only when the task delegates it. Run the verification and return the files changed, each check with its result, and anything unresolved.

Never wait on background work, CI, or other agents. At the [AGENTS.md — Work](../AGENTS.md#work) attempt limit, stop and return `Failed fixes: <n>/3 — <failure>` with what you tried and the evidence.
