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

## Self-Check (BLOCKING — do NOT emit completion until every item is ✅)

Run this audit before the final output. If ANY item is unchecked → STOP, fix, re-check.

- [ ] **Scope** (top): only simplification — no features, fixes, or behavior changes.
- [ ] **Tests pass** (`## Apply`): targeted tests run + pass post-change. Failures: __.
- [ ] **Lines removed**: net reduction. Before: __ / after: __.
- [ ] **User approved** (`## Apply`): findings presented, user chose Apply all / pick / skip before edits.

If ALL checked → print: simplified, lines removed, test status.
