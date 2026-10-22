#!/usr/bin/env bash
# The stack tree of live plans (../skills/dev/plan.md#stacks), for create-pr
# and run-stack. `review` appends a record to a planning plan; `stop` and
# `resume` append to the stack's stops.log; the rest only read.
set -euo pipefail

SCRIPT_DIR=$(dirname -- "$(realpath -- "${BASH_SOURCE[0]}")")
fail() { printf '%s\n' "$*" >&2; exit 1; }
usage() {
  printf '%s\n' \
    'Usage: dev-stack.sh stack <root plan>' \
    '       dev-stack.sh next <root plan> [--md|--tree]' \
    '       dev-stack.sh review <plan> ready|needs-changes' \
    '       dev-stack.sh stop <plan> <reason>' \
    '       dev-stack.sh resume <plan>' \
    'stack lists the plans, parents before children. next prints, per plan,' \
    '"<plan> <status> <parent> <action> <reason>" tab-separated, with "-" for none;' \
    'action is a runnable phase (review-feature, execute-feature, review-code,' \
    'create-pr), revise after a NEEDS CHANGES review, or stopped, wait-parent,' \
    'wait-user, blocked, or done. --tree prints the stack as a tree instead, and' \
    '--md as a Markdown table, both with a colored dot per status and a mark per' \
    'action.' \
    'review records a review-feature verdict for the current spec. stop records' \
    'in the stack'"'"'s stops.log why run-stack stopped a plan; it holds until the' \
    'plan changes or resume clears it, and one citing "Failed fixes: 3/3" or more' \
    'holds until resume. Only the user runs resume.' \
    '<plan> is ~/work/ai-docs/plans/<repo>/<issue>_<slug>/pr<N>.spec.md, run from the repository.' \
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

# What a stop record is bound to: plan $1's Status value, its spec
# with the specs below it, and its branch's tip. Not the worktree's HEAD: a parent and its
# only child share a worktree, and switching between them changes neither.
stop_key() {
  local hash branch tip=-
  hash=$(plan_hash "$1") || fail "Cannot hash $1: a plan below it is missing or unreadable."
  branch=$(field "$1" Branch)
  [[ -z "$branch" ]] || tip=$(git -C "$REPO_ROOT" rev-parse --verify -q "refs/heads/$branch^{commit}" 2>/dev/null || printf -)
  printf '%s\n%s\n%s\n' "$(field "$1" Status)" "$hash" "$tip" | git hash-object --stdin
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

cmd_review() {
  local verdict hash
  case "$2" in ready) verdict=READY ;; needs-changes) verdict='NEEDS CHANGES' ;; *) usage >&2; exit 2 ;; esac
  [[ "$(status_of "$1")" == planning ]] || fail "$1 is '$(status_of "$1")'; a plan review records only for a planning plan."
  hash=$(plan_hash "$1") || fail "Cannot hash $1: a plan below it is missing, has an unreadable 'Stacks On:' line, or forms a cycle."
  [[ -z "$(tail -c1 "$1")" ]] || printf '\n' >> "$1"
  printf 'Plan review: %s at %s\n' "$verdict" "$hash" >> "$1"
  printf 'Plan review: %s recorded in %s\n' "$verdict" "$1"
}

# The gate's reason for running skill $1 on plan $2; empty when it passes.
gate_reason() {
  local out
  out=$(jq -cn --arg s "dev-$1" --arg a "$2" '{hook_event_name:"PreToolUse",tool_name:"Skill",tool_input:{skill:$s,args:$a}}' |
    bash "$SCRIPT_DIR/gate-check.sh")
  [[ -z "$out" ]] || jq -r '.reason' <<<"$out" 2>/dev/null || printf '%s\n' "$out"
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
    elif [[ "$status" != planning && "$state" == stale ]]; then
      status_case=stale
    else
      status_case=$status
    fi
    case "$status_case" in
      stopped) action=stopped ;;
      stale) action=blocked; reason="its spec or a plan below it changed since its Plan review; return it to planning and review it again (skills/dev/plan.md#stacks)" ;;
      planning)
        if (( ${prank:-0} < 1 )); then action=wait-parent; reason="$parent must be approved first"
        elif [[ "$state" == READY ]]; then action=wait-user; reason='review-feature READY; the user approves it'
        elif [[ "$state" == 'NEEDS CHANGES' ]]; then action=revise; reason='review-feature NEEDS CHANGES; revise it (skills/dev/design-feature.md#7-revise-after-review), then review it again'
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
    pairs("planning ⚪ approved 🔵 implemented 🟡 reviewed 🟢 published 🟣", dot)
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
[[ $# -eq 2 || ( $# -eq 3 && ( "$1" == review || "$1" == stop || ( "$1" == next && ( "$3" == --md || "$3" == --tree ) ) ) ) ]] || { usage >&2; exit 2; }
command -v jq >/dev/null || fail 'jq is required.'
REPO_ROOT=$(bash "$SCRIPT_DIR/dev-utils.sh" main-root)
cd "$REPO_ROOT"
. "$SCRIPT_DIR/dev-plan-lib.sh"

case "$1" in
  stack) require_live "$2"; stack_plans "$PLAN" ;;
  next)
    require_live "$2"
    if [[ $# -eq 2 ]]; then cmd_next "$PLAN"; else rows=$(cmd_next "$PLAN"); "${3#--}_view" <<<"$rows"; fi ;;
  review) [[ $# -eq 3 ]] || { usage >&2; exit 2; }; require_live "$2"; cmd_review "$PLAN" "$3" ;;
  stop) [[ $# -eq 3 ]] || { usage >&2; exit 2; }; require_live "$2"; cmd_stop "$PLAN" "$3" ;;
  resume) require_live "$2"; cmd_resume "$PLAN" ;;
  *) usage >&2; exit 2 ;;
esac
