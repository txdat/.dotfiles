# /create-pr — Create Pull Request

Plans: `docs/plans/`. Find active plan. **PR creation requires status `reviewed` or `recapped`**: if no plan exists, STOP and run `design-feature` or `fix-bug` first. If the plan is `implemented`, run `review-code`. If status is `reviewed`, continue but print: `⚠️ Recap skipped — reusable insights may be lost. Run recap first if this produced patterns worth preserving.` Read plan + project config file (CLAUDE.md/CODEX.md/GEMINI.md/AGENTS.md).

Resolve `<base>` per CORE. PR bases come from `<base>` and the chain order — not the current branch: execute-feature/fix-bug create the slice branches and commit there before this skill runs. Branch names and order come from the plan's finalized `## PR Pattern`.

## PR Pattern

Read `## PR Pattern` from the active plan:
- **Finalized** (no `(provisional)` marker) → use it: `single` or `chain`, with the listed branch names and summaries.
- **Provisional** (unexpected once `reviewed` — review-code finalizes before flipping status) → STOP; run `/dev:review-code` to finalize against the actual diff.
- **Absent** → STOP; review-code/fix-bug must finalize a PR Pattern before create-pr.

## Procedure

`<branch-k>` = branch name in row k of the plan's PR Pattern table (single PR: the sole row, `<type>/<slug>`; chain: `<type>/<slug>-k`).

Define `<parent>` per context:
- Single PR: `<parent>` = `<base>`
- Chain PR k: `<parent>` = `<branch-(k-1)>` for k > 1, else `<base>`

---

For each PR (single = N of 1; chain = repeat for k = 1…N):

**1. Branch** — `<branch-k>` must already exist (execute-feature/fix-bug created it from the correct parent) — absent → STOP `❌ <branch-k> missing — run execute-feature/fix-bug first`. Then switch onto it:
```bash
git rev-parse --verify <branch-k> >/dev/null || { echo "<branch-k> missing"; exit 1; }
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

## Self-Check (BLOCKING — do NOT emit completion until every item is ✅)

Run this audit before creating the PR. If ANY item is unchecked → STOP, fix, re-check.

- [ ] **Plan status** (top): status `reviewed` or `recapped`. Current: __. If `reviewed`, warning printed: yes/no.
- [ ] **PR Pattern** (`## PR Pattern`): finalized (no `(provisional)`); provisional/absent → STOP per that section.
- [ ] **Branches exist** (Procedure 1): each `<branch-k>` exists (`git rev-parse --verify`). Missing: __.
- [ ] **Commits above parent** (Procedure 3): `git log <parent>..HEAD` non-empty per slice. Empty: __.
- [ ] **Pre-flight clean** (Procedure 4): no `System.out`/`console.log`/`print(`/`// DEBUG`, no conflict markers in diff. Issues: __.
- [ ] **PR description** (Procedure 5): title <72 chars; WHAT/HOW/Testing/Checklist present; `Closes #N` if `Issue:` set.

If ALL checked → create PR, update plan to `archived`, print PR URL + "Feature shipped."
