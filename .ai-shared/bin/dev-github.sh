#!/usr/bin/env bash
# Creation commands only. The owning phase supplies consent, auth checks,
# reviewed scope, duplicate-PR checks, and publication/archival sequencing.
set -euo pipefail
fail() { printf '%s\n' "$*" >&2; exit 1; }
usage() {
  printf '%s\n' \
    'Usage: dev-github.sh issue-create <title> <body-file> [gh issue create options ...]' \
    '       dev-github.sh pr-create <title> <body-file> <parent> [--ready]' \
    'Uses gh current repository and configured credentials. PRs default to draft.' \
    'Creates external records; run only after the owning phase authorization and preflight.'
}
[[ "${1-}" != --help && "${1-}" != -h ]] || { usage; exit 0; }
case "${1-}" in
  issue-create|pr-create) ;;
  *) usage >&2; exit 2 ;;
esac
[[ $# -ge 3 && -n "$2" && -f "$3" && -r "$3" ]] || fail 'A nonempty title and readable body file are required.'
action="$1"; title="$2"; body="$3"
shift 3
case "$action" in
  issue-create) exec gh issue create --title "$title" --body-file "$body" "$@" ;;
  pr-create)
    [[ $# -eq 1 || ( $# -eq 2 && "$2" == --ready ) ]] || fail 'pr-create requires an explicit parent and optional --ready.'
    [[ -n "$1" ]] || fail 'A nonempty parent is required.'
    flags=(--draft)
    [[ $# -eq 1 ]] || flags=()
    exec gh pr create --title "$title" --body-file "$body" --base "$1" "${flags[@]}" ;;
esac
