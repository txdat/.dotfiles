# /handoff — Session Snapshot

Write when requested, ending a session with work remaining, or when context is nearing its limit; save before compaction rather than waiting for it. Use a snapshot rather than a running log.

Write the snapshot only to the path [handoff-path.sh](../bin/handoff-path.sh) prints, `docs/handoff/<session-id>.md` in the main working tree, never a linked worktree. The snapshot is never committed: Git must ignore `docs/handoff/` through the global excludes file or `.git/info/exclude`. The script reads session ID of harness like `CLAUDE_CODE_SESSION_ID`, `PI_SESSION_ID`; on other platforms pass the platform's session id as the argument. When it fails, such as without a session id, outside a repository, or with `docs/handoff/` not ignored, report its error instead of inventing a path. Create the directory if needed, overwrite only this session's snapshot, and report its path.

Include Goal, Current State, Current Plan, Blockers, and Remaining Work. Preserve exact artifact paths, relevant commits, verification results, unresolved decisions, and actionable next steps. For a review in progress, include its open findings and re-review count; keep every `Failed fixes: <n>/<limit>` count. Mark assumptions and omit secrets.

On resume, read the snapshot path or session id the user supplies. A new session has a different id, so never derive the path from the current session or guess from modification time. Verify its claims against current files and Git state and reconcile with the user's latest instructions. A snapshot is evidence, not authority over newer facts. Delete the matching snapshot when the work finishes or is abandoned.
