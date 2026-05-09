# /create-pr — Create Pull Request

Plans: `docs/plans/`. Find active plan (`implemented`/`reviewed`). If none, warn and ask for PR scope before proceeding. Read plan when present + project config file (CLAUDE.md/CODEX.md/GEMINI.md/AGENTS.md).

Resolve `<base>` per GUIDELINES. Record current branch as the work branch. If already on a feature branch with the intended commits, do not create another. Otherwise checkout new branch: `<type>/<slug>` (feat/fix/refactor/chore/migration/hotfix).

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
- **Checklist**: from project config or default
- **Closes**: `Closes #N` if plan has `Issue:` set

```bash
gh pr create --title "..." --body "..." --base <base> --draft
```

Default `--draft`. Pass `ready` to open directly.

Print PR URL. Update plan status to `pr-created`. Print: "Run /dev:recap before closing."
