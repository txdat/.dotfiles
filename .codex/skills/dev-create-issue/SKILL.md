---
name: dev-create-issue
description: "Create a standalone GitHub issue. Use make-plan for plan-linked issues."
model: gpt-5.4-mini
effort: medium
---


# /dev:create-issue — Standalone GitHub Issue

For plan-linked issues, use `/dev:make-plan` instead.

Collect from $ARGUMENTS or ask: title (required), description, labels, milestone.

```bash
gh issue create --title "..." --body "..." [--label "..."] [--milestone "..."]
```

Print issue URL.
