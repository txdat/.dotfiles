---
model: haiku
---

# /create-pr — Create Pull Request

Plans: `docs/plans/`. Find active plan (`implemented`/`reviewed`). If none, warn. Read plan + `CLAUDE.md`.

Record current branch as base. Checkout new branch: `<type>/<slug>` (feat/fix/refactor/chore/migration/hotfix).

Pre-flight:
```bash
git diff <base> | rg -n "System\.out|console\.log|print\(|// DEBUG"
git diff <base> | rg -n "^[<>]{7}|^={7}"
```

Stage and commit: `<type>(<scope>): <summary>`.

PR description from plan + `git diff <base>`:
- **Title**: `<type>(<scope>): <under 72 chars>`
- **WHAT**: 3–6 bullets of behavior changes
- **HOW**: approach, decisions, correctness, out of scope
- **Testing**: tests, invariants, manual steps
- **Checklist**: from `CLAUDE.md` or default
- **Closes**: `Closes #N` if plan has `Issue:` set

```bash
gh pr create --title "..." --body "..." --base <base> --draft
```

Default `--draft`. Pass `ready` to open directly.

Print PR URL. Update plan status to `pr-created`. Print: "Run /dev:recap before closing."
