# /explore — Codebase Exploration

Target from $ARGUMENTS or ask. Read project config file (CLAUDE.md/CODEX.md/GEMINI.md/AGENTS.md). Do NOT modify files.

## Area Decomposition

Identify distinct areas (e.g. auth, API, DB). Single area → explore inline.

Otherwise, write to `/tmp/ai-ctx/<slug>.md`:
```
Target: <feature/module/question>
Stack: <detected>
Standards: <from project config>
Constraints: Read-only. Report findings only.
```

Spawn parallel `code-explorer` per area:
```
Read `/tmp/ai-ctx/<slug>.md` first.
Explore: <area>. Report: entry points, key files, data flow, patterns, gotchas.
```

## Output

```
## Exploration: <target>

### Entry Points
- `file:line` — <description>

### Key Files
- `file` — <what it owns>

### Data Flow
<input → transform → output>

### Patterns
- <pattern>: <where>

### Gotchas
- <constraint or issue>

### Open Questions
- <unclear before planning>
```

## Self-Check (BLOCKING — do NOT emit completion until every item is ✅)

Run this audit before the final output. If ANY item is unchecked → STOP, fix, re-check.

- [ ] **Read-only**: no files modified.
- [ ] **Entry Points** (`## Output`): ≥1 with file:line.
- [ ] **Key Files** (`## Output`): ≥1 with description.
- [ ] **Data Flow** (`## Output`): input → transform → output traced.
- [ ] **Patterns** (`## Output`): ≥1 with location.
- [ ] **Gotchas** (`## Output`): surfaced, or explicit `none found`.
- [ ] **Open Questions** (`## Output`): listed for planning, or explicit `none`.

If ALL checked → print: "Exploration complete."
