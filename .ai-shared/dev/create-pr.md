# /create-pr — Create Pull Request

Plans: `docs/plans/`. Find active plan (`implemented`/`reviewed`). If none, warn and ask for PR scope before proceeding. Read plan when present + project config file (CLAUDE.md/CODEX.md/GEMINI.md/AGENTS.md).

Resolve `<base>` per GUIDELINES. Record current branch as `<target>`. Always checkout a new branch `<type>/<slug>` (feat/fix/refactor/chore/migration/hotfix) targeting `<target>`.

## Scope assessment — single PR vs. chain

Before creating any branch, assess the total diff:
```bash
git diff <base>..<target>   # committed changes
git diff                    # uncommitted changes
```

If focused → single PR. If it spans multiple concerns, **create a chain** — one focused PR per slice rather than one large PR.

Split axes (pick natural boundaries):
- **arch** — structural/schema/infra changes without new behaviour
- **feat** — behaviour built on top of arch
- **l10n** — string/translation-only changes
- **test** — test-only additions or refactors
- **migration** — data or DB migration scripts
- **chore** — config, deps, tooling

## Procedure

Define `<parent>` per context:
- Single PR: `<parent>` = `<target>`
- Chain PR k: `<parent>` = `<type>/<slug>-(k-1)` for k > 1, else `<target>`

### Chain pre-pass (chain only — do before creating any branch)

Enumerate all N slices upfront: assign each a branch name `<type>/<slug>-k` and a one-line summary. This is fully known before PR-1 is created, so PR-1 lists all N rows from the start.

---

For each PR (single = N of 1; chain = repeat for k = 1…N):

**1. Branch** — create if new, switch if already exists:
```bash
git checkout -b <type>/<slug>-k 2>/dev/null || git checkout <type>/<slug>-k
```

**2. Commit (if uncommitted changes exist for this slice):**
```bash
git diff --cached --quiet && git diff --quiet || \
  git add <slice-files> && git commit -m "<type>(<scope>): <summary>"
```
Skip silently if the working tree is already clean (commits already in place).

**3. Guard — abort if branch has no new commits above `<parent>`:**
```bash
git log <parent>..HEAD --oneline
```
If empty: absorb this slice into the previous PR or drop it. Do not create an empty PR.

**4. Pre-flight:**
```bash
git diff <parent>..HEAD | rg -n "System\.out|console\.log|print\(|// DEBUG"
git diff <parent>..HEAD | rg -n "^[<>]{7}|^={7}"
```

**5. PR description** from plan + `git diff <parent>..HEAD`:
- **Title**: `<type>(<scope>): <under 72 chars>`
- **WHAT**: 3–6 bullets of behaviour changes
- **HOW**: approach, decisions, correctness, out of scope
- **Testing**: tests, invariants, manual steps
- **Checklist**: from project config or default
- **Closes**: `Closes #N` if plan has `Issue:` set
- **Chain index** (chain PRs only — include in every PR of the chain):

```
## Chain
| # | Branch | PR | Summary |
|---|--------|----|---------|
| **1** | **feat/foo-1** | **#NNN** | **arch changes** ← current |
| 2 | feat/foo-2 | — | feature logic |
| 3 | feat/foo-3 | — | l10n strings |
```

All N rows are present from PR-1 onward (branches known from pre-pass). Bold the current row. Use `—` for links not yet created.

**6. Create:**
```bash
gh pr create --title "..." --body "..." --base <parent> --draft
```

**7. Back-fill PR-1 (chain, k > 1 only):** after each PR-k is created, update PR-1's body — fetch its current body, replace the `—` in row k with `#<pr-k-number>`, and push back:
```bash
body=$(gh pr view <pr-1-number> --json body -q .body)
gh pr edit <pr-1-number> --body "${body//<row-k-dash>/#<pr-k-number>}"
```

Default `--draft`. Pass `ready` to open directly.

Print PR URL. Update plan status to `pr-created`. Print: "Run /dev:recap before closing."
