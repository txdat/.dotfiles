# /create-pr — Create Pull Request

Plans: `docs/plans/`. Find active plan. **Planned work requires status `reviewed` or `recapped`**: if a plan exists but isn't `reviewed`/`recapped` (e.g. `implemented`), STOP — run `/dev:review-code` first, then `/dev:recap` for the ship-feature flow. No plan → warn, ask for PR scope, proceed ad-hoc. Read plan when present + project config file (CLAUDE.md/CODEX.md/GEMINI.md/AGENTS.md).

Resolve `<base>` per CORE. PR bases come from `<base>` and the chain order — not the current branch: execute-feature/fix-bug create the slice branches and commit there before this skill runs. Branch names and order come from `## PR Pattern` in the plan (ad-hoc: a single derived branch).

## PR Pattern

Read `## PR Pattern` from the active plan:
- **Finalized** (no `(provisional)` marker) → use it: `single` or `chain`, with the listed branch names and summaries.
- **Provisional** (unexpected once `reviewed` — review-code finalizes before flipping status) → STOP; run `/dev:review-code` to finalize against the actual diff.
- **Absent** (no pattern, or no plan) → single ad-hoc PR: one slice, branch `<type>/<slug>` derived from the diff scope.

## Procedure

`<branch-k>` = branch name in row k of the plan's PR Pattern table (single PR: the sole row, `<type>/<slug>`; chain: `<type>/<slug>-k`; ad-hoc absent pattern: the single derived `<type>/<slug>`, k = 1).

Define `<parent>` per context:
- Single PR: `<parent>` = `<base>`
- Chain PR k: `<parent>` = `<branch-(k-1)>` for k > 1, else `<base>`

---

For each PR (single = N of 1; chain = repeat for k = 1…N):

**1. Branch** — **planned work:** `<branch-k>` must already exist (execute-feature/fix-bug created it from the correct parent) — absent → STOP `❌ <branch-k> missing — run execute-feature/fix-bug first`. **Ad-hoc** (no plan): create from `<base>`. Then switch onto it:
```bash
git rev-parse --verify <branch-k> 2>/dev/null || git checkout -b <branch-k> <base>   # ad-hoc only; planned + missing → STOP above
git checkout <branch-k>
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

All N rows are present from PR-1 onward (branches known from the plan's PR Pattern). Bold the current row. Use `—` for links not yet created.

**6. Create:**
```bash
gh pr create --title "..." --body "..." --base <parent> --draft
```

**7. Back-fill PR-1 (chain, k > 1 only):** after each PR-k is created, update PR-1's body — replace the `—` in `<branch-k>`'s row with `#<pr-k-number>`. Anchor on the exact branch cell `| <branch-k> |` (with pipe boundaries) so prefix-sharing branches don't collide (e.g. `…-1` must not match `…-10`):
```bash
body=$(gh pr view <pr-1-number> --json body -q .body)
gh pr edit <pr-1-number> --body "$(printf '%s' "$body" | sed "\\#| <branch-k> |# s|—|#<pr-k-number>|")"
```

Default `--draft`. Pass `ready` to open directly.

Print PR URL. Update plan status to `archived`. Print: "Feature shipped."
