#!/usr/bin/env bash
# Publication checks for create-pr (../skills/dev/create-pr.md): slice and
# Green checks, the plan archive commit, PR verification, and cleanup.
#
# The main agent alone runs it. The create-pr gate (gate-check) owns entry:
# reviewed status and an active worktree. The agent pushes and opens the PRs
# and owns their titles and bodies, the sensitive-content read of the plan,
# and the ignored-file check. This script never merges, retargets,
# force-pushes, or rewrites branches; every command rechecks state, so a
# failed run can be repeated. PLAN_NAME_RE, field, plan_rows, and stacks_on
# mirror gate-check's PLAN_NAME_RE, field, plan_parents, and stacks_on; change
# both together.
set -euo pipefail

SCRIPT_DIR=$(dirname -- "$(realpath -- "${BASH_SOURCE[0]}")")
fail() { printf '%s\n' "$*" >&2; exit 1; }
usage() {
  printf '%s\n' \
    'Usage: dev-publish.sh stack <root plan>' \
    '       dev-publish.sh check <plan>' \
    '       dev-publish.sh archive <plan>' \
    '       dev-publish.sh verify <plan>' \
    '       dev-publish.sh cleanup <plan> [--ignored-checked]' \
    '<plan> is docs/plans/<issue>_<type>_<slug>.spec.md under the main working tree.' \
    'Exit: 0 ok, 1 failure, 2 usage, 4 confirmation needed (cleanup).'
}

# ── plan reading ──────────────────────────────────────────────────────

PLAN_NAME_RE='^docs/plans/[0-9]+_(feature|fix|refactor)_[a-z0-9-]+\.spec\.md$'

load_plan() {
  [[ "$1" =~ $PLAN_NAME_RE ]] ||
    fail "Plan must be docs/plans/<issue>_<type>_<slug>.spec.md: $1"
  PLAN_REL="$1"
  PLAN_FILE="$MAIN_ROOT/$PLAN_REL"
  PLAN_STEM=$(basename -- "$PLAN_REL" .spec.md)
}

require_live_plan() {
  [[ -f "$PLAN_FILE" && ! -L "$PLAN_FILE" ]] || fail "Live plan not found: $PLAN_FILE"
  ! is_tracked "$PLAN_REL" ||
    fail "$PLAN_REL is tracked by Git, a published record; a live plan is untracked."
}

# One field of the Status line, such as Base or Worktree.
field() {
  awk -v key="$2" '
    /^Status:/ {
      n = split($0, f, /\|/)
      for (i = 1; i <= n; i++) {
        x = f[i]; gsub(/^[[:space:]]+|[[:space:]]+$/, "", x)
        if (index(x, key ":") == 1) { sub("^" key ":[[:space:]]*", "", x); print x; exit }
      }
      exit
    }' "$1"
}

# PR Pattern rows as "PR-n<TAB>branch<TAB>parent", in table order.
plan_rows() {
  awk -F'|' '
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    /^## PR Pattern[[:space:]]*$/ { inp = 1; next }
    /^## / && inp { exit }
    inp && /^\|/ {
      if (trim($2) ~ /^PR-[1-9][0-9]*$/) {
        if (!bcol || !pcol) { print "!no Branch or Parent column"; exit }
        print trim($2) "\t" trim($bcol) "\t" trim($pcol)
        next
      }
      for (i = 2; i <= NF; i++) { c = trim($i); if (c == "Branch") bcol = i; if (c == "Parent") pcol = i }
    }' "$PLAN_FILE"
}

load_rows() {
  local line pr branch parent
  ROW_PR=(); ROW_BRANCH=(); ROW_PARENT=()
  while IFS= read -r line; do
    [[ "$line" != '!'* ]] || fail "PR Pattern in $PLAN_REL: ${line#!}"
    IFS=$'\t' read -r pr branch parent <<<"$line"
    [[ -n "$branch" && -n "$parent" ]] || fail "$pr in $PLAN_REL needs a Branch and a Parent."
    ROW_PR+=("$pr"); ROW_BRANCH+=("$branch"); ROW_PARENT+=("$parent")
  done < <(plan_rows)
  [[ ${#ROW_PR[@]} -gt 0 ]] || fail "No PR-n rows under ## PR Pattern in $PLAN_REL."
  LAST=$(( ${#ROW_PR[@]} - 1 ))
  BASE=$(field "$PLAN_FILE" Base)
  [[ -n "$BASE" ]] || fail "Plan header has no Base."
  WT=$(field "$PLAN_FILE" Worktree)
}

# Green: PR-n (<branch>) at <sha>, recorded by review-code.
green_sha() {
  local rec
  rec=$(sed -nE "s/^[[:space:]]*([-*][[:space:]]*)?Green: $1 \\(([^)]*)\\) at ([0-9a-f]{7,40}).*/\\2 \\3/p" "$PLAN_FILE" | tail -1)
  [[ -n "$rec" ]] || return 1
  [[ "${rec% *}" == "$2" ]] || fail "Green record for $1 names branch ${rec% *}, not $2."
  git_root rev-parse --verify --quiet "${rec#* }^{commit}"
}

# The plan with its Status-line Worktree field emptied; other fields stay.
clear_worktree() {
  awk '
    !done && /^Status:/ {
      if (!sub(/Worktree:[^|]*\|/, "Worktree: |")) sub(/Worktree:[^|]*$/, "Worktree:")
      done = 1
    }
    { print }' "$1"
}

# Whether revision $1 holds the archived plan: reviewed, with an empty Worktree.
is_plan_copy() {
  local copy
  copy=$(git_root show "$1:$PLAN_REL" 2>/dev/null) || return 1
  [[ "$(field <(printf '%s\n' "$copy") Status)" == reviewed &&
     -z "$(field <(printf '%s\n' "$copy") Worktree)" ]]
}

# The header 'Stacks On:' plan of plan file $1, if any. The create-pr gate
# already rejected malformed lines, so this reads only the well-formed one.
stacks_on() {
  awk '/^[[:space:]]*(```|~~~)/ { fenced = !fenced; next }
    fenced { next }
    /^## / { exit }
    /^Stacks On:/ { print; exit }' "$1" | grep -oE "${PLAN_NAME_RE:1:-1}" | head -1 || true
}

# Live plans whose 'Stacks On:' names plan $1.
child_plans() {
  local f rel
  for f in "$MAIN_ROOT"/docs/plans/*.spec.md; do
    rel=${f#"$MAIN_ROOT"/}
    [[ -f "$f" && ! -L "$f" ]] && ! is_tracked "$rel" || continue
    [[ "$(stacks_on "$f")" != "$1" ]] || printf '%s\n' "$rel"
  done
}

is_tracked() { git_root ls-files --error-unmatch -- "$1" >/dev/null 2>&1 || git_root cat-file -e "HEAD:$1" 2>/dev/null; }

archive_message() { printf 'docs(plan): archive %s\n' "$PLAN_STEM"; }

# ── git and GitHub state ──────────────────────────────────────────────

git_root() { git -C "$MAIN_ROOT" "$@"; }
gh_root() { (cd "$MAIN_ROOT" && gh "$@"); }

fetch_origin() { git_root fetch --quiet --prune origin || fail 'Cannot fetch origin.'; }

ref_sha() {
  git_root rev-parse --verify --quiet "refs/heads/$1^{commit}" ||
    git_root rev-parse --verify --quiet "refs/remotes/origin/$1^{commit}"
}
origin_sha() { git_root rev-parse --verify --quiet "refs/remotes/origin/$1^{commit}"; }
local_sha() { git_root rev-parse --verify --quiet "refs/heads/$1^{commit}"; }
is_ancestor() { git_root cat-file -e "$1^{commit}" 2>/dev/null && git_root merge-base --is-ancestor "$1" "$2"; }

# PRs for a head branch as JSON; gh's state filter (open or all).
prs_for() { gh_root pr list --head "$1" --state "$2" --json number,url,state,baseRefName,headRefOid,body; }

# Sets RES_SHA for row $1's recorded Parent.
resolve_parent() {
  if [[ "${ROW_PARENT[$1]}" == "$BASE" ]]; then
    RES_SHA=$(origin_sha "$BASE" || ref_sha "$BASE") || fail "Base $BASE resolves neither locally nor on origin."
  else
    RES_SHA=$(ref_sha "${ROW_PARENT[$1]}") || fail "Parent ${ROW_PARENT[$1]} of ${ROW_PR[$1]} resolves neither locally nor on origin."
  fi
}

# Paths changed by the commits in $1..$2.
commit_paths() { git_root log --format= --name-only "$1..$2" | sed '/^$/d' | sort -u; }

# True when slice tip $2 contains its Parent $1, or lacks only plan files: the
# parent plan's archive commit lands on its last slice after a stacked plan
# branched from it. A tree diff without rename detection, so neither a merge nor a
# rename into docs/plans/ hides a code change.
contains_parent() {
  local mb paths
  is_ancestor "$1" "$2" && return 0
  mb=$(git_root merge-base "$1" "$2") || return 1
  paths=$(git_root diff --no-renames --name-only "$mb" "$1")
  [[ -n "$paths" ]] && ! grep -qvxE "$PLAN_NAME_RE" <<<"$paths"
}

# The final slice tip may carry the archive commit above its Green SHA.
tip_matches_green() {
  [[ "$1" == "$2" ]] && return 0
  [[ "$3" -eq "$LAST" ]] && is_ancestor "$1" "$2" && [[ "$(commit_paths "$1" "$2")" == "$PLAN_REL" ]]
}

require_worktree() {
  [[ -n "$WT" && -d "$WT" ]] || fail "Plan has no existing Worktree recorded."
  [[ "$(git -C "$WT" symbolic-ref --quiet --short HEAD)" == "${ROW_BRANCH[$LAST]}" ]] ||
    fail "Worktree $WT is not on the final slice ${ROW_BRANCH[$LAST]}; switch to it first."
}

# ── commands ──────────────────────────────────────────────────────────

# The root, then every plan stacked on it, parents before children.
cmd_stack() {
  local parent queue=("$PLAN_REL") cur child
  parent=$(stacks_on "$PLAN_FILE")
  [[ -z "$parent" ]] || fail "$PLAN_REL stacks on $parent; pass the stack's root."
  while (( ${#queue[@]} > 0 )); do
    cur="${queue[0]}"; queue=("${queue[@]:1}")
    printf '%s\n' "$cur"
    while IFS= read -r child; do queue+=("$child"); done < <(child_plans "$cur")
  done
}

cmd_check() {
  local i pr branch tip green parent_sha prs n problems=()
  fetch_origin
  for i in "${!ROW_PR[@]}"; do
    pr="${ROW_PR[$i]}"; branch="${ROW_BRANCH[$i]}"
    resolve_parent "$i"
    tip=$(ref_sha "$branch") || { problems+=("$pr: branch $branch does not resolve"); continue; }
    if [[ "${ROW_PARENT[$i]}" != "$BASE" ]] && ! contains_parent "$RES_SHA" "$tip"; then
      problems+=("$pr: $branch does not contain its Parent ${ROW_PARENT[$i]}")
    fi
    parent_sha=$(git_root merge-base "$RES_SHA" "$tip") || { problems+=("$pr: no merge base with ${ROW_PARENT[$i]}"); continue; }
    if ! green=$(green_sha "$pr" "$branch"); then
      problems+=("$pr: no Green: $pr ($branch) at <sha> record")
    else
      tip_matches_green "$green" "$tip" "$i" ||
        problems+=("$pr: tip $tip differs from Green $green by more than the plan archive; changed code returns to review")
      if git_root diff --quiet "$parent_sha" "$green"; then problems+=("$pr: empty diff from ${ROW_PARENT[$i]}"); fi
      (cd "$MAIN_ROOT" && bash "$SCRIPT_DIR/dev-check" artifacts "$parent_sha" "$green") >/dev/null 2>&1 ||
        problems+=("$pr: conflict markers; run dev-check artifacts $parent_sha $green")
    fi
    prs=$(prs_for "$branch" all)
    # An open PR from an earlier run is this slice's own when it targets the
    # recorded Parent; a repair moves the tip ahead of it until the push.
    n=$(jq --arg b "${ROW_PARENT[$i]}" \
      '[.[] | select(.state == "OPEN" and .baseRefName != $b)] | length' <<<"$prs")
    [[ "$n" -eq 0 ]] || problems+=("$pr: $branch has an open PR not based on ${ROW_PARENT[$i]}")
    printf '%s\t%s\tbase=%s\tparent=%s\ttip=%s\n' "$pr" "$branch" "${ROW_PARENT[$i]}" "$parent_sha" "$tip"
  done
  if [[ ${#problems[@]} -gt 0 ]]; then printf 'BLOCK %s\n' "${problems[@]}" >&2; exit 1; fi
  printf 'PASS check %s\n' "$PLAN_REL"
}

# A rerun, such as after a repair, refreshes this plan's own earlier copy.
cmd_archive() {
  require_worktree
  [[ -z "$(git -C "$WT" status --porcelain --untracked-files=all)" ]] || fail "Worktree $WT is not clean."
  ! git -C "$WT" cat-file -e "HEAD:$PLAN_REL" 2>/dev/null ||
    [[ "$(git -C "$WT" log -1 --format=%s -- "$PLAN_REL")" == "$(archive_message)" ]] ||
    fail "A published plan already occupies $PLAN_REL in $WT; resolve the path collision."
  mkdir -p -- "$(dirname -- "$WT/$PLAN_REL")"
  clear_worktree "$PLAN_FILE" > "$WT/$PLAN_REL"
  git -C "$WT" add -f -- "$PLAN_REL"
  if git -C "$WT" diff --cached --quiet; then
    printf 'PASS archive already committed at %s\n' "$(git -C "$WT" rev-parse HEAD)"; return 0
  fi
  git -C "$WT" commit --quiet -m "$(archive_message)"
  printf 'PASS archive committed at %s\n' "$(git -C "$WT" rev-parse HEAD)"
}

# Collects problems into VERIFY_PROBLEMS; prints one line per verified PR.
verify_publication() {
  local i pr branch prs n url base oid num body tip origin_tip j green link_sha urls=() nums=()
  VERIFY_PROBLEMS=()
  fetch_origin
  for i in "${!ROW_PR[@]}"; do
    pr="${ROW_PR[$i]}"; branch="${ROW_BRANCH[$i]}"
    prs=$(prs_for "$branch" open)
    n=$(jq length <<<"$prs")
    if [[ "$n" -ne 1 ]]; then VERIFY_PROBLEMS+=("$pr: expected one open PR for $branch, found $n"); urls+=(""); nums+=(""); continue; fi
    IFS=$'\t' read -r url base oid num < <(jq -r '.[0] | [.url, .baseRefName, .headRefOid, (.number|tostring)] | @tsv' <<<"$prs")
    body=$(jq -r '.[0].body' <<<"$prs")
    urls+=("$url"); nums+=("$num")
    [[ "$base" == "${ROW_PARENT[$i]}" ]] || VERIFY_PROBLEMS+=("$pr: PR base is $base, expected ${ROW_PARENT[$i]}")
    origin_tip=$(origin_sha "$branch" || true)
    tip=$(local_sha "$branch" || printf '%s' "$origin_tip")
    [[ -n "$origin_tip" && "$oid" == "$origin_tip" && "$tip" == "$origin_tip" ]] ||
      VERIFY_PROBLEMS+=("$pr: PR head, origin, and local tip of $branch differ")
    if green=$(green_sha "$pr" "$branch"); then
      [[ -z "$origin_tip" ]] || tip_matches_green "$green" "$origin_tip" "$i" ||
        VERIFY_PROBLEMS+=("$pr: origin/$branch differs from Green $green by more than the plan archive")
    else
      VERIFY_PROBLEMS+=("$pr: no Green record")
    fi
    for (( j = 0; j < i; j++ )); do
      # A link must not continue with a digit: #1 and .../pull/1 are not #12.
      [[ -z "${urls[$j]}" || "$body" == *"${urls[$j]}" || "$body" == *"${urls[$j]}"[^0-9]* ||
         "$body" == *"#${nums[$j]}" || "$body" == *"#${nums[$j]}"[^0-9]* ]] ||
        VERIFY_PROBLEMS+=("$pr: body does not link earlier ${ROW_PR[$j]}")
    done
    if [[ "$i" -eq "$LAST" && -n "$origin_tip" ]]; then
      is_plan_copy "$origin_tip" ||
        VERIFY_PROBLEMS+=("$pr: $PLAN_REL at origin/$branch is not a reviewed plan copy with an empty Worktree")
      link_sha=$(grep -oE "/blob/[0-9a-f]{40}/$PLAN_REL" <<<"$body" | head -1 | cut -d/ -f3 || true)
      if [[ -z "$link_sha" ]]; then
        VERIFY_PROBLEMS+=("$pr: body has no immutable /blob/<sha>/$PLAN_REL plan link")
      elif ! is_ancestor "$link_sha" "$origin_tip" || ! is_plan_copy "$link_sha"; then
        VERIFY_PROBLEMS+=("$pr: plan link $link_sha is not the plan copy on $branch")
      elif ! git_root diff --quiet "$link_sha" "$origin_tip" -- "$PLAN_REL"; then
        VERIFY_PROBLEMS+=("$pr: plan link $link_sha is not the latest plan copy on $branch; update the PR body")
      fi
    fi
    printf '%s\t%s\t%s\n' "$pr" "$url" "$base"
  done
}

cmd_verify() {
  verify_publication
  if [[ ${#VERIFY_PROBLEMS[@]} -gt 0 ]]; then printf 'BLOCK %s\n' "${VERIFY_PROBLEMS[@]}" >&2; exit 1; fi
  printf 'PASS verify %s\n' "$PLAN_REL"
}

cmd_cleanup() {
  local checked="$1" i branch out ignored children problems=()
  children=$(child_plans "$PLAN_REL")
  [[ -z "$children" ]] || fail "Live plans stack on $PLAN_REL: ${children//$'\n'/ }. Clean them up first, children before parents."
  verify_publication >/dev/null
  if [[ ${#VERIFY_PROBLEMS[@]} -gt 0 ]]; then printf 'BLOCK %s\n' "${VERIFY_PROBLEMS[@]}" >&2; fail 'Publication is not verified; cleanup keeps everything.'; fi
  if [[ -n "$WT" && -d "$WT" ]]; then
    # Removal deletes ignored content unseen, so it is shown first for the
    # agent to check for unrelated files.
    if [[ "$checked" != 1 ]]; then
      ignored=$(git -C "$WT" status --porcelain --ignored --untracked-files=normal | sed -n 's/^!! //p')
      if [[ -n "$ignored" ]]; then
        printf 'IGNORED in %s:\n%s\n' "$WT" "$ignored"
        printf 'Check the ignored content above for unrelated files, then rerun: dev-publish.sh cleanup %s --ignored-checked\n' "$PLAN_REL" >&2
        exit 4
      fi
    fi
    out=$(bash "$SCRIPT_DIR/dev-worktree.sh" remove "$WT" 2>&1 | tail -1) || fail "Worktree removal failed: $out"
    printf 'WORKTREE removed %s; %s\n' "$WT" "$out"
  elif [[ -n "$WT" ]]; then
    printf 'WORKTREE already absent %s\n' "$WT"
  fi
  # dev-worktree.sh removes only the checked-out branch. verify fetched origin,
  # so a branch at origin's tip has nothing unpushed.
  for i in "${!ROW_PR[@]}"; do
    branch="${ROW_BRANCH[$i]}"
    local_sha "$branch" >/dev/null || continue
    if [[ "$(local_sha "$branch")" == "$(origin_sha "$branch" || true)" ]]; then
      git_root branch -q -D "$branch"
      printf '%s\tdeleted %s\n' "${ROW_PR[$i]}" "$branch"
    else
      problems+=("${ROW_PR[$i]}: local $branch differs from origin; kept")
    fi
  done
  if [[ ${#problems[@]} -gt 0 ]]; then printf 'BLOCK %s\n' "${problems[@]}" >&2; fail 'Cleanup stopped; the live plan is kept.'; fi
  rm -- "$PLAN_FILE"
  printf 'PASS cleanup %s; live plan deleted\n' "$PLAN_REL"
}

# ── dispatch ──────────────────────────────────────────────────────────

[[ "${1-}" != --help && "${1-}" != -h ]] || { usage; exit 0; }
[[ $# -ge 2 ]] || { usage >&2; exit 2; }
command -v jq >/dev/null || fail 'jq is required.'
MAIN_ROOT=$(bash "$SCRIPT_DIR/dev-utils.sh" main-root)

case "$1" in
  stack)
    [[ $# -eq 2 ]] || { usage >&2; exit 2; }
    load_plan "$2"; require_live_plan; cmd_stack ;;
  check|archive|verify)
    [[ $# -eq 2 ]] || { usage >&2; exit 2; }
    load_plan "$2"; require_live_plan; load_rows; "cmd_$1" ;;
  cleanup)
    [[ $# -eq 2 || ( $# -eq 3 && "$3" == --ignored-checked ) ]] || { usage >&2; exit 2; }
    load_plan "$2"
    if [[ ! -e "$PLAN_FILE" ]]; then
      # A cleaned-up plan's path has an archive commit; a wrong path has none
      # (a reused plan name also passes).
      [[ -n "$(git_root log --all -1 --format=%H -- "$PLAN_REL")" ]] || fail "Live plan not found: $PLAN_FILE"
      printf 'PASS cleanup already complete; %s is removed\n' "$PLAN_REL"; exit 0
    fi
    require_live_plan; load_rows
    cmd_cleanup "$([[ $# -eq 3 ]] && echo 1 || echo 0)" ;;
  *) usage >&2; exit 2 ;;
esac
