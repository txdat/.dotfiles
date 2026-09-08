#!/usr/bin/env bash
# Main-agent-only worktree setup; never edits, copies, or removes a plan.
set -euo pipefail

SCRIPT_DIR=$(dirname -- "$(realpath -- "${BASH_SOURCE[0]}")")
fail() { printf '%s\n' "$*" >&2; exit 1; }
usage() {
  printf '%s\n' \
    'Usage: dev-worktree.sh create <slug> <branch> <parent> [worktree-directory]' \
    '       dev-worktree.sh link-deps <worktree> [dependency-name ...]' \
    '       dev-worktree.sh isolate-dep <worktree> <dependency-name>' \
    'create defaults to $HOME/work/ai-worktrees and prints the new path.' \
    'link-deps defaults to node_modules vendor .venv venv Pods.' \
    'Dependencies must be direct-child directory names. Existing local content is preserved.' \
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

case "$1" in
  create)
    [[ $# -eq 4 || $# -eq 5 ]] || fail 'create requires slug, branch, parent, and optional worktree-directory.'
    slug="$2"; branch="$3"; parent="$4"
    valid_name "$slug"
    git check-ref-format --branch "$branch" >/dev/null
    [[ -n "$parent" ]] || fail 'An explicit parent is required.'
    git -C "$MAIN_ROOT" rev-parse --verify --quiet --end-of-options "${parent}^{commit}" >/dev/null || fail "Parent does not resolve: $parent"
    destination=$(realpath -m -- "${5-$HOME/work/ai-worktrees}/$(basename -- "$MAIN_ROOT")-$slug")
    [[ "$destination/" != "$MAIN_ROOT/"* ]] || fail 'Worktrees must be outside the main working tree.'
    [[ ! -e "$destination" && ! -L "$destination" ]] || fail "Destination already exists: $destination"
    git -C "$MAIN_ROOT" worktree add "$destination" -b "$branch" "$parent" >&2
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
  *) usage >&2; exit 2 ;;
esac
