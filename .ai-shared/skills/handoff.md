# /handoff — Session Snapshot

Write when requested, ending a session with work remaining, or when context is nearing its limit; save before compaction rather than waiting for it. Use a snapshot rather than a running log.

Run [handoff-path.sh](../bin/handoff-path.sh) from the repository with the plan slug when present. It returns the task's path under `/tmp/ai-handoff/`; create the directory if needed and overwrite only that task's snapshot.

Include Goal, Current State, Current Plan, Blockers, and Remaining Work. Preserve exact artifact paths, relevant commits, verification results, unresolved decisions, and actionable next steps. Mark assumptions and omit secrets.

On resume, read the snapshot for the identified repository/task; do not guess another task from modification time. Verify its claims against current files and Git state and reconcile with the user's latest instructions. A snapshot is evidence, not authority over newer facts. Follow [plan.md](dev/plan.md) for terminal plans. Delete the matching snapshot when the work finishes or is abandoned.
