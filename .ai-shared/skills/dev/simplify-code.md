# /simplify-code — Simplify Existing Code

Target from $ARGUMENTS or ask. Read target + project config file (CLAUDE.md/CODEX.md/GEMINI.md/AGENTS.md).

Scope: simplification only. No features, bug fixes, or behavior changes.

## Analysis

Single file → analyze inline. Otherwise, write to `/tmp/ai-ctx/<slug>.md`:
```
Standards: <from project config>
Scope: simplification only
```

Spawn `code-explorer` per file: "Read /tmp/ai-ctx/<slug>.md. Analyze <file>. Find: dead code · redundant logic · premature abstractions · over-engineering. Per finding: file:line, why, simpler form."

## Apply

Present findings. Ask: "Apply all / pick / skip?"

Apply approved inline. Run targeted tests — if fail, revert and report.

Print: simplified, lines removed, test status.
