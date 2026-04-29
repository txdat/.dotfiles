---
model: haiku
---

# /explore — Codebase Exploration

Target from $ARGUMENTS or ask. Read `CLAUDE.md`. Do NOT modify files.

## Area Decomposition

Identify distinct areas (e.g. auth, API, DB). Single area → explore inline.

Otherwise, write to `/tmp/claude-ctx-<slug>.md`:
```
Target: <feature/module/question>
Stack: <detected>
Standards: <from CLAUDE.md>
Constraints: Read-only. Report findings only.
```

Spawn parallel `code-explorer` per area:
```
Read `/tmp/claude-ctx-<slug>.md` first.
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

Print: "Exploration complete."
