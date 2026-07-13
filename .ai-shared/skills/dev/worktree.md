# Worktree Lifecycle — Single Source

Referenced by execute-feature, execute-infra, fix-bug, review-code, recap, create-pr. Skills bind `<slug>`/`<branch>`/`<parent>` themselves and follow these steps — never restate them. Resolution and the single-source-of-truth rule live in CORE `Plan worktree`.

- **Create (first run):** `<parent>` is always explicit — never implicit HEAD. Only the main agent runs these Git commands.
  ```bash
  MAIN_ROOT=$(git rev-parse --show-toplevel)
  WORKTREE="/tmp/ai-worktrees/$(basename "$MAIN_ROOT")-<slug>"
  git worktree add "$WORKTREE" -b <branch> <parent>
  ```
  Record `Worktree: <path>` (the resolved `$WORKTREE`) in the main-tree plan frontmatter immediately. Then set `Main Plan Fingerprint:` in the same frontmatter to the output of the command below — it hashes the plan with that field removed from the shared `Status:` line, so writing the value doesn't invalidate the hash (the subsequent plan copy carries it into the worktree):
  ```bash
  sed -E 's/[[:space:]]*\|[[:space:]]*Main Plan Fingerprint:[^|]*//' "$MAIN_ROOT/docs/plans/<file>.md" | sha256sum | awk '{print $1}'
  ```
- **Plan copy (once, right after create):** design skills write `docs/plans/<file>.md` only into `$MAIN_ROOT`'s working tree — never committed there — so a fresh worktree checkout lacks it. After recording the worktree and fingerprint, `cp "$MAIN_ROOT/docs/plans/<file>.md" "$WORKTREE/docs/plans/<file>.md"`. From this point on, edit and commit the plan *inside* the worktree only; never leave plan edits uncommitted at teardown.
- **Dependency linking (once, before any test run):** for each dep dir present at `$MAIN_ROOT` and absent in the worktree (`node_modules`, `vendor`, `.venv`, `venv`, `Pods`, or project convention) — symlink, never reinstall or copy: `ln -s "$MAIN_ROOT/<dep>" "<worktree>/<dep>"`. A **new** dependency → install in `$MAIN_ROOT` first (never inside a worktree — it would mutate the shared target under every other concurrent worktree), then symlink. Lockfile differs from `<base>` → warn and still symlink; do not auto-reinstall. (Dep dirs are normally gitignored; a project that doesn't ignore one leaves its symlink untracked, so teardown's `git worktree remove` will need confirmed `--force`.)
- **Resume:** `Worktree:` set → reuse it; `git worktree list` must show it (missing → STOP `❌ worktree <path> missing — recreate or ask`); verify ancestry — `git -C <worktree> merge-base --is-ancestor <parent> <branch>` non-zero → STOP `❌ <branch> not based on <parent>`.
- All plan commands run inside the worktree (`cd <worktree>` or `git -C <worktree>`).

**Plan resolution vs. truth:** resolution still scans `$MAIN_ROOT/docs/plans/` (the worktree path isn't discoverable otherwise) — match the plan file, read its `Worktree:` field there, then read live `Status:` from the worktree copy. An edit left uncommitted at teardown is lost and makes `git worktree remove` refuse. Before create-pr copies the final plan back, it recomputes the main-tree fingerprint with the fingerprint field removed from the `Status:` line and compares it with `Main Plan Fingerprint:` in the worktree plan. A mismatch — or a missing recorded value (pre-fingerprint plan) — means the shared main-tree plan cannot be proven unchanged since worktree creation: STOP and request explicit overwrite confirmation. On a match, create-pr copies the final plan back, marks it `archived`, and clears both `Worktree:` and `Main Plan Fingerprint:` before removing the worktree.

**`$MAIN_ROOT` sharing:** the main working tree is never checked out or committed to by any skill — only `git worktree add`/`remove` touch it. It stays on whatever branch it was on for the whole plan lifecycle, so it's safe to share across concurrent agents/plans on the same repo; each plan's isolation comes entirely from its own `<worktree>` + branch. The one shared-mutable-state exception is symlinked dependency directories — they point back into `$MAIN_ROOT`, so new dependencies install in `$MAIN_ROOT` itself, never inside a `<worktree>`.
