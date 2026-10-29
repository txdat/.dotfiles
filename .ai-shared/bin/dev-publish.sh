#!/usr/bin/env bash
# Publication checks for create-pr (../skills/dev/create-pr.md): reviewed-tip
# checks, PR verification, and cleanup. A plan is one PR; the PR carries code
# only, and the plan stays outside the repository as a published record.
#
# The main agent alone runs it. The create-pr gate (gate-check.sh) owns entry:
# reviewed status and an active worktree. The agent pushes and opens the PRs
# and owns their titles and bodies and the ignored-file check. This script
# never merges, retargets, force-pushes, or rewrites branches; every command
# rechecks state, so a failed run can be repeated. Plan reading comes from
# dev-plan-lib.sh.
set -euo pipefail

SCRIPT_DIR=$(dirname -- "$(realpath -- "${BASH_SOURCE[0]}")")
fail() { printf '%s\n' "$*" >&2; exit 1; }
usage() {
  printf '%s\n' \
    'Usage: dev-publish.sh check <plan>' \
    '       dev-publish.sh verify <plan>' \
    '       dev-publish.sh cleanup <plan> [--ignored-checked]' \
    '<plan> is ~/work/plans/<repo>/<issue>_<slug>/pr<N>.spec.md, run from the repository.' \
    'cleanup sets Status: published and keeps the plan as a record.' \
    'Exit: 0 ok, 1 failure, 2 usage, 4 confirmation needed (cleanup).'
}

# ── plan reading ──────────────────────────────────────────────────────

load_plan() {
  PLAN_FILE=$(canonical_plan "$1") || fail "Plan must be $PLAN_FORMAT: $1"
  [[ -f "$PLAN_FILE" && ! -L "$PLAN_FILE" ]] || fail "Plan not found: $PLAN_FILE"
}

require_unpublished() {
  ! is_published "$PLAN_FILE" || fail "$PLAN_FILE is published; publication of it is complete."
}

# The plan's branch, the branch its PR targets, and its worktree.
load_fields() {
  BRANCH=$(field "$PLAN_FILE" Branch)
  [[ -n "$BRANCH" ]] || fail "Plan header has no Branch."
  PARENT_PLAN=$(stacks_on "$PLAN_FILE") || fail "Plan has an unreadable 'Stacks On:' line."
  TARGET=$(pr_target "$PLAN_FILE")
  [[ -n "$TARGET" ]] || fail "No PR target: ${PARENT_PLAN:+parent plan $PARENT_PLAN has no Branch}${PARENT_PLAN:-the plan header has no Base}."
  WT=$(worktree_of "$PLAN_FILE")
}

# The Tip SHA of a `Status: reviewed` plan, recorded by review-code.
green_sha() {
  local sha
  sha=$(green_of "$PLAN_FILE")
  [[ -n "$sha" ]] || return 1
  git_root rev-parse --verify --quiet "$sha^{commit}"
}

# ── git and GitHub state ──────────────────────────────────────────────

git_root() { git -C "$MAIN_ROOT" "$@"; }
gh_root() { (cd "$MAIN_ROOT" && gh "$@"); }

fetch_origin() { git_root fetch --quiet --prune origin || fail 'Cannot fetch origin.'; }

origin_sha() { git_root rev-parse --verify --quiet "refs/remotes/origin/$1^{commit}"; }
local_sha() { git_root rev-parse --verify --quiet "refs/heads/$1^{commit}"; }
ref_sha() { local_sha "$1" || origin_sha "$1"; }
is_ancestor() { git_root cat-file -e "$1^{commit}" 2>/dev/null && git_root merge-base --is-ancestor "$1" "$2"; }

# PRs for a head branch as JSON; gh's state filter (open or all).
prs_for() { gh_root pr list --head "$1" --state "$2" --json number,url,state,baseRefName,headRefOid,body; }

# The SHA of the PR target: Base from origin (or local), a parent plan's
# branch from either.
target_sha() {
  if [[ -z "$PARENT_PLAN" ]]; then
    origin_sha "$TARGET" || ref_sha "$TARGET" || fail "Base $TARGET resolves neither locally nor on origin."
  else
    ref_sha "$TARGET" || fail "Parent branch $TARGET resolves neither locally nor on origin."
  fi
}

# The plans below this one, nearest first; "!<plan>" ends the list at a plan
# whose Stacks On line cannot be read.
ancestor_plans() {
  local plan="$PARENT_PLAN"
  while [[ -n "$plan" ]]; do
    printf '%s\n' "$plan"
    plan=$(stacks_on "$plan") || { printf '!%s\n' "$plan"; return 0; }
  done
}

# ── commands ──────────────────────────────────────────────────────────

# Prints PROBLEMS as BLOCK lines and fails when there are any.
report_problems() {
  (( ${#PROBLEMS[@]} == 0 )) || { printf 'BLOCK %s\n' "${PROBLEMS[@]}" >&2; return 1; }
}

cmd_check() {
  local tip green target parent_sha prs n
  PROBLEMS=()
  fetch_origin
  target=$(target_sha)
  if ! tip=$(ref_sha "$BRANCH"); then
    PROBLEMS+=("branch $BRANCH does not resolve")
  else
    if [[ -n "$PARENT_PLAN" ]] && ! is_ancestor "$target" "$tip"; then
      PROBLEMS+=("$BRANCH does not contain its parent plan's branch $TARGET; merge it forward")
    fi
    if ! parent_sha=$(git_root merge-base "$target" "$tip"); then
      PROBLEMS+=("no merge base with $TARGET")
    elif ! green=$(green_sha); then
      PROBLEMS+=("no 'Status: reviewed' with a 'Tip:' SHA")
    else
      [[ "$green" == "$tip" ]] ||
        PROBLEMS+=("tip $tip differs from the reviewed $green; changed code returns to review")
      if git_root diff --quiet "$parent_sha" "$green"; then PROBLEMS+=("empty diff from $TARGET"); fi
      (cd "$MAIN_ROOT" && bash "$SCRIPT_DIR/dev-check.sh" artifacts "$parent_sha" "$green") >/dev/null 2>&1 ||
        PROBLEMS+=("conflict markers; run dev-check.sh artifacts $parent_sha $green")
    fi
    prs=$(prs_for "$BRANCH" all)
    # An open PR from an earlier run is this plan's own when it targets its
    # PR target; a repair moves the tip ahead of it until the push.
    n=$(jq --arg b "$TARGET" '[.[] | select(.state == "OPEN" and .baseRefName != $b)] | length' <<<"$prs")
    [[ "$n" -eq 0 ]] || PROBLEMS+=("$BRANCH has an open PR not based on $TARGET")
    printf '%s\tbase=%s\tparent=%s\ttip=%s\n' "$BRANCH" "$TARGET" "${parent_sha:-?}" "$tip"
  fi
  report_problems || exit 1
  printf 'PASS check %s\n' "$PLAN_FILE"
}

# Collects problems into PROBLEMS; prints the verified PR.
verify_publication() {
  local prs n url base oid body tip origin_tip green plan pbranch pprs purl pnum
  PROBLEMS=()
  fetch_origin
  prs=$(prs_for "$BRANCH" open)
  n=$(jq length <<<"$prs")
  if [[ "$n" -ne 1 ]]; then PROBLEMS+=("expected one open PR for $BRANCH, found $n"); return 0; fi
  IFS=$'\t' read -r url base oid < <(jq -r '.[0] | [.url, .baseRefName, .headRefOid] | @tsv' <<<"$prs")
  body=$(jq -r '.[0].body' <<<"$prs")
  [[ "$base" == "$TARGET" ]] || PROBLEMS+=("PR base is $base, expected $TARGET")
  origin_tip=$(origin_sha "$BRANCH" || true)
  tip=$(local_sha "$BRANCH" || printf '%s' "$origin_tip")
  [[ -n "$origin_tip" && "$oid" == "$origin_tip" && "$tip" == "$origin_tip" ]] ||
    PROBLEMS+=("PR head, origin, and local tip of $BRANCH differ")
  if green=$(green_sha); then
    [[ -z "$origin_tip" || "$green" == "$origin_tip" ]] ||
      PROBLEMS+=("origin/$BRANCH differs from the reviewed $green")
  else
    PROBLEMS+=("no 'Status: reviewed' with a 'Tip:' SHA")
  fi
  # The body links the PR of every plan below this one.
  while IFS= read -r plan; do
    [[ -n "$plan" ]] || continue
    if [[ "$plan" == '!'* ]]; then PROBLEMS+=("a plan below, $(plan_label "${plan#!}"), has an unreadable 'Stacks On:' line"); continue; fi
    pbranch=$(field "$plan" Branch)
    pprs=$(prs_for "$pbranch" open)
    if [[ "$(jq length <<<"$pprs")" -ne 1 ]]; then
      PROBLEMS+=("the plan below, $(plan_label "$plan"), has no single open PR for $pbranch"); continue
    fi
    IFS=$'\t' read -r purl pnum < <(jq -r '.[0] | [.url, (.number|tostring)] | @tsv' <<<"$pprs")
    # A link must not continue with a digit: #1 and .../pull/1 are not #12.
    [[ "$body" == *"$purl" || "$body" == *"$purl"[^0-9]* || "$body" == *"#$pnum" || "$body" == *"#$pnum"[^0-9]* ]] ||
      PROBLEMS+=("body does not link the PR of $(plan_label "$plan"), $purl")
  done < <(ancestor_plans)
  printf '%s\t%s\t%s\n' "$BRANCH" "$url" "$base"
}

cmd_verify() {
  verify_publication
  report_problems || exit 1
  printf 'PASS verify %s\n' "$PLAN_FILE"
}

# The plan with its Status set to published.
mark_published() { set_header "$PLAN_FILE" Status published || fail "Cannot set Status: published in $PLAN_FILE."; }

# A plan shares its worktree with its parent when both resolve to the same one
# (an only child); the plan that created the worktree removes it.
cmd_cleanup() {
  local checked="$1" out ignored children head tip
  # "!<plan>" is a plan whose Stacks On line cannot be read, so it may name this one.
  children=$(child_plans "$PLAN_FILE")
  [[ -z "$children" ]] || fail "Unpublished plans stack on $PLAN_FILE or have an unreadable Stacks On line: ${children//$'\n'/ }. Clean up its children first, children before parents; fix an unreadable line first."
  verify_publication >/dev/null
  report_problems || fail 'Publication is not verified; cleanup keeps everything.'
  if [[ -n "$WT" ]]; then
    [[ -z "$(git -C "$WT" status --porcelain --untracked-files=all)" ]] || fail "Worktree $WT has uncommitted or untracked changes."
    head=$(git -C "$WT" symbolic-ref --quiet --short HEAD || true)
    if [[ -n "$PARENT_PLAN" && "$(worktree_of "$PARENT_PLAN")" == "$WT" ]]; then
      # Shared: hand the worktree back to the parent, which removes it later.
      [[ "$head" == "$BRANCH" || "$head" == "$TARGET" ]] || fail "Worktree $WT is on '${head:-a detached HEAD}', neither $BRANCH nor its parent's $TARGET."
      [[ "$head" == "$TARGET" ]] || git -C "$WT" switch --quiet "$TARGET" || fail "Cannot switch $WT to $TARGET."
      printf 'WORKTREE %s returned to %s\n' "$WT" "$TARGET"
    else
      [[ "$head" == "$BRANCH" ]] || fail "Worktree $WT is on '${head:-a detached HEAD}', not $BRANCH; clean up the plans stacked on this one first."
      # Removal deletes ignored content unseen, so it is shown first for the
      # agent to check for unrelated files.
      if [[ "$checked" != 1 ]]; then
        ignored=$(git -C "$WT" status --porcelain --ignored --untracked-files=normal) || fail "Cannot list ignored files in $WT."
        ignored=$(sed -n 's/^!! //p' <<<"$ignored")
        if [[ -n "$ignored" ]]; then
          printf 'IGNORED in %s:\n%s\n' "$WT" "$ignored"
          printf 'Check the ignored content above for unrelated files, then rerun: dev-publish.sh cleanup %s --ignored-checked\n' "$PLAN_FILE" >&2
          exit 4
        fi
      fi
      out=$(bash "$SCRIPT_DIR/dev-worktree.sh" remove "$WT" 2>&1 | tail -1) || fail "Worktree removal failed: $out"
      printf 'WORKTREE removed %s; %s\n' "$WT" "$out"
    fi
  else
    printf 'WORKTREE none\n'
  fi
  # verify fetched origin, so a branch at origin's tip has nothing unpushed.
  if tip=$(local_sha "$BRANCH"); then
    [[ "$tip" == "$(origin_sha "$BRANCH" || true)" ]] ||
      fail "Local $BRANCH differs from origin; kept. Cleanup stopped; the plan stays unpublished."
    # A worktree directory deleted by hand still holds the branch until pruned.
    git_root worktree prune
    git_root branch -q -D "$BRANCH"
    printf 'deleted %s\n' "$BRANCH"
  fi
  mark_published
  printf 'PASS cleanup %s; Status: published\n' "$PLAN_FILE"
}

# ── dispatch ──────────────────────────────────────────────────────────

[[ "${1-}" != --help && "${1-}" != -h ]] || { usage; exit 0; }
[[ $# -ge 2 ]] || { usage >&2; exit 2; }
command -v jq >/dev/null || fail 'jq is required.'
MAIN_ROOT=$(bash "$SCRIPT_DIR/dev-utils.sh" main-root)
REPO_ROOT="$MAIN_ROOT"
cd "$MAIN_ROOT"
. "$SCRIPT_DIR/dev-plan-lib.sh"

case "$1" in
  check|verify)
    [[ $# -eq 2 ]] || { usage >&2; exit 2; }
    load_plan "$2"; require_unpublished; load_fields; "cmd_$1" ;;
  cleanup)
    [[ $# -eq 2 || ( $# -eq 3 && "$3" == --ignored-checked ) ]] || { usage >&2; exit 2; }
    load_plan "$2"
    if is_published "$PLAN_FILE"; then printf 'PASS cleanup already complete; %s is published\n' "$PLAN_FILE"; exit 0; fi
    load_fields
    cmd_cleanup "$(( $# == 3 ))" ;;
  *) usage >&2; exit 2 ;;
esac
