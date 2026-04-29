---
model: sonnet
effort: high
---

# /simplify-code — Simplify Existing Code

Target from $ARGUMENTS or ask. Read target + `CLAUDE.md`.

Scope: simplification only. No features, bug fixes, or behavior changes.

## Analysis

Single file → analyze inline. Otherwise, write to `/tmp/claude-ctx-<slug>.md`:
```
Standards: <from CLAUDE.md>
Scope: simplification only
```

Spawn `code-explorer` per file: "Read /tmp/claude-ctx-<slug>.md. Analyze <file>. Find: dead code · redundant logic · premature abstractions · over-engineering. Per finding: file:line, why, simpler form."

## Apply

Present findings. Ask: "Apply all / pick / skip?"

Apply approved inline. Run targeted tests — if fail, revert and report.

Print: simplified, lines removed, test status.
