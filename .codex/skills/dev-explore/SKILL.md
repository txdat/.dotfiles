---
name: dev-explore
description: "Explore a codebase area and report entry points, flow, patterns, and gotchas."
model: gpt-5.4-mini
effort: medium
---


# /dev:explore — Codebase Exploration

Target from $ARGUMENTS or ask. Read `CODEX.md`. Do NOT modify files.

## Area Decomposition

Identify distinct areas (e.g. auth, API, DB). Single area → explore inline.

Otherwise, write to `/tmp/codex-ctx-<slug>.md`:
```
Target: <feature/module/question>
Stack: <detected>
Standards: <from CODEX.md>
Constraints: Read-only. Report findings only.
```

Spawn parallel `code-explorer` per area:
```
Read `/tmp/codex-ctx-<slug>.md` first.
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
