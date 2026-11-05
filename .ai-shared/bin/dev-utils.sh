#!/usr/bin/env bash
# Mechanics shared by dev phase skills and gate-check.sh. Every command is
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
    '       dev-utils.sh recent-issues [days]' \
    '       dev-utils.sh recent-prs [days]' \
    'Paths/refs are printed on stdout; errors go to stderr.' \
    'recent-issues and recent-prs list 7 days back by default, newest first, at most 100.' \
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

# gh rows listed; one more is fetched so a truncated window is detectable.
LIST_LIMIT=100

# The ISO date <days> days ago; fails unless <days> is a whole number. GNU date
# first, then BSD, so the command is not Linux-only.
since_days() {
  [[ "$1" =~ ^[0-9]+$ ]] || fail "Need a whole number of days, got '$1'."
  date -I -d "$1 days ago" 2>/dev/null || date -v-"${1}"d +%F 2>/dev/null \
    || fail "Cannot resolve $1 days ago: the count is too large, or date supports neither GNU -d nor BSD -v."
}

# The table step cannot run without column; callers also call it before a
# listing, so a missing tool costs no API request.
needs_column() { command -v column >/dev/null || fail 'An aligned table needs column (util-linux or BSD).'; }

# <header-tsv> and <body-tsv> as a column-aligned table on stdout.
aligned() { needs_column; printf '%s\n%s\n' "$1" "$2" | column -t -s $'\t'; }

# <rows> trimmed to $LIST_LIMIT, announced on stderr only when that trimming
# hid a match, so a complete window is never reported as truncated.
trim_cap() {
  local rows=$1
  if [[ "$(printf '%s\n' "$rows" | wc -l)" -gt "$LIST_LIMIT" ]]; then
    printf 'Only the newest %s are shown; older matches in this window are hidden.\n' "$LIST_LIMIT" >&2
    printf '%s\n' "$rows" | head -n "$LIST_LIMIT"
  else
    printf '%s\n' "$rows"
  fi
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
  recent-issues)
    [[ $# -le 2 ]] || fail 'recent-issues takes an optional number of days.'
    since=$(since_days "${2-7}")
    needs_column
    rows=$(gh issue list --assignee @me --search "created:>=$since sort:created-desc" --limit "$((LIST_LIMIT + 1))" \
             --json number,title,state,createdAt,labels \
             --jq '.[] | ["#\(.number)", .createdAt[:10], .state, ([(.labels // [])[].name] | join(", ")), .title] | @tsv') \
      || fail 'Cannot list assigned issues.'
    [[ -n "$rows" ]] || { printf 'No issues assigned to @me, created since %s.\n' "$since"; exit 0; }
    rows=$(trim_cap "$rows")
    printf 'Issues assigned to @me, created since %s:\n\n' "$since"
    aligned 'NUMBER	CREATED	STATE	LABELS	TITLE' "$rows" ;;
  recent-prs)
    [[ $# -le 2 ]] || fail 'recent-prs takes an optional number of days.'
    since=$(since_days "${2-7}")
    needs_column
    rows=$(gh pr list --author @me --search "created:>=$since sort:created-desc" --limit "$((LIST_LIMIT + 1))" \
             --json number,title,state,createdAt,isDraft,reviewDecision,statusCheckRollup \
             --jq '
  def bad: (.conclusion // .state // "") as $s
    | ["FAILURE","TIMED_OUT","CANCELLED","ACTION_REQUIRED","STARTUP_FAILURE","ERROR"] | index($s);
  def waiting: (.status // .state // "") as $s
    | ["QUEUED","IN_PROGRESS","PENDING","WAITING","REQUESTED","EXPECTED"] | index($s);
  def checks: if length == 0 then "none"
    elif any(.[]; bad) then "fail"
    elif any(.[]; waiting) then "pending"
    else "pass" end;
  def review: if . == null or . == "" then "-"
    elif . == "APPROVED" then "approved"
    elif . == "CHANGES_REQUESTED" then "changes"
    elif . == "REVIEW_REQUIRED" then "required"
    else ascii_downcase end;
  .[] | ["#\(.number)", .createdAt[:10], (if .isDraft then "DRAFT" else .state end),
         (.reviewDecision | review), (.statusCheckRollup // [] | checks), .title] | @tsv') \
      || fail 'Cannot list your pull requests.'
    [[ -n "$rows" ]] || { printf 'No pull requests you opened, created since %s.\n' "$since"; exit 0; }
    rows=$(trim_cap "$rows")
    printf 'Pull requests you opened, created since %s:\n\n' "$since"
    aligned 'NUMBER	CREATED	STATE	REVIEW	CHECKS	TITLE' "$rows" ;;
  --help|-h) usage ;;
  *) usage >&2; exit 2 ;;
esac
