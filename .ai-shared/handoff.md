# Session Handoff

Continuity across compaction and across sessions. A handoff is a living snapshot, not a log: overwrite the file, never append history. It must let a fresh session act correctly without reading the old conversation.

**Path** (self-contained — hook agents have no other context): `/tmp/ai-handoff/<repo-basename>-<slug>.md` (`mkdir -p /tmp/ai-handoff` first). `<repo-basename>` is the basename of `git rev-parse --show-toplevel`. `<slug>` is the active plan's slug — many sessions can work one repo, so the plan distinguishes them; active plan = a `docs/plans/*.md` whose `Status:` is not `archived`, and none → drop the suffix. A worktree session's git-root basename is already `<repo>-<slug>`: use it as-is, never a second suffix. Overwrite your own file, never another slug's. Delete the file when its work ships or is abandoned — a stale handoff misleads the next session.

**Write it:** before any compaction (hooks automate this for `/compact` and auto-compact); at dev-flow phase boundaries when the session is long; whenever ending a session with work remaining or asked to hand off.

**Read it:** yourself — nothing injects it. After compaction, and before continuing another session's work on a repo, read your repo's file(s) under `/tmp/ai-handoff/` (newest matching the path rule above); where it and a compaction summary disagree, the handoff wins. If its work already shipped, it is stale — delete it instead of resuming.

## Format

```text
# Handoff: <task> — <repo> — <ISO datetime>
## Goal            # the user's requested outcome — preserve their intent, not a paraphrase that narrows it
## Current State   # only verified facts: files changed, commits made, test results, what is proven done
## Current Plan    # active docs/plans/<file>.md + its Status, or the ordered steps being followed
## Blockers        # what stops progress and exactly what input/decision unblocks it — or "none"
## Remaining Work  # ordered, concrete next steps with exact paths/commands
```

## Rules

- Keep it under ~60 lines: facts, exact paths, commands, and IDs — no narration.
- Distinguish verified from assumed: anything not proven by a run/commit is marked `unverified`.
- Remaining Work items are actionable as written; "continue the work" is not an item.
- Never include secrets, tokens, or credentials.
