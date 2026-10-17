#!/usr/bin/env bash
# Publication mechanics for create-pr (../skills/dev/create-pr.md): parent
# resolution, preflight, plan archive, PR creation, verification, and cleanup.
#
# Unlike dev-worktree.sh, this script commits a copy of the live plan in the
# final slice and deletes the live plan after cleanup. It acts for the main
# agent, which alone invokes it (../skills/dev/plan.md). The create-pr
# gate (gate-check) owns entry: reviewed status, finalized PR Pattern, linked
# issue, and an active worktree. Judgment stays with the agent: PR titles and
# bodies, the merge handoff, sensitive-content review of the archive, ignored
# worktree content, and issue checklists. It never merges, retargets,
# force-pushes, or rewrites branches.
#
# Every command rechecks state before acting, so a failed run can be repeated.
# Plan parsing mirrors gate-check (plan_parents, plan_base, plan_worktree);
# change both together.
set -euo pipefail

SCRIPT_DIR=$(dirname -- "$(realpath -- "${BASH_SOURCE[0]}")")
fail() { printf '%s\n' "$*" >&2; exit 1; }
usage() {
  printf '%s\n' \
    'Usage: dev-publish.sh preflight <plan>' \
    '       dev-publish.sh archive <plan>' \
    '       dev-publish.sh archive --commit <plan>' \
    '       dev-publish.sh create <plan> <PR-n> <title> <body-file> [--ready]' \
    '       dev-publish.sh verify <plan>' \
    '       dev-publish.sh cleanup <plan> [--ignored-checked]' \
    '<plan> is docs/plans/<file>.md under the main working tree. PRs default to draft.' \
    'Exit: 0 ok, 1 failure, 2 usage, 4 confirmation needed (cleanup).'
}

# ── plan reading ──────────────────────────────────────────────────────

load_plan() {
  [[ "$1" =~ ^docs/plans/[^/]+\.md$ ]] || fail "Plan must be docs/plans/<file>.md: $1"
  PLAN_REL="$1"
  PLAN_FILE="$MAIN_ROOT/$PLAN_REL"
  PLAN_STEM=$(basename -- "$PLAN_REL" .md)
}

require_live_plan() {
  [[ -f "$PLAN_FILE" && ! -L "$PLAN_FILE" ]] || fail "Live plan not found: $PLAN_FILE"
  ! git_root ls-files --error-unmatch -- "$PLAN_REL" >/dev/null 2>&1 && ! git_root cat-file -e "HEAD:$PLAN_REL" 2>/dev/null ||
    fail "$PLAN_REL is tracked by Git, a published record; a live plan is untracked."
}

# One field of the Status header line, such as Base or Worktree.
header_field() {
  awk -v key="$2" '
    /^Status:/ {
      n = split($0, f, /\|/)
      for (i = 1; i <= n; i++) {
        x = f[i]; gsub(/^[[:space:]]+|[[:space:]]+$/, "", x)
        if (index(x, key ":") == 1) { sub("^" key ":[[:space:]]*", "", x); print x }
      }
      exit
    }' "$1"
}

# PR Pattern rows as "PR-n<TAB>branch<TAB>parent", in table order.
plan_rows() {
  awk -F'|' '
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    /^## PR Pattern/ { inp = 1; next }
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
  local line
  ROW_PR=(); ROW_BRANCH=(); ROW_PARENT=()
  while IFS= read -r line; do
    [[ "$line" != '!'* ]] || fail "PR Pattern in $PLAN_REL: ${line#!}"
    IFS=$'\t' read -r pr branch parent <<<"$line"
    [[ -n "$branch" && -n "$parent" ]] || fail "$pr in $PLAN_REL needs a Branch and a Parent."
    ROW_PR+=("$pr"); ROW_BRANCH+=("$branch"); ROW_PARENT+=("$parent")
  done < <(plan_rows)
  [[ ${#ROW_PR[@]} -gt 0 ]] || fail "No PR-n rows under ## PR Pattern in $PLAN_REL."
  LAST=$(( ${#ROW_PR[@]} - 1 ))
  BASE=$(header_field "$PLAN_FILE" Base)
  [[ -n "$BASE" ]] || fail "Plan header has no Base."
}

row_index() {
  local i
  for i in "${!ROW_PR[@]}"; do [[ "${ROW_PR[$i]}" != "$1" ]] || { printf '%s\n' "$i"; return 0; }; done
  fail "$1 is not a row of the PR Pattern."
}

# Green: PR-n (<branch>) at <sha>, recorded by review-code.
green_sha() {
  local rec
  rec=$(sed -nE "s/^[[:space:]]*([-*][[:space:]]*)?Green: $1 \\(([^)]*)\\) at ([0-9a-f]{7,40}).*/\\2 \\3/p" "$PLAN_FILE" | tail -1)
  [[ -n "$rec" ]] || return 1
  [[ "${rec% *}" == "$2" ]] || fail "Green record for $1 names branch ${rec% *}, not $2."
  git -C "$MAIN_ROOT" rev-parse --verify --quiet "${rec#* }^{commit}"
}

# Worktree: PR-n (<branch>) at <path> from the Publication Inventory; the final
# slice may instead be the header Worktree.
slice_worktree() {
  local path
  path=$(sed -nE "s/^[[:space:]]*([-*][[:space:]]*)?Worktree: $1 \\([^)]*\\) at (.+)$/\\2/p" "$PLAN_FILE" | tail -1)
  if [[ -z "$path" && "$2" -eq "$LAST" ]]; then path=$(header_field "$PLAN_FILE" Worktree); fi
  printf '%s\n' "$path"
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

# Whether revision $1 holds the committed plan copy: reviewed, with an empty
# Worktree.
is_plan_copy() {
  local copy
  copy=$(git_root show "$1:$PLAN_REL" 2>/dev/null) || return 1
  [[ "$(header_field <(printf '%s\n' "$copy") Status)" == reviewed &&
     -z "$(header_field <(printf '%s\n' "$copy") Worktree)" ]]
}

# ── git and GitHub state ──────────────────────────────────────────────

git_root() { git -C "$MAIN_ROOT" "$@"; }
gh_root() { (cd "$MAIN_ROOT" && gh "$@"); }

fetch_origin() { git_root fetch --quiet --prune origin || fail 'Cannot fetch origin.'; }

ref_sha() {
  git_root rev-parse --verify --quiet "refs/heads/$1^{commit}" ||
    git_root rev-parse --verify --quiet "refs/remotes/origin/$1^{commit}"
}

origin_sha() { git_root rev-parse --verify --quiet "refs/remotes/origin/$1^{commit}"; }

is_ancestor() { git_root cat-file -e "$1^{commit}" 2>/dev/null && git_root merge-base --is-ancestor "$1" "$2"; }

# PRs for a head branch as JSON; gh's own state filter (open or all).
prs_for() {
  gh_root pr list --head "$1" --state "$2" --json number,url,state,baseRefName,headRefOid,body
}

base_sha() {
  BASE_SHA=$(origin_sha "$BASE" || ref_sha "$BASE") || fail "Base $BASE resolves neither locally nor on origin."
}

# Sets RES_BASE (the GitHub base) and RES_SHA for row $1: the recorded Parent,
# never re-resolved; retargeting is the maintainer's.
resolve_parent() {
  RES_BASE="${ROW_PARENT[$1]}"
  if [[ "$RES_BASE" == "$BASE" ]]; then RES_SHA="$BASE_SHA"; return 0; fi
  RES_SHA=$(ref_sha "$RES_BASE") || fail "Parent $RES_BASE of ${ROW_PR[$1]} resolves neither locally nor on origin."
}

# The slice tip: the local branch, or origin's once cleanup deleted it.
slice_tip() { ref_sha "${ROW_BRANCH[$1]}"; }

# Paths changed by every commit in $1..$2, one per line.
commit_paths() { git_root log --format= --name-only "$1..$2" | sed '/^$/d' | sort -u; }

# True when slice tip $2 contains its Parent $1, or lacks only plan files: an
# earlier plan's archive commit lands on its last slice after a later plan
# branched from it (../skills/dev/create-pr.md#chain-publication). A tree
# diff without rename detection, not a commit walk, so neither a merge nor a
# rename into docs/plans/ hides a code change.
contains_parent() {
  local mb paths
  is_ancestor "$1" "$2" && return 0
  mb=$(git_root merge-base "$1" "$2") || return 1
  paths=$(git_root diff --no-renames --name-only "$mb" "$1")
  [[ -n "$paths" ]] && ! grep -qvxE 'docs/plans/[^/]+\.md' <<<"$paths"
}

# ── commands ──────────────────────────────────────────────────────────

cmd_preflight() {
  local i tip green parent_sha problems=() pr branch prs n
  fetch_origin; base_sha
  for i in "${!ROW_PR[@]}"; do
    pr="${ROW_PR[$i]}"; branch="${ROW_BRANCH[$i]}"
    resolve_parent "$i"
    tip=$(slice_tip "$i") || { problems+=("$pr: branch $branch does not resolve"); continue; }
    if [[ "$RES_BASE" != "$BASE" ]] && ! contains_parent "$RES_SHA" "$tip"; then
      problems+=("$pr: $branch does not contain its Parent $RES_BASE")
    fi
    parent_sha=$(git_root merge-base "$RES_SHA" "$tip") || { problems+=("$pr: no merge base with $RES_BASE"); continue; }
    if ! green=$(green_sha "$pr" "$branch"); then
      problems+=("$pr: no Green: $pr ($branch) at <sha> record")
    elif [[ "$green" != "$tip" ]]; then
      if [[ "$i" -ne "$LAST" ]] || ! is_ancestor "$green" "$tip" || [[ "$(commit_paths "$green" "$tip")" != "$PLAN_REL" ]]; then
        problems+=("$pr: tip $tip differs from Green $green by more than the plan copy; changed code returns to review")
      fi
    fi
    if [[ -n "${green:-}" ]]; then
      if git_root diff --quiet "$parent_sha" "$green"; then problems+=("$pr: empty diff from $RES_BASE"); fi
      (cd "$MAIN_ROOT" && bash "$SCRIPT_DIR/dev-check" artifacts "$parent_sha" "$green") >/dev/null 2>&1 ||
        problems+=("$pr: artifact scan failed; run dev-check artifacts $parent_sha $green")
    fi
    prs=$(prs_for "$branch" all)
    # An open PR is this slice's own, made by an earlier create, only when it
    # targets the recorded Parent at the slice tip.
    n=$(jq --arg b "$RES_BASE" --arg t "$tip" \
      '[.[] | select(.state == "OPEN" and (.baseRefName != $b or .headRefOid != $t))] | length' <<<"$prs")
    [[ "$n" -eq 0 ]] || problems+=("$pr: $branch has an open PR not based on $RES_BASE at $tip")
    while IFS= read -r oid; do
      [[ -n "$oid" ]] || continue
      if [[ "$oid" != "$parent_sha" ]] && is_ancestor "$parent_sha" "$oid" && is_ancestor "$oid" "$tip"; then
        problems+=("$pr: a closed or merged PR already published commits of this slice ($oid)")
      fi
    done < <(jq -r '.[] | select(.state != "OPEN") | .headRefOid' <<<"$prs")
    printf '%s\t%s\tbase=%s\tparent=%s\ttip=%s\n' "$pr" "$branch" "$RES_BASE" "$parent_sha" "$tip"
    green=""
  done
  if [[ ${#problems[@]} -gt 0 ]]; then printf 'BLOCK %s\n' "${problems[@]}" >&2; exit 1; fi
  printf 'PASS preflight %s\n' "$PLAN_REL"
}

final_worktree() {
  WT=$(slice_worktree "${ROW_PR[$LAST]}" "$LAST")
  [[ -n "$WT" && -d "$WT" ]] || fail "Final slice ${ROW_PR[$LAST]} has no existing worktree recorded."
  [[ "$(git -C "$WT" symbolic-ref --quiet --short HEAD)" == "${ROW_BRANCH[$LAST]}" ]] ||
    fail "Worktree $WT is not on ${ROW_BRANCH[$LAST]}."
}

archive_message() { printf 'docs(plan): archive %s\n' "$PLAN_STEM"; }

cmd_archive() {
  local content staged
  require_live_plan; final_worktree
  content=$(clear_worktree "$PLAN_FILE")
  if [[ "$(git -C "$WT" log -1 --format=%s)" == "$(archive_message)" ]]; then
    printf 'PASS archive already committed at %s\n' "$(git -C "$WT" rev-parse HEAD)"; return 0
  fi
  staged=$(git -C "$WT" diff --cached --name-only)
  if [[ -z "$staged" ]]; then
    [[ -z "$(git -C "$WT" status --porcelain --untracked-files=all)" ]] || fail "Final worktree $WT is not clean."
    ! git -C "$WT" cat-file -e "HEAD:$PLAN_REL" 2>/dev/null ||
      fail "A published plan already occupies $PLAN_REL in $WT; resolve the path collision."
    mkdir -p -- "$(dirname -- "$WT/$PLAN_REL")"
    printf '%s\n' "$content" > "$WT/$PLAN_REL"
    git -C "$WT" add -f -- "$PLAN_REL"
  elif [[ "$staged" != "$PLAN_REL" ]]; then
    fail "Final worktree stages more than $PLAN_REL: $staged"
  fi
  git -C "$WT" diff --cached -- "$PLAN_REL"
  printf 'STAGED %s in %s; inspect it for sensitive content, then run: dev-publish.sh archive --commit %s\n' "$PLAN_REL" "$WT" "$PLAN_REL"
}

cmd_archive_commit() {
  local staged
  final_worktree
  if [[ "$(git -C "$WT" log -1 --format=%s)" == "$(archive_message)" ]]; then
    printf 'PASS archive already committed at %s\n' "$(git -C "$WT" rev-parse HEAD)"; return 0
  fi
  staged=$(git -C "$WT" diff --cached --name-only)
  [[ "$staged" == "$PLAN_REL" ]] || fail "Expected only $PLAN_REL staged in $WT; found: ${staged:-nothing}. Run archive first."
  [[ -z "$(git -C "$WT" status --porcelain --untracked-files=all | grep -vxE "[AM]  $PLAN_REL" || true)" ]] ||
    fail "Final worktree $WT has changes besides the staged archive."
  git -C "$WT" commit --quiet -m "$(archive_message)"
  printf 'PASS archive committed at %s\n' "$(git -C "$WT" rev-parse HEAD)"
}

cmd_create() {
  local pr="$1" title="$2" body="$3" ready="$4" i branch open url tip base_ref head_oid flags=(--draft)
  require_live_plan
  [[ -n "$title" && -f "$body" && -r "$body" ]] || fail 'A nonempty title and readable body file are required.'
  i=$(row_index "$pr"); branch="${ROW_BRANCH[$i]}"
  fetch_origin; base_sha; resolve_parent "$i"
  # An open PR from an earlier create, including a failed one, is reused only
  # when it targets the recorded Parent at the slice tip.
  open=$(prs_for "$branch" open | jq -r '.[0] // empty | [.url, .baseRefName, .headRefOid] | @tsv')
  if [[ -n "$open" ]]; then
    tip=$(slice_tip "$i") || fail "Branch $branch does not resolve."
    IFS=$'\t' read -r url base_ref head_oid <<<"$open"
    [[ "$base_ref" == "$RES_BASE" && "$head_oid" == "$tip" ]] ||
      fail "$branch has an open PR $url based on $base_ref at $head_oid, not $RES_BASE at $tip."
    printf 'EXISTS %s %s\n' "$pr" "$url"; return 0
  fi
  if [[ "$RES_BASE" != "$BASE" ]]; then
    origin_sha "$RES_BASE" >/dev/null || fail "Base branch $RES_BASE of $pr is not on origin; create earlier PRs first."
  fi
  if [[ "$i" -eq "$LAST" ]]; then
    is_plan_copy "refs/heads/$branch" ||
      fail "Final slice $branch has no committed plan copy; run archive and archive --commit first."
  fi
  git_root push --quiet origin "refs/heads/$branch:refs/heads/$branch" || fail "Push of $branch failed; origin may have diverged."
  [[ "$ready" == 1 ]] && flags=()
  url=$(gh_root pr create --head "$branch" --base "$RES_BASE" --title "$title" --body-file "$body" "${flags[@]}") ||
    fail "PR creation for $pr failed; rerun create, which reports EXISTS if the PR was created."
  printf 'CREATED %s %s\n' "$pr" "$url"
}

# Collects problems into VERIFY_PROBLEMS; prints one line per verified PR.
verify_publication() {
  local i pr branch prs n info url base oid body tip origin_tip j green link_sha
  local urls=() nums=()
  VERIFY_PROBLEMS=()
  fetch_origin; base_sha
  for i in "${!ROW_PR[@]}"; do
    pr="${ROW_PR[$i]}"; branch="${ROW_BRANCH[$i]}"
    resolve_parent "$i"
    prs=$(prs_for "$branch" open)
    n=$(jq length <<<"$prs")
    if [[ "$n" -ne 1 ]]; then VERIFY_PROBLEMS+=("$pr: expected one open PR for $branch, found $n"); urls+=(""); nums+=(""); continue; fi
    info=$(jq -r '.[0] | [.url, .baseRefName, .headRefOid, (.number|tostring)] | @tsv' <<<"$prs")
    IFS=$'\t' read -r url base oid num <<<"$info"
    body=$(jq -r '.[0].body' <<<"$prs")
    urls+=("$url"); nums+=("$num")
    [[ "$base" == "$RES_BASE" ]] || VERIFY_PROBLEMS+=("$pr: PR base is $base, expected $RES_BASE")
    origin_tip=$(origin_sha "$branch" || true)
    tip=$(git_root rev-parse --verify --quiet "refs/heads/$branch^{commit}" || printf '%s' "$origin_tip")
    [[ "$oid" == "$origin_tip" && "$tip" == "$origin_tip" ]] || VERIFY_PROBLEMS+=("$pr: PR head, origin, and local tip of $branch differ")
    for (( j = 0; j < i; j++ )); do
      # A link must not continue with a digit: #1 and .../pull/1 are not #12.
      [[ -z "${urls[$j]}" || "$body" == *"${urls[$j]}" || "$body" == *"${urls[$j]}"[^0-9]* ||
         "$body" == *"#${nums[$j]}" || "$body" == *"#${nums[$j]}"[^0-9]* ]] ||
        VERIFY_PROBLEMS+=("$pr: body does not link earlier ${ROW_PR[$j]}")
    done
    if [[ "$i" -eq "$LAST" && -n "$origin_tip" ]]; then
      is_plan_copy "$origin_tip" ||
        VERIFY_PROBLEMS+=("$pr: $PLAN_REL at origin/$branch is not a reviewed plan copy with empty Worktree")
      if green=$(green_sha "$pr" "$branch"); then
        [[ "$green" == "$origin_tip" || "$(commit_paths "$green" "$origin_tip")" == "$PLAN_REL" ]] ||
          VERIFY_PROBLEMS+=("$pr: commits after Green touch more than $PLAN_REL")
      fi
      link_sha=$(grep -oE "/blob/[0-9a-f]{40}/$PLAN_REL" <<<"$body" | head -1 | cut -d/ -f3 || true)
      if [[ -z "$link_sha" ]]; then
        VERIFY_PROBLEMS+=("$pr: body has no immutable /blob/<sha>/$PLAN_REL plan link")
      elif ! is_ancestor "$link_sha" "$origin_tip" || ! is_plan_copy "$link_sha"; then
        VERIFY_PROBLEMS+=("$pr: plan link $link_sha is not the plan copy on $branch")
      fi
    fi
    printf '%s\t%s\t%s\n' "$pr" "$url" "$base"
  done
}

cmd_verify() {
  require_live_plan
  verify_publication
  if [[ ${#VERIFY_PROBLEMS[@]} -gt 0 ]]; then printf 'BLOCK %s\n' "${VERIFY_PROBLEMS[@]}" >&2; exit 1; fi
  printf 'PASS verify %s\n' "$PLAN_REL"
}

cmd_cleanup() {
  local checked="$1" i pr branch wt out ignored problems=() unchecked=0
  if [[ ! -e "$PLAN_FILE" ]]; then printf 'PASS cleanup already complete; %s is removed\n' "$PLAN_REL"; return 0; fi
  require_live_plan
  verify_publication >/dev/null
  if [[ ${#VERIFY_PROBLEMS[@]} -gt 0 ]]; then printf 'BLOCK %s\n' "${VERIFY_PROBLEMS[@]}" >&2; fail 'Publication is not verified; cleanup keeps everything.'; fi
  # Removal deletes ignored content unseen, so all of it is shown before any
  # worktree goes; the agent checks it for unrelated files.
  if [[ "$checked" != 1 ]]; then
    for i in "${!ROW_PR[@]}"; do
      wt=$(slice_worktree "${ROW_PR[$i]}" "$i")
      [[ -n "$wt" && -d "$wt" ]] || continue
      ignored=$(git -C "$wt" status --porcelain --ignored --untracked-files=normal | sed -n 's/^!! //p')
      if [[ -n "$ignored" ]]; then printf 'IGNORED %s (%s):\n%s\n' "${ROW_PR[$i]}" "$wt" "$ignored"; unchecked=1; fi
    done
    if [[ "$unchecked" -eq 1 ]]; then
      printf 'Check the ignored content above for unrelated files, then rerun: dev-publish.sh cleanup %s --ignored-checked\n' "$PLAN_REL" >&2
      exit 4
    fi
  fi
  for i in "${!ROW_PR[@]}"; do
    pr="${ROW_PR[$i]}"; branch="${ROW_BRANCH[$i]}"
    wt=$(slice_worktree "$pr" "$i")
    if [[ -n "$wt" && -d "$wt" ]]; then
      out=$(bash "$SCRIPT_DIR/dev-worktree.sh" remove "$wt" 2>&1 | tail -1) || { problems+=("$pr: $out"); continue; }
      [[ "$out" == "deleted $branch" ]] || problems+=("$pr: $out")
      printf '%s\t%s\n' "$pr" "$out"
    elif git_root rev-parse --verify --quiet "refs/heads/$branch" >/dev/null; then
      problems+=("$pr: worktree is gone but local branch $branch remains")
    else
      printf '%s\talready removed\n' "$pr"
    fi
  done
  if [[ ${#problems[@]} -gt 0 ]]; then printf 'BLOCK %s\n' "${problems[@]}" >&2; fail 'Cleanup stopped; the live plan is retained.'; fi
  rm -- "$PLAN_FILE"
  printf 'PLAN deleted (untracked)\n'
  printf 'PASS cleanup %s\n' "$PLAN_REL"
}

# ── dispatch ──────────────────────────────────────────────────────────

[[ "${1-}" != --help && "${1-}" != -h ]] || { usage; exit 0; }
[[ $# -ge 2 ]] || { usage >&2; exit 2; }
command -v jq >/dev/null || fail 'jq is required.'
MAIN_ROOT=$(bash "$SCRIPT_DIR/dev-utils.sh" main-root)

case "$1" in
  preflight)
    [[ $# -eq 2 ]] || { usage >&2; exit 2; }
    load_plan "$2"; require_live_plan; load_rows; cmd_preflight ;;
  archive)
    if [[ "$2" == --commit ]]; then
      [[ $# -eq 3 ]] || { usage >&2; exit 2; }
      load_plan "$3"; require_live_plan; load_rows; cmd_archive_commit
    else
      [[ $# -eq 2 ]] || { usage >&2; exit 2; }
      load_plan "$2"; require_live_plan; load_rows; cmd_archive
    fi ;;
  create)
    [[ $# -eq 5 || ( $# -eq 6 && "$6" == --ready ) ]] || { usage >&2; exit 2; }
    load_plan "$2"; require_live_plan; load_rows
    cmd_create "$3" "$4" "$5" "$([[ $# -eq 6 ]] && echo 1 || echo 0)" ;;
  verify)
    [[ $# -eq 2 ]] || { usage >&2; exit 2; }
    load_plan "$2"; require_live_plan; load_rows; cmd_verify ;;
  cleanup)
    [[ $# -eq 2 || ( $# -eq 3 && "$3" == --ignored-checked ) ]] || { usage >&2; exit 2; }
    load_plan "$2"
    if [[ -e "$PLAN_FILE" ]]; then load_rows; fi
    cmd_cleanup "$([[ $# -eq 3 ]] && echo 1 || echo 0)" ;;
  *) usage >&2; exit 2 ;;
esac
