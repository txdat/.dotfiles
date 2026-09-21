# /handoff — Session Snapshot

Write when requested, ending a session with work remaining, or when context is nearing its limit; save before compaction rather than waiting for it. Use a snapshot rather than a running log.

Run [handoff-path.sh](../bin/handoff-path.sh) to get this session's path, `$HOME/work/ai-handoff/<session-id>.md`. It reads `CLAUDE_CODE_SESSION_ID`; on other platforms pass the platform's session id as the argument. If no session id is available, report that instead of inventing one. Create the directory if needed, overwrite only this session's snapshot, and report its path.

Include Goal, Current State, Current Plan, Blockers, and Remaining Work. Preserve exact artifact paths, relevant commits, verification results, unresolved decisions, and actionable next steps. Mark assumptions and omit secrets.

On resume, read the snapshot path or session id the user supplies. A new session has a different id, so never derive the path from the current session or guess from modification time. Verify its claims against current files and Git state and reconcile with the user's latest instructions. A snapshot is evidence, not authority over newer facts. Follow [plan.md](dev/plan.md) for terminal plans. Delete the matching snapshot when the work finishes or is abandoned.
