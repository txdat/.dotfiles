# /create-pr — Publish Reviewed Work

Read [PROCESS.md](../../PROCESS.md) and resolve the named plan under [plan.md](plan.md). Entry is `reviewed` with a finalized PR Pattern. Default to draft unless `ready` is requested. [`~/.dotfiles/.ai-shared/bin/dev-publish.sh`](../../bin/dev-publish.sh) (`dev-publish.sh` below) performs every mechanical step and rechecks state on each run; on `BLOCK` or failure, stop and report its output rather than working around it.

## Publish

1. Run `dev-publish.sh preflight <plan>`. It checks each slice against its recorded Parent and `Green:` record, its diff and artifacts, and existing PRs, and prints each slice's base. A recorded Parent that no longer exists follows [plan.md — Changes](plan.md#changes).
2. Run `dev-publish.sh archive <plan>` and inspect the printed diff of the plan copy for sensitive content. Then run `dev-publish.sh archive --commit <plan>`.
3. For each slice, first to last, write its body under [PR bodies](#pr-bodies), then run `dev-publish.sh create <plan> <PR-n> <title> <body-file> [--ready]`. Each body links PRs created before it, so it is written only after they exist. The script pushes without force and creates the PR against the recorded Parent. `EXISTS` means the slice's PR already exists from an earlier run: continue.
4. Run `dev-publish.sh verify <plan>`. Fix body mismatches with `gh pr edit --body-file`, then rerun; any other `BLOCK` stops publication.
5. Update issues under [Issue links](#issue-links).
6. Run `dev-publish.sh cleanup <plan>`. When it lists ignored content, check it for unrelated files, then rerun with `--ignored-checked`.

## Merge handoff

PR bodies give the maintainer merge context: the intended integration branch, external parent PR dependencies, dependency order, and any repository-prescribed merge strategy. Identify the integration branch from project configuration, check live merge/protection settings for constraints, and record it separately from publication Parents, which may be unmerged dependency branches. Resolve ambiguity before publication.

For dependent PRs, note that downstream bases must be reconciled as parents merge, and that squash or rebase merges can alter a replayed diff, so the maintainer re-verifies it against the reviewed slice. These are maintainer notes; the workflow never merges, retargets, or rewrites branches.

## PR bodies

Use [language.md](language.md) and the project template: the change, rationale, verification, and limitations, with `Refs #N` and no issue-closing keywords. Include the ordered branch/parent table linking every earlier PR; later entries use branch names only, without predicted numbers or placeholders, and created bodies are not backfilled. The final PR links the archive by its full 40-character commit SHA: `…/blob/<archive-sha>/<plan path>`. After verify passes, read the fetched bodies for language and the merge handoff.

## Issue links

For each represented issue, mark only the delivered goal's checklist items complete and attach their PR numbers after all its PRs exist. Preserve other goals; resolve an ambiguous goal entry before editing. PRs only reference issues; closing one is a QA or maintainer decision.

## Complete

Return the PR URLs and the cleanup output, and end the turn. Claim completion only after verify and cleanup pass; otherwise report the script output for manual handling. A failed cleanup resumes by rerunning `dev-publish.sh cleanup <plan>`, not create-pr. Once any PR of the plan is merged or closed, stop and report it; the user finishes as under [plan.md — Lifecycle](plan.md#lifecycle) Stopping. Publication does not establish CI success, merge, or deployment. Follow-up changes use a new plan whose Parent follows [design-feature.md — PR slicing](design-feature.md#pr-slicing).
