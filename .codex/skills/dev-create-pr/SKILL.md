---
name: dev-create-pr
description: "Create a pull request from an implemented or reviewed plan."
model: gpt-5.4-mini
effort: medium
---


# /dev:create-pr — Create Pull Request

Plans: `docs/plans/`. Find active plan (`implemented`/`reviewed`). If none, warn. Read plan + `CODEX.md`.

If on `main`/`master`, create branch: `<type>/<slug>` (feat/fix/refactor/chore/migration/hotfix).

Pre-flight:
```bash
git diff main | rg -n "System\.out|console\.log|print\(|// DEBUG"
git diff main | rg -n "^[<>]{7}|^={7}"
```

Stage and commit: `<type>(<scope>): <summary>`.

PR description from plan + `git diff main`:
- **Title**: `<type>(<scope>): <under 72 chars>`
- **WHAT**: 3–6 bullets of behavior changes
- **HOW**: approach, decisions, correctness, out of scope
- **Testing**: tests, invariants, manual steps
- **Checklist**: from `CODEX.md` or default
- **Closes**: `Closes #N` if plan has `Issue:` set

```bash
gh pr create --title "..." --body "..." --draft
```

Default `--draft`. Pass `ready` to open directly.

Print PR URL. Update plan status to `pr-created`. Print: "Run /dev:recap before closing."
