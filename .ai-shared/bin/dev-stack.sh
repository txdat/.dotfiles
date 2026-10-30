#!/usr/bin/env bash
# The stack tree of live plans (../skills/dev/plan.md#stacks), for
# design-feature, create-pr, and run-stack. `review` sets a planning plan's
# Status and Spec; `stop` and `resume` append to the stack's stops.log; the
# rest only read.
set -euo pipefail

SCRIPT_DIR=$(dirname -- "$(realpath -- "${BASH_SOURCE[0]}")")
fail() { printf '%s\n' "$*" >&2; exit 1; }
usage() {
  printf '%s\n' \
    'Usage: dev-stack.sh stack <root plan>' \
    '       dev-stack.sh next <root plan> [--tab|--tree|--md]' \
    '       dev-stack.sh review <plan> ready|needs-changes' \
    '       dev-stack.sh stop <plan> <reason>' \
    '       dev-stack.sh resume <plan>' \
    '       dev-stack.sh check <root plan>' \
    'stack lists the plans, parents before children. next prints, per plan,' \
    '"<plan> <status> <parent> <action> <reason>" tab-separated, with "-" for none' \
    '(--tab, the default);' \
    'action is a runnable phase (review-feature, execute-feature, review-code,' \
    'create-pr), revise after a needs-changes review, or stopped, wait-parent,' \
    'wait-user, blocked, or done. --tree prints the stack as a tree instead, and' \
    '--md as a Markdown table, both with a colored dot per status and a mark per' \
    'action.' \
    'review sets Status to the review-feature verdict, ready or needs-changes,' \
    'and Spec to its hash of the current spec. stop records' \
    'in the stack'"'"'s stops.log why run-stack stopped a plan; it holds until the' \
    'plan changes or resume clears it, and one citing "Failed fixes: 3/3" or more' \
    'holds until resume. Only the user runs resume.' \
    'check runs the review-feature gate, without its parent check, on each plan' \
    'in the stack still in planning, printing PASS or BLOCK and the reason, and' \
    'SKIP for a plan approved or later whose review still holds (BLOCK when it' \
    'does not); it exits 1 on a block.' \
    '<plan> is ~/work/plans/<repo>/<issue>_<slug>/pr<N>.spec.md, run from the repository.' \
    'Exit: 0 ok, 1 failure, 2 usage.'
}

# An unpublished plan of this repository, a regular file; sets PLAN.
require_live() {
  PLAN=$(canonical_plan "$1") || fail "Plan must be $PLAN_FORMAT: $1"
  [[ -f "$PLAN" && ! -L "$PLAN" ]] || fail "Plan not found: $PLAN"
  ! is_published "$PLAN" || fail "$PLAN is published; no phase resumes it."
  index_stack "$PLAN"
}

# Plan $1 and every plan stacked above it, parents before children; fails on a
# plan that is not the root or a Stacks On line that cannot be read.
stack_plans() {
  local parent plans
  parent=$(stacks_on "$1") || fail "$1 has an unreadable 'Stacks On:' line."
  [[ -z "$parent" ]] || fail "$1 stacks on $parent; pass the stack's root."
  [[ "$(root_plans "$1" | grep -c . || true)" == 1 ]] || fail "$(dirname -- "$1") holds more than one plan without a 'Stacks On:' line; a directory holds one stack."
  plans=$(descendant_plans "$1")
  [[ "$plans" != *'!'* ]] || fail "Unreadable 'Stacks On:' lines in: $(grep '^!' <<<"$plans" | tr -d '!' | tr '\n' ' ')"
  printf '%s\n' "$1"
  [[ -z "$plans" ]] || printf '%s\n' "$plans"
}

# What a stop record is bound to: plan $1's Status value, a verdict read as
# planning so recording one keeps the stop, and its Tip; its spec with the
# specs below it; and its branch's tip. Not the worktree's HEAD: a parent and
# its only child share a worktree, and switching between them changes neither.
stop_key() {
  local hash branch tip=- status
  hash=$(plan_hash "$1") || fail "Cannot hash $1: a plan below it is missing or unreadable."
  branch=$(field "$1" Branch)
  [[ -z "$branch" ]] || tip=$(git -C "$REPO_ROOT" rev-parse --verify -q "refs/heads/$branch^{commit}" 2>/dev/null || printf -)
  status=$(field "$1" Status)
  [[ "$(status_rank "$status")" != 0 ]] || status=planning
  printf '%s %s\n%s\n%s\n' "$status" "$(field "$1" Tip)" "$hash" "$tip" | git hash-object --stdin
}

# Whether stop reason $1 cites three or more failed fixes of three.
three_failed() {
  grep -oE 'Failed fixes: [0-9]+/3([^0-9]|$)' <<<"$1" | grep -qE ': 0*([3-9]|[1-9][0-9]+)/3'
}

# Why plan $1 is stopped; empty when it is not. Three failed fixes recorded
# since the last resume hold until the user grants more with resume
# (../AGENTS.md#work); otherwise the last stop holds while its key does, and
# a change or a resume ends it.
stop_reason() {
  local recs rec held=""
  recs=$(stop_records "$1")
  while IFS= read -r rec; do
    [[ "$rec" =~ ^(.+)\ at\ [0-9a-f]{40,64}$ ]] && three_failed "${BASH_REMATCH[1]}" && held=${BASH_REMATCH[1]}
  done <<<"$recs"
  [[ -z "$held" ]] || { printf '%s\n' "$held"; return 0; }
  rec=$(tail -1 <<<"$recs")
  [[ "$rec" =~ ^(.+)\ at\ ([0-9a-f]{40,64})$ && "${BASH_REMATCH[2]}" == "$(stop_key "$1")" ]] || return 0
  printf '%s\n' "${BASH_REMATCH[1]}"
}

# The stack's stop log: "pr<N>: <reason> at <key>" or "pr<N>: cleared" lines.
stops_log() { printf '%s/stops.log\n' "$(dirname -- "$1")"; }

# Plan $1's stop records since its last resume, without their prefix.
stop_records() {
  awk -v p="pr$(plan_number "$1"): " 'index($0, p) == 1 {
      r = substr($0, length(p) + 1)
      if (r == "cleared") n = 0; else rec[++n] = r
    }
    END { for (i = 1; i <= n; i++) print rec[i] }' "$(stops_log "$1")" 2>/dev/null || true
}

cmd_stop() {
  local key
  [[ -n "$2" && "$2" != *[$'\t\n']* ]] || fail 'A stop reason is one nonempty line without tabs.'
  key=$(stop_key "$1")
  printf 'pr%s: %s at %s\n' "$(plan_number "$1")" "$2" "$key" >> "$(stops_log "$1")"
  printf 'Stop recorded in %s\n' "$(stops_log "$1")"
}

cmd_resume() {
  printf 'pr%s: cleared\n' "$(plan_number "$1")" >> "$(stops_log "$1")"
  printf 'Stop cleared in %s\n' "$(stops_log "$1")"
}

# Sets Status to verdict $2 and Spec to its hash of the current spec, in place.
cmd_review() {
  local hash
  case "$2" in ready|needs-changes) ;; *) usage >&2; exit 2 ;; esac
  [[ "$(status_rank "$(status_of "$1")")" == 0 ]] || fail "$1 is '$(status_of "$1")'; a verdict records only before approval."
  hash=$(plan_hash "$1") || fail "Cannot hash $1: a plan below it is missing, has an unreadable 'Stacks On:' line, or forms a cycle."
  hash=$(verdict_hash "$hash" "$2")
  set_header "$1" Status "$2" Spec "$hash" || fail "Cannot write the header of $1."
  printf 'Status: %s, Spec: %s recorded in %s\n' "$2" "$hash" "$1"
}

# The gate's reason for running skill $1 on plan $2; empty when it passes.
gate_reason() {
  local out
  out=$(jq -cn --arg s "dev-$1" --arg a "$2" '{hook_event_name:"PreToolUse",tool_name:"Skill",tool_input:{skill:$s,args:$a}}' |
    bash "$SCRIPT_DIR/gate-check.sh")
  [[ -z "$out" ]] || jq -r '.reason' <<<"$out" 2>/dev/null || printf '%s\n' "$out"
}

# The review-feature gate, without its parent check, on each plan in the
# stack still in planning, as design-feature hands it over; fails when any
# plan blocks. An approved plan whose review still holds is past design and
# frozen (plan.md#changes), so a revision under it still checks; one whose
# spec, or a spec below it, changed since blocks, as in next.
cmd_check() {
  local plans plan status rank out failed=0
  # Not a process substitution: its failure would read as an empty, passing stack.
  plans=$(stack_plans "$1") || exit 1
  while IFS= read -r plan; do
    status=$(status_of "$plan"); rank=$(status_rank "$status")
    if [[ -n "$rank" ]] && (( rank >= 1 && rank <= 3 )); then
      if [[ "$(review_state "$plan" || true)" == ready ]]; then printf 'SKIP %s (%s)\n' "$plan" "$status"; continue; fi
      failed=1
      printf 'BLOCK %s\nIt is %s, but its spec or a plan below it changed since its review; return it to planning and review it again (skills/dev/plan.md#stacks).\n' "$plan" "$status"
      continue
    fi
    if ! out=$(bash "$SCRIPT_DIR/gate-check.sh" --design "$plan" </dev/null); then
      failed=1; printf 'BLOCK %s\ngate-check.sh failed without a verdict.\n' "$plan"; continue
    fi
    if [[ -z "$out" ]]; then printf 'PASS %s\n' "$plan"; continue; fi
    failed=1
    printf 'BLOCK %s\n%s\n' "$plan" "$(jq -r '.reason' <<<"$out" 2>/dev/null || printf '%s' "$out")"
  done <<<"$plans"
  (( ! failed ))
}

# The next action for each plan in the stack. A runnable phase is one its gate
# passes now, so next and the gates never disagree, except that a stopped
# plan's gate may still pass.
cmd_next() {
  local plans plan status status_case parent pstatus prank all=1 action reason skill state
  plans=$(stack_plans "$1")
  while IFS= read -r plan; do [[ "$(status_of "$plan")" == reviewed ]] || all=0; done <<<"$plans"
  while IFS= read -r plan; do
    status=$(status_of "$plan"); parent=$(stacks_on "$plan")
    pstatus=""; prank=3
    if [[ -n "$parent" ]]; then pstatus=$(status_of "$parent"); prank=$(status_rank "$pstatus"); fi
    state=$(review_state "$plan") || fail "Cannot hash $plan: a plan below it is missing or unreadable."
    action=""; reason=""; skill=""
    reason=$(stop_reason "$plan")
    if [[ -n "$reason" ]]; then
      status_case=stopped
    elif [[ "$(status_rank "$status")" != 0 && "$state" == stale ]]; then
      status_case=stale
    else
      status_case=$status
    fi
    case "$status_case" in
      stopped) action=stopped ;;
      stale) action=blocked; reason="its spec or a plan below it changed since its review; return it to planning and review it again (skills/dev/plan.md#stacks)" ;;
      planning|needs-changes|ready)
        if (( ${prank:-0} < 1 )); then action=wait-parent; reason="$parent must be approved first"
        elif [[ "$state" == ready ]]; then action=wait-user; reason='review-feature ready; the user approves it'
        elif [[ "$state" == needs-changes ]]; then action=revise; reason='review-feature needs-changes; revise it (skills/dev/design-feature.md#7-revise-after-review), then review it again'
        else skill=review-feature; fi ;;
      approved|implemented)
        if (( ${prank:-0} < 3 )); then action=wait-parent; reason="$parent must be reviewed first"
        elif [[ "$status" == approved ]]; then skill=execute-feature
        else skill=review-code; fi ;;
      reviewed)
        if (( ${prank:-0} < 3 )); then action=blocked; reason="$parent is '$pstatus'; once it is reviewed, merge it forward into this plan (skills/dev/plan.md#worktree), set Status: implemented, and review-code"
        elif [[ -n "$parent" ]] && ! contains_parent_green "$plan" "$parent"; then
          action=blocked; reason="its reviewed SHA does not contain $parent's; merge it forward (skills/dev/plan.md#worktree), set Status: implemented, and review-code"
        elif [[ "$plan" == "$1" && "$all" == 1 ]]; then skill=create-pr
        else action=done; [[ "$plan" != "$1" ]] || reason='the stack publishes once every plan is reviewed'; fi ;;
      *) action=blocked; reason="unknown status '$status'" ;;
    esac
    if [[ -n "$skill" ]]; then
      reason=$(gate_reason "$skill" "$plan")
      if [[ -z "$reason" ]]; then action=$skill; else action=blocked; reason="$skill: $reason"; fi
    fi
    # One line per plan: a gate reason may span lines.
    reason=${reason//[$'\n\t']/ }
    printf '%s\t%s\t%s\t%s\t%s\n' "$plan" "${status:--}" "${parent:--}" "$action" "${reason:--}"
  done <<<"$plans"
}

# awk for both views: short(s) cuts the plan paths in s (all under pre) to
# their pr<N>; marked(v, dot|mark) prefixes a status or action with its symbol.
VIEW_AWK='
  function short(s,   at, out) {
    out = ""
    while ((at = index(s, pre)) > 0) {
      out = out substr(s, 1, at - 1); s = substr(s, at + length(pre))
      sub(/^[^\/]*\//, "", s)
      if (match(s, /^pr[0-9]+\.spec\.md/)) s = substr(s, 1, RLENGTH - 8) substr(s, RLENGTH + 1)
    }
    return out s
  }
  function pairs(list, map,   a, i) { split(list, a, " "); for (i = 1; (i + 1) in a; i += 2) map[a[i]] = a[i + 1] }
  function marked(v, map) { return ((v in map) ? map[v] : "❔") " " v }
  BEGIN {
    pairs("planning ⚪ needs-changes 🟠 ready 🟤 approved 🔵 implemented 🟡 reviewed 🟢 published 🟣", dot)
    pairs("review-feature ▶ execute-feature ▶ review-code ▶ create-pr ▶ revise ✏️ wait-user 👤 wait-parent ⏳ blocked ⛔ stopped 🛑 done ✅", mark)
  }'

# TSV rows from next as a Markdown table, with "|" escaped and plans shortened
# to pr<N>.
md_view() {
  awk -F'\t' -v pre="$REPO_PLANS/" "$VIEW_AWK"'
    BEGIN { print "| plan | status | parent | action | reason |"; print "|---|---|---|---|---|" }
    {
      for (i = 1; i <= NF; i++) { $i = short($i); gsub(/\|/, "\\|", $i) }
      printf "| %s | %s | %s | %s | %s |\n", $1, marked($2, dot), $3, marked($4, mark), $5
    }'
}

# TSV rows from next, root first and parents before children, as a tree:
# "<prN> <dot> <status>  <mark> <action> — <reason>".
tree_view() {
  awk -F'\t' -v pre="$REPO_PLANS/" "$VIEW_AWK"'
    function show(i, lead, branch, below,   k, last) {
      print lead branch row[i]
      for (k = 1; k <= kids[i]; k++) {
        last = k == kids[i]
        show(kid[i, k], below, last ? "└─ " : "├─ ", below (last ? "   " : "│  "))
      }
    }
    {
      for (i = 1; i <= NF; i++) $i = short($i)
      at[$1] = NR; p = at[$3]
      if (NR > 1) kid[p, ++kids[p]] = NR
      row[NR] = sprintf("%s %s  %s%s", $1, marked($2, dot), marked($4, mark), $5 == "-" ? "" : " — " $5)
    }
    END { if (NR) show(1, "", "", "") }'
}

[[ "${1-}" != --help && "${1-}" != -h ]] || { usage; exit 0; }
[[ $# -eq 2 || ( $# -eq 3 && ( "$1" == review || "$1" == stop || ( "$1" == next && ( "$3" == --tab || "$3" == --tree || "$3" == --md ) ) ) ) ]] || { usage >&2; exit 2; }
command -v jq >/dev/null || fail 'jq is required.'
REPO_ROOT=$(bash "$SCRIPT_DIR/dev-utils.sh" main-root)
cd "$REPO_ROOT"
. "$SCRIPT_DIR/dev-plan-lib.sh"

case "$1" in
  stack) require_live "$2"; stack_plans "$PLAN" ;;
  next)
    require_live "$2"
    if [[ "${3:---tab}" == --tab ]]; then cmd_next "$PLAN"; else rows=$(cmd_next "$PLAN"); "${3#--}_view" <<<"$rows"; fi ;;
  review) [[ $# -eq 3 ]] || { usage >&2; exit 2; }; require_live "$2"; cmd_review "$PLAN" "$3" ;;
  stop) [[ $# -eq 3 ]] || { usage >&2; exit 2; }; require_live "$2"; cmd_stop "$PLAN" "$3" ;;
  resume) require_live "$2"; cmd_resume "$PLAN" ;;
  check) require_live "$2"; cmd_check "$PLAN" ;;
  *) usage >&2; exit 2 ;;
esac
