# /create-issue — Standalone GitHub Issue

For plan-linked issues, use the design-feature skill instead.

Collect from $ARGUMENTS or ask: title (required), description, labels, milestone.

```bash
gh issue create --title "..." --body "..." [--label "..."] [--milestone "..."]
```

## Self-Check (BLOCKING — do NOT emit completion until every item is ✅)

Run this audit before creating the issue. If ANY item is unchecked → STOP, fix, re-check.

- [ ] **Standalone scope**: Issue is not linked to an implementation plan. If plan-linked, use design-feature instead.
- [ ] **Title**: Present, specific, and under 72 chars.
- [ ] **Body**: Describes problem, expected outcome, and relevant context.
- [ ] **Metadata**: Labels/milestone applied when requested; omitted only when not provided.
- [ ] **GitHub auth**: `gh auth status` uses the expected account per CORE.

If ALL checked → create the issue and print the issue URL.
