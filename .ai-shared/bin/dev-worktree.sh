#!/usr/bin/env bash
# Main-agent-only worktree setup and cleanup, except that a reviewer may run
# scratch-diff on its scratch; never edits, copies, or removes a plan.
set -euo pipefail

SCRIPT_DIR=$(dirname -- "$(realpath -- "${BASH_SOURCE[0]}")")
fail() { printf '%s\n' "$*" >&2; exit 1; }
usage() {
  printf '%s\n' \
    'Usage: dev-worktree.sh create <slug> <branch> <parent> [directory ...]' \
    '       dev-worktree.sh link-deps <worktree> [dependency-name ...]' \
    '       dev-worktree.sh isolate-dep <worktree> <dependency-name>' \
    '       dev-worktree.sh remove <worktree>' \
    '       dev-worktree.sh scratch <name> <ref> [patch ...]' \
    '       dev-worktree.sh scratch-diff <scratch> [-- <path> ...]' \
    '       dev-worktree.sh scratch-remove <scratch>' \
    'create makes <repo>-<slug> under $AI_WORKTREES_ROOT, or $HOME/work/wt, on <branch> from <parent>,' \
    'or on <branch> as it is when it exists, and prints the new path.' \
    'Directories make it a cone-mode sparse checkout of root files plus those repo-relative directories.' \
    'link-deps defaults to node_modules vendor .venv venv Pods.' \
    'Dependencies must be direct-child directory names. Existing local content is preserved.' \
    'remove unlinks link-deps links, deletes a clean worktree, then its local branch only when origin/<branch> has the same tip;' \
    'it prints "deleted <branch>" or "kept <branch>", with the reason for keeping on stderr.' \
    'scratch makes a detached <repo>-<name> under <worktrees root>/scratch at <ref>, applies the patches three-way' \
    '(removing it if one fails), links dependencies, and prints its path. scratch-diff prints the changes since <ref>,' \
    'new unignored files included, as a patch limited to the paths given; it omits dependency links, isolated' \
    'dependencies (default link-deps names <ref> does not track, including ones a patch created), and submodule changes.' \
    'A ref resolves where the command runs. scratch-remove deletes the scratch, never a link target.' \
    'Scratch commands refuse other worktrees; run them from inside the repository or a worktree, not a dependency link.' \
    'Requires the owning phase authorization; does not approve a plan or install dependencies.'
}

valid_name() {
  [[ "$1" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ || "$1" =~ ^\.[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]] || fail "Invalid directory name: $1"
}

# A repo-relative directory: valid names joined by single slashes. One anchored
# match over the whole argument, so no newline or other byte slips past it.
valid_dir() {
  local name='\.?[a-zA-Z0-9][a-zA-Z0-9._-]*'
  [[ "$1" =~ ^$name(/$name)*/?$ ]] || fail "Invalid directory: $1"
}

registered_worktree() {
  local requested="$1" listing
  [[ -d "$requested" ]] || fail "Worktree directory does not exist: $requested"
  WORKTREE_PATH=$(realpath -- "$requested")
  [[ "$WORKTREE_PATH" != "$MAIN_ROOT" ]] || fail 'Dependency operations may not target the main working tree.'
  listing=$(git -C "$MAIN_ROOT" worktree list --porcelain)
  [[ "$listing" == "worktree $WORKTREE_PATH"$'\n'* || "$listing" == *$'\n'"worktree $WORKTREE_PATH"$'\n'* ]] || fail 'Target is not a registered worktree.'
}

DEFAULT_DEPS=(node_modules vendor .venv venv Pods)

# Links each named dependency, by default DEFAULT_DEPS, that the main root has
# and worktree $1 lacks.
link_deps() {
  local worktree="$1" dep
  shift
  [[ $# -gt 0 ]] || set -- "${DEFAULT_DEPS[@]}"
  for dep in "$@"; do valid_name "$dep"; done
  for dep in "$@"; do
    if [[ -d "$MAIN_ROOT/$dep" && ! -e "$worktree/$dep" && ! -L "$worktree/$dep" ]]; then
      ln -s -- "$MAIN_ROOT/$dep" "$worktree/$dep"
    fi
  done
}

# Prints the dependency links link_deps made in worktree $1; remove unlinks them.
dep_links() {
  local entry
  for entry in "$1"/* "$1"/.[!.]*; do
    if [[ -L "$entry" && "$(readlink -- "$entry")" == "$MAIN_ROOT/$(basename -- "$entry")" ]]; then printf '%s\n' "$entry"; fi
  done
}

# A registered worktree under the scratch root with the base scratch recorded,
# so no scratch command reaches a plan's worktree or the main root.
scratch_worktree() {
  registered_worktree "$1"
  [[ "$WORKTREE_PATH" == "$SCRATCH_ROOT"/* ]] || fail "Not a scratch worktree: $WORKTREE_PATH"
  local base_file
  base_file="$(git -C "$WORKTREE_PATH" rev-parse --absolute-git-dir)/scratch-base"
  [[ -f "$base_file" ]] || fail "Scratch worktree has no recorded base: $WORKTREE_PATH"
  SCRATCH_BASE=$(<"$base_file")
}

[[ "${1-}" != --help && "${1-}" != -h ]] || { usage; exit 0; }
[[ $# -gt 0 ]] || { usage >&2; exit 2; }
MAIN_ROOT=$(bash "$SCRIPT_DIR/dev-utils.sh" main-root)
REPO_ROOT="$MAIN_ROOT"
. "$SCRIPT_DIR/dev-plan-lib.sh"
SCRATCH_ROOT="$WORKTREES_ROOT/scratch"

case "$1" in
  create)
    [[ $# -ge 4 ]] || fail 'create requires slug, branch, and parent.'
    slug="$2"; branch="$3"; parent="$4"
    shift 4
    valid_name "$slug"
    for dir in "$@"; do valid_dir "$dir"; done
    git check-ref-format --branch "$branch" >/dev/null
    [[ -n "$parent" ]] || fail 'An explicit parent is required.'
    git -C "$MAIN_ROOT" rev-parse --verify --quiet --end-of-options "${parent}^{commit}" >/dev/null || fail "Parent does not resolve: $parent"
    destination=$(worktree_path "$slug")
    [[ "$destination/" != "$MAIN_ROOT/"* ]] || fail 'Worktrees must be outside the main working tree.'
    [[ ! -e "$destination" && ! -L "$destination" ]] || fail "Destination already exists: $destination"
    # A plan whose worktree went missing gets it back on its existing branch;
    # prune drops the registration a deleted directory leaves behind.
    git -C "$MAIN_ROOT" worktree prune
    # Sparse: check out only after the cone is set. Git turns on the shared
    # extensions.worktreeConfig and keeps the cone in this worktree's config, so
    # the main root stays a full checkout.
    add=(git -C "$MAIN_ROOT" worktree add); [[ $# -eq 0 ]] || add+=(--no-checkout)
    created=""
    if git -C "$MAIN_ROOT" show-ref --verify -q "refs/heads/$branch"; then
      "${add[@]}" "$destination" "$branch" >&2
    else
      created=$(git -C "$MAIN_ROOT" rev-parse "${parent}^{commit}")
      "${add[@]}" "$destination" -b "$branch" "$parent" >&2
    fi
    if [[ $# -gt 0 ]] && ! { git -C "$destination" sparse-checkout set --cone -- "$@" >&2 && git -C "$destination" checkout >&2; }; then
      # Nothing is checked out yet. Undo the worktree and any branch made here,
      # which the gates would otherwise take as this plan's or its parent's.
      git -C "$MAIN_ROOT" worktree remove --force "$destination" >&2
      [[ -z "$created" ]] || git -C "$MAIN_ROOT" update-ref -d "refs/heads/$branch" "$created"
      fail "Sparse checkout failed; removed $destination${created:+ and branch $branch}."
    fi
    printf '%s\n' "$destination" ;;
  link-deps)
    [[ $# -ge 2 ]] || fail 'link-deps requires a registered worktree.'
    registered_worktree "$2"
    shift 2
    link_deps "$WORKTREE_PATH" "$@" ;;
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
    # An unignored dependency link would otherwise block removal; its
    # main-root target stays.
    while IFS= read -r entry; do unlink -- "$entry"; done < <(dep_links "$WORKTREE_PATH")
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
  scratch)
    [[ $# -ge 3 ]] || fail 'scratch requires a name, a ref, and optional patches.'
    valid_name "$2"
    # Resolved where the caller runs, so HEAD in a worktree is that worktree's.
    base=$(git rev-parse --verify --quiet --end-of-options "${3}^{commit}") || fail "Ref does not resolve: $3"
    name="$2"; ref="$3"; patches=()
    shift 3
    for patch in "$@"; do [[ -f "$patch" ]] || fail "Patch does not exist: $patch"; patches+=("$(realpath -- "$patch")"); done
    destination="$SCRATCH_ROOT/${MAIN_ROOT##*/}-$name"
    [[ "$destination/" != "$MAIN_ROOT/"* ]] || fail 'Scratch worktrees must be outside the main working tree.'
    [[ ! -e "$destination" && ! -L "$destination" ]] || fail "Scratch worktree already exists: $destination"
    # A scratch deleted by hand leaves a registration that would block this path.
    git -C "$MAIN_ROOT" worktree prune
    mkdir -p -- "$SCRATCH_ROOT"
    git -C "$MAIN_ROOT" worktree add --detach "$destination" "$base" >&2
    printf '%s\n' "$base" > "$(git -C "$destination" rev-parse --absolute-git-dir)/scratch-base"
    # Patches go in before the links, so none writes through one into the main
    # root; three-way, so a repro whose test the ref already has still applies.
    for patch in ${patches[@]+"${patches[@]}"}; do
      if [[ -s "$patch" ]] && ! git -C "$destination" apply --3way --binary --whitespace=nowarn -- "$patch" >&2; then
        git -C "$MAIN_ROOT" worktree remove --force "$destination" >&2
        fail "Patch does not apply at $ref: $patch; removed $destination."
      fi
    done
    link_deps "$destination"
    printf '%s\n' "$destination" ;;
  scratch-diff)
    [[ $# -ge 2 ]] || fail 'scratch-diff requires a scratch worktree.'
    scratch_worktree "$2"
    shift 2
    if [[ $# -gt 0 ]]; then [[ "$1" == -- && $# -gt 1 ]] || fail 'Paths follow --.'; shift; fi
    # A private index from the base, so the scratch's own index stays as it is
    # and the patch holds the paths asked for; plumbing ignores diff config.
    index=$(mktemp)
    trap 'rm -f -- "$index"' EXIT
    GIT_INDEX_FILE="$index" git -C "$WORKTREE_PATH" read-tree "$SCRATCH_BASE"
    if [[ $# -gt 0 ]]; then GIT_INDEX_FILE="$index" git -C "$WORKTREE_PATH" add -A -- "$@"; else GIT_INDEX_FILE="$index" git -C "$WORKTREE_PATH" add -A; fi
    for dep in "${DEFAULT_DEPS[@]}"; do
      if [[ -z "$(git -C "$WORKTREE_PATH" ls-tree --name-only "$SCRATCH_BASE" -- "$dep")" ]]; then
        GIT_INDEX_FILE="$index" git -C "$WORKTREE_PATH" rm -r -q --cached --ignore-unmatch -- "$dep"
      fi
    done
    GIT_INDEX_FILE="$index" git -C "$WORKTREE_PATH" diff-index --cached -p --binary "$SCRATCH_BASE" ;;
  scratch-remove)
    [[ $# -eq 2 ]] || fail 'scratch-remove requires a scratch worktree.'
    scratch_worktree "$2"
    # Forced removal deletes dependency links without following them.
    git -C "$MAIN_ROOT" worktree remove --force "$WORKTREE_PATH" >&2 ;;
  *) usage >&2; exit 2 ;;
esac
