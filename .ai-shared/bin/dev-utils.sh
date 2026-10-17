#!/usr/bin/env bash
# Mechanics shared by dev phase skills and gate-check. Every command is
# read-only except issue-create, the only one that creates an external record;
# run it only after the owning phase's authorization.
set -euo pipefail

fail() { printf '%s\n' "$*" >&2; exit 1; }
usage() {
  printf '%s\n' \
    'Usage: dev-utils.sh main-root' \
    '       dev-utils.sh diagnostic-base' \
    '       dev-utils.sh search-production <literal-symbol> [directory]' \
    '       dev-utils.sh issue-create <title> <body-file> [gh issue create options ...]' \
    'Paths/refs are printed on stdout; errors go to stderr.' \
    'search-production preserves rg status: 0 matches, 1 none, 2 error.'
}

main_root() {
  local listing root
  listing=$(git worktree list --porcelain) || fail 'Cannot resolve the main working-tree root.'
  root=${listing%%$'\n'*}
  [[ "$root" == 'worktree '* ]] || fail 'Cannot resolve the main working-tree root.'
  root=${root#worktree }
  [[ -n "$root" && -d "$root" ]] || fail 'Cannot resolve an existing main working-tree root.'
  [[ "$(git -C "$root" rev-parse --is-inside-work-tree)" == true ]] || fail 'The main repository has no working tree.'
  printf '%s\n' "$root"
}

diagnostic_base() {
  local diagnostic_default diagnostic_ref
  diagnostic_default=$(git symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null) || diagnostic_default=
  for diagnostic_ref in "$diagnostic_default" refs/heads/main refs/remotes/origin/main; do
    [[ -n "$diagnostic_ref" ]] || continue
    if git rev-parse --verify --quiet "${diagnostic_ref}^{commit}" >/dev/null; then
      printf '%s\n' "$diagnostic_ref"
      return 0
    fi
  done
  fail 'Cannot resolve a diagnostic base; provide an existing branch or commit.'
}

case "${1-}" in
  main-root)
    [[ $# -eq 1 ]] || fail 'main-root takes no arguments.'
    main_root ;;
  diagnostic-base)
    [[ $# -eq 1 ]] || fail 'diagnostic-base takes no arguments.'
    diagnostic_base ;;
  search-production)
    [[ $# -ge 2 && $# -le 3 && -n "$2" ]] || fail 'search-production requires a literal symbol and optional directory.'
    exec rg -n -F -g '!**/{test,tests,spec,specs,__tests__}/**' \
      -g '!**/*_test.*' -g '!**/*_spec.*' -g '!**/*.test.*' -g '!**/*.spec.*' \
      -- "$2" "${3-.}" ;;
  issue-create)
    [[ $# -ge 3 && -n "$2" && -f "$3" && -r "$3" ]] || fail 'issue-create requires a nonempty title and a readable body file.'
    title="$2"; body="$3"; shift 3
    exec gh issue create --title "$title" --body-file "$body" "$@" ;;
  --help|-h) usage ;;
  *) usage >&2; exit 2 ;;
esac
