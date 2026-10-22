#!/usr/bin/env bash
# Main-agent-only worktree setup and cleanup; never edits, copies, or removes a plan.
set -euo pipefail

SCRIPT_DIR=$(dirname -- "$(realpath -- "${BASH_SOURCE[0]}")")
fail() { printf '%s\n' "$*" >&2; exit 1; }
usage() {
  printf '%s\n' \
    'Usage: dev-worktree.sh create <slug> <branch> <parent>' \
    '       dev-worktree.sh link-deps <worktree> [dependency-name ...]' \
    '       dev-worktree.sh isolate-dep <worktree> <dependency-name>' \
    '       dev-worktree.sh remove <worktree>' \
    'create makes <repo>-<slug> under $AI_WORKTREES_ROOT, or $HOME/work/ai-worktrees, on <branch> from <parent>,' \
    'or on <branch> as it is when it exists, and prints the new path.' \
    'link-deps defaults to node_modules vendor .venv venv Pods.' \
    'Dependencies must be direct-child directory names. Existing local content is preserved.' \
    'remove unlinks link-deps links, deletes a clean worktree, then its local branch only when origin/<branch> has the same tip;' \
    'it prints "deleted <branch>" or "kept <branch>", with the reason for keeping on stderr.' \
    'Requires the owning phase authorization; does not approve a plan or install dependencies.'
}

valid_name() {
  [[ "$1" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ || "$1" =~ ^\.[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]] || fail "Invalid directory name: $1"
}

registered_worktree() {
  local requested="$1" listing
  [[ -d "$requested" ]] || fail "Worktree directory does not exist: $requested"
  WORKTREE_PATH=$(realpath -- "$requested")
  [[ "$WORKTREE_PATH" != "$MAIN_ROOT" ]] || fail 'Dependency operations may not target the main working tree.'
  listing=$(git -C "$MAIN_ROOT" worktree list --porcelain)
  [[ "$listing" == "worktree $WORKTREE_PATH"$'\n'* || "$listing" == *$'\n'"worktree $WORKTREE_PATH"$'\n'* ]] || fail 'Target is not a registered worktree.'
}

[[ "${1-}" != --help && "${1-}" != -h ]] || { usage; exit 0; }
[[ $# -gt 0 ]] || { usage >&2; exit 2; }
MAIN_ROOT=$(bash "$SCRIPT_DIR/dev-utils.sh" main-root)
REPO_ROOT="$MAIN_ROOT"
. "$SCRIPT_DIR/dev-plan-lib.sh"

case "$1" in
  create)
    [[ $# -eq 4 ]] || fail 'create requires slug, branch, and parent.'
    slug="$2"; branch="$3"; parent="$4"
    valid_name "$slug"
    git check-ref-format --branch "$branch" >/dev/null
    [[ -n "$parent" ]] || fail 'An explicit parent is required.'
    git -C "$MAIN_ROOT" rev-parse --verify --quiet --end-of-options "${parent}^{commit}" >/dev/null || fail "Parent does not resolve: $parent"
    destination=$(worktree_path "$slug")
    [[ "$destination/" != "$MAIN_ROOT/"* ]] || fail 'Worktrees must be outside the main working tree.'
    [[ ! -e "$destination" && ! -L "$destination" ]] || fail "Destination already exists: $destination"
    # A plan whose worktree went missing gets it back on its existing branch;
    # prune drops the registration a deleted directory leaves behind.
    git -C "$MAIN_ROOT" worktree prune
    if git -C "$MAIN_ROOT" show-ref --verify -q "refs/heads/$branch"; then
      git -C "$MAIN_ROOT" worktree add "$destination" "$branch" >&2
    else
      git -C "$MAIN_ROOT" worktree add "$destination" -b "$branch" "$parent" >&2
    fi
    printf '%s\n' "$destination" ;;
  link-deps)
    [[ $# -ge 2 ]] || fail 'link-deps requires a registered worktree.'
    registered_worktree "$2"
    shift 2
    [[ $# -gt 0 ]] || set -- node_modules vendor .venv venv Pods
    for dep in "$@"; do valid_name "$dep"; done
    for dep in "$@"; do
      if [[ -d "$MAIN_ROOT/$dep" && ! -e "$WORKTREE_PATH/$dep" && ! -L "$WORKTREE_PATH/$dep" ]]; then
        ln -s -- "$MAIN_ROOT/$dep" "$WORKTREE_PATH/$dep"
      fi
    done ;;
  isolate-dep)
    [[ $# -eq 3 ]] || fail 'isolate-dep requires a registered worktree and a dependency name.'
    registered_worktree "$2"
    valid_name "$3"
    dependency="$WORKTREE_PATH/$3"
    if [[ -L "$dependency" ]]; then
      # Unlink only the directory entry; never traverse into the shared target.
      unlink -- "$dependency"
    elif [[ -e "$dependency" && ! -d "$dependency" ]]; then
      fail "Dependency path is not a directory: $dependency"
    fi
    mkdir -p -- "$dependency"
    [[ -d "$dependency" && ! -L "$dependency" ]] || fail 'Dependency isolation failed.' ;;
  remove)
    [[ $# -eq 2 ]] || fail 'remove requires a registered worktree.'
    registered_worktree "$2"
    branch=$(git -C "$WORKTREE_PATH" symbolic-ref --quiet --short HEAD) || fail 'Worktree HEAD is detached; its branch cannot be identified.'
    # Unlink the dependency links link-deps made, so an unignored link does not
    # block removal; their main-root targets stay.
    for entry in "$WORKTREE_PATH"/* "$WORKTREE_PATH"/.[!.]*; do
      if [[ -L "$entry" && "$(readlink -- "$entry")" == "$MAIN_ROOT/$(basename -- "$entry")" ]]; then unlink -- "$entry"; fi
    done
    [[ -z "$(git -C "$WORKTREE_PATH" status --porcelain --untracked-files=all)" ]] || fail "Worktree has uncommitted or untracked changes: $WORKTREE_PATH"
    git -C "$MAIN_ROOT" worktree remove "$WORKTREE_PATH" >&2
    # Delete the branch only when a fresh fetch shows origin at the same tip, so
    # no unpushed commit is lost. A failed fetch keeps it rather than trusting a
    # stale tracking ref. -d would refuse a branch not merged into the root's HEAD.
    if ! git -C "$MAIN_ROOT" fetch --quiet origin "+refs/heads/$branch:refs/remotes/origin/$branch" 2>/dev/null; then
      printf 'Cannot fetch origin/%s (never pushed, deleted on origin, or origin unreachable); keeping the branch.\n' "$branch" >&2
      printf 'kept %s\n' "$branch"
    elif [[ "$(git -C "$MAIN_ROOT" rev-parse --verify "refs/heads/$branch")" != "$(git -C "$MAIN_ROOT" rev-parse --verify "refs/remotes/origin/$branch")" ]]; then
      printf 'Local %s differs from origin/%s; keeping the branch.\n' "$branch" "$branch" >&2
      printf 'kept %s\n' "$branch"
    else
      git -C "$MAIN_ROOT" branch -D "$branch" >&2
      printf 'deleted %s\n' "$branch"
    fi ;;
  *) usage >&2; exit 2 ;;
esac
