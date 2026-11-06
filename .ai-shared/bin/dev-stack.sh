#!/usr/bin/env bash
# The stack tree of plans (../skills/dev/plan.md#stacks), for
# design-feature, create-pr, and run-stack. `review` sets a planning plan's
# Status and Spec; `approve` sets a ready one auto-approved; `reopen` returns
# approved plans to planning, and `auto-reopen` auto-approved ones once each; `renumber` and `drop` reshape a stack before
# approval. Each write appends to the stack's log (dev-plan-lib.sh
# stack_log), as do `code-review`, `stop`, and `resume`, and `next` and
# `check` when they record an approval the user set by hand; the rest only
# read.
set -euo pipefail

SCRIPT_DIR=$(dirname -- "$(realpath -- "${BASH_SOURCE[0]}")")
fail() { printf '%s\n' "$*" >&2; exit 1; }
usage() {
  printf '%s\n' \
    'Usage: dev-stack.sh stack <root plan>' \
    '       dev-stack.sh next <root plan> [--tab|--tree|--md]' \
    '       dev-stack.sh review <plan> ready|needs-changes' \
    '       dev-stack.sh approve <plan>' \
    '       dev-stack.sh code-review <plan> pass|needs-changes' \
    '       dev-stack.sh stop <plan> <reason>' \
    '       dev-stack.sh resume <plan>' \
    '       dev-stack.sh reopen <plan>' \
    '       dev-stack.sh auto-reopen <plan>' \
    '       dev-stack.sh renumber <root plan> <old>=<new> ...' \
    '       dev-stack.sh drop <plan>' \
    '       dev-stack.sh check <root plan>' \
    'stack lists the unpublished plans, or every plan once the root is' \
    'published, parents before children. next prints, per listed plan,' \
    '"<plan> <status> <parent> <action> <reason>" tab-separated, with "-" for none' \
    '(--tab, the default);' \
    'action is a runnable phase (review-feature, execute-feature, review-code,' \
    'create-pr), revise after a needs-changes review, or stopped, wait-parent,' \
    'wait-user, blocked, or done. --tree prints the stack as a tree instead, and' \
    '--md as a Markdown table, both with a colored dot per status and a mark per' \
    'action.' \
    'review sets Status to the review-feature verdict, ready or needs-changes,' \
    'and Spec to its hash of the current spec, and logs the round <k>/<limit>;' \
    'code-review logs a review-code verdict the same way. A needs-changes verdict' \
    'on the last round stops the plan. The limit is 3; resume at the limit adds 3.' \
    'approve sets a ready plan, whose review holds and whose parent is approved or later,' \
    'to auto-approved, the agent'"'"'s approval; only the user sets approved. An' \
    'approved plan is frozen: its Status never returns to planning and its spec' \
    'never changes, until the user runs reopen, which returns it and every plan' \
    'above it that is approved or later to planning and clears their stops. stop records in the' \
    'stack'"'"'s log why run-stack stopped a plan; it holds until the plan changes' \
    'or resume clears it, and a round limit or one citing "Failed fixes: 3/3" or' \
    'more holds until resume. Only the user runs resume and reopen.' \
    'auto-reopen, dev-autopilot'"'"'s reopen, returns plans to planning as reopen does when' \
    'the approval of each is auto-approved, once per plan; it clears no stop: the' \
    'Status change ends ordinary stops, and it refuses a round limit or a' \
    '"Failed fixes: 3/3" stop.' \
    'renumber renames unapproved plans never executed, with the Stacks On lines' \
    'and log lines naming them; drop deletes one and restacks its children.' \
    'check runs the review-feature gate, without its parent check, on each plan' \
    'in the stack still in planning, printing PASS or BLOCK and the reason, and' \
    'SKIP for a plan approved or later whose review still holds (BLOCK when it' \
    'does not); it exits 1 on a block.' \
    '<plan> is <main root>/docs/plans/<issue>_<slug>/pr<N>.spec.md, run from the repository.' \
    'Exit: 0 ok, 1 failure, 2 usage.'
}

# A plan of this repository, a regular file; sets PLAN.
require_plan() {
  PLAN=$(canonical_plan "$1") || fail "Plan must be $PLAN_FORMAT: $1"
  [[ -f "$PLAN" && ! -L "$PLAN" ]] || fail "Plan not found: $PLAN"
  index_stack "$PLAN"
}

# An unpublished plan of this repository, a regular file; sets PLAN.
require_live() {
  require_plan "$1"
  ! is_published "$PLAN" || fail "$PLAN is published; no phase resumes it."
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

# stack_plans for stack and next: cleanup publishes the root last, so a
# published root means a published stack, listed whole.
listed_plans() {
  if is_published "$1"; then INCLUDE_PUBLISHED=1 stack_plans "$1"; else stack_plans "$1"; fi
}

# Appends event $2 to plan $1's lines in the stack log (dev-plan-lib.sh
# stack_log).
log_event() {
  printf 'pr%s: %s\n' "$(plan_number "$1")" "$2" >> "$(stack_log "$1")"
}

# stop_key and stop_reason, failing when the plan cannot be hashed.
key_of() { stop_key "$1" || fail "Cannot hash $1: a plan below it is missing or unreadable."; }
stopped_why() { stop_reason "$1" || fail "Cannot hash $1: a plan below it is missing or unreadable."; }

cmd_stop() {
  local key
  [[ -n "$2" && "$2" != *[$'\t\n']* ]] || fail 'A stop reason is one nonempty line without tabs.'
  key=$(key_of "$1")
  log_event "$1" "stop $2 at $key"
  printf 'Stop recorded in %s\n' "$(stack_log "$1")"
}

cmd_resume() {
  log_event "$1" cleared
  printf 'Stop cleared in %s\n' "$(stack_log "$1")"
}

# Records an approval the user set by hand, which writes no log line, at the
# spec its review passed, so the approval ratchet (freeze_reason) binds it too.
# A user's approved over an auto-approved one is recorded as well, so
# auto-reopen never takes it for dev-autopilot's.
note_approval() {
  local rank hash status
  status_get "$1"; status=$REPLY; rank=$(status_rank "$status")
  [[ -n "$rank" ]] && (( rank >= 1 && rank <= 3 )) || return 0
  [[ "$(review_state "$1" || true)" == ready ]] || return 0
  [[ -z "$(approved_hash "$1")" ]] ||
    [[ "$status" == approved && "$(approval_kind "$1")" == auto-approved ]] || return 0
  hash=$(plan_hash "$1") || return 0
  log_event "$1" "approve approved at $hash"
}

# Fails unless plan $1 may take a verdict now: not frozen and not stopped.
require_open() {
  local reason
  reason=$(freeze_reason "$1")
  [[ -z "$reason" ]] || fail "$1 is frozen: $reason."
  reason=$(stopped_why "$1")
  [[ -z "$reason" ]] || fail "$1 is stopped: $reason. Only the user clears it, with dev-stack.sh resume."
}

# Sets Status to verdict $2 and Spec to its hash of the current spec, in place,
# and logs the round; a needs-changes verdict on the last round stops the
# plan until the user's resume.
cmd_review() {
  local hash spec key k
  case "$2" in ready|needs-changes) ;; *) usage >&2; exit 2 ;; esac
  [[ "$(status_rank "$(status_of "$1")")" == 0 ]] || fail "$1 is '$(status_of "$1")'; a verdict records only before approval."
  require_open "$1"
  spec=$(plan_hash "$1") || fail "Cannot hash $1: a plan below it is missing, has an unreadable 'Stacks On:' line, or forms a cycle."
  hash=$(verdict_hash "$spec" "$2")
  key=$(key_of "$1")
  round_budget "$1" review; k=$((ROUND + 1))
  set_header "$1" Status "$2" Spec "$hash" || fail "Cannot write the header of $1."
  log_event "$1" "review $2 ($k/$LIMIT) at $spec"
  printf 'Status: %s, Spec: %s recorded in %s, review-feature round %s/%s\n' "$2" "$hash" "$1" "$k" "$LIMIT"
  if [[ "$2" == needs-changes ]] && (( k >= LIMIT )); then
    log_event "$1" "stop review-feature round limit ($k/$LIMIT) at $key"
    printf 'Stopped: review-feature round limit (%s/%s); only the user grants more rounds, with dev-stack.sh resume.\n' "$k" "$LIMIT"
  fi
}

# Logs review-code's verdict on an implemented plan; a needs-changes verdict
# on the last round stops the plan until the user's resume. Status and Tip
# stay with review-code (skills/dev/review-code.md#finalize).
cmd_code_review() {
  local key k tip
  case "$2" in pass|needs-changes) ;; *) usage >&2; exit 2 ;; esac
  [[ "$(status_of "$1")" == implemented ]] || fail "$1 is '$(status_of "$1")'; review-code verdicts record on an implemented plan."
  require_open "$1"
  key=$(key_of "$1")
  tip=$(git -C "$REPO_ROOT" rev-parse --verify -q "refs/heads/$(field "$1" Branch)^{commit}" 2>/dev/null) || tip=-
  round_budget "$1" code-review; k=$((ROUND + 1))
  log_event "$1" "code-review $2 ($k/$LIMIT) at $tip"
  printf 'review-code %s recorded in %s, round %s/%s\n' "$2" "$(stack_log "$1")" "$k" "$LIMIT"
  if [[ "$2" == needs-changes ]] && (( k >= LIMIT )); then
    log_event "$1" "stop review-code round limit ($k/$LIMIT) at $key"
    printf 'Stopped: review-code round limit (%s/%s); only the user grants more rounds, with dev-stack.sh resume.\n' "$k" "$LIMIT"
  fi
}

# Returns an approved plan, and every plan stacked above it that is approved
# or later, to planning: the user's way past the approval ratchet. Their
# Spec values stay, so each needs review-feature again once revised.
cmd_reopen() {
  local plans plan rank reopened=()
  status_get "$1"; rank=$(status_rank "$REPLY")
  [[ -n "$rank" && ( "$rank" -ge 1 || -n "$(approved_hash "$1")" ) ]] ||
    fail "$1 is '$REPLY'; reopen takes a plan approved or later."
  plans=$(printf '%s\n' "$1"; descendant_plans "$1")
  [[ "$plans" != *'!'* ]] || fail "Unreadable 'Stacks On:' lines in: $(grep '^!' <<<"$plans" | tr -d '!' | tr '\n' ' ')"
  while IFS= read -r plan; do
    status_get "$plan"; rank=$(status_rank "$REPLY")
    [[ -n "$rank" ]] && { (( rank >= 1 )) || [[ -n "$(approved_hash "$plan")" ]]; } || continue
    (( rank == 0 )) || set_header "$plan" Status planning || fail "Cannot write the header of $plan."
    log_event "$plan" reopened
    reopened+=("$plan")
  done <<<"$plans"
  printf 'Reopened to planning: %s\n' "${reopened[*]}"
}

# dev-autopilot's reopen of its own approval (../skills/dev/autopilot.md#decisions):
# reopen, for a plan approved or later whose approval, and that of every plan
# above it that it returns to planning, is dev-stack.sh approve's; once per
# plan, counting a reopen it caused above; never past a held stop.
cmd_auto_reopen() {
  local plans plan rank reason reopened=()
  status_get "$1"; rank=$(status_rank "$REPLY")
  [[ -n "$rank" ]] && (( rank >= 1 )) || fail "$1 is '$REPLY'; auto-reopen takes a plan approved or later."
  plans=$(printf '%s\n' "$1"; descendant_plans "$1")
  [[ "$plans" != *'!'* ]] || fail "Unreadable 'Stacks On:' lines in: $(grep '^!' <<<"$plans" | tr -d '!' | tr '\n' ' ')"
  while IFS= read -r plan; do
    status_get "$plan"; rank=$(status_rank "$REPLY")
    [[ -n "$rank" ]] && { (( rank >= 1 )) || [[ -n "$(approved_hash "$plan")" ]]; } || continue
    [[ "$REPLY" != approved && "$(approval_kind "$plan")" == auto-approved ]] ||
      fail "$plan carries the user's approval, or none recorded; only the user reopens it, with dev-stack.sh reopen."
    (( $(auto_reopens "$plan") == 0 )) ||
      fail "$plan was auto-reopened once; only the user reopens it now, with dev-stack.sh reopen."
    reason=$(stopped_why "$plan")
    [[ -z "$reason" ]] || ! held_stop "$reason" ||
      fail "$plan is stopped: $reason. Only the user clears it, with dev-stack.sh resume."
  done <<<"$plans"
  while IFS= read -r plan; do
    status_get "$plan"; rank=$(status_rank "$REPLY")
    [[ -n "$rank" ]] && { (( rank >= 1 )) || [[ -n "$(approved_hash "$plan")" ]]; } || continue
    (( rank == 0 )) || set_header "$plan" Status planning || fail "Cannot write the header of $plan."
    log_event "$plan" auto-reopened
    reopened+=("$plan")
  done <<<"$plans"
  printf 'Auto-reopened to planning: %s\n' "${reopened[*]}"
}

# Fails unless plan $1 may be renumbered or dropped: before approval, never
# approved, never executed, and not stopped, since a stopped plan dropped and
# rewritten as a new plan would start its round count afresh.
require_movable() {
  local branch reason
  [[ "$(status_rank "$(status_of "$1")")" == 0 && -z "$(approved_hash "$1")" ]] ||
    fail "$1 is '$(status_of "$1")' and approved since its last reopen; only an unapproved plan is renumbered or dropped."
  # Rewritten at its number, an auto-reopened plan would regain its one auto-reopen.
  (( $(auto_reopens "$1") == 0 )) || fail "$1 was auto-reopened; it is revised, never renumbered or dropped."
  reason=$(stopped_why "$1")
  [[ -z "$reason" ]] || fail "$1 is stopped: $reason. It is renumbered or dropped only after its stop ends (skills/dev/run-stack.md)."
  branch=$(field "$1" Branch)
  [[ -z "$branch" ]] || ! branch_exists "$branch" || fail "$1's Branch $branch exists; a plan executed once is revised instead."
  ! is_worktree "$(worktree_path "$(worktree_name "$1")")" || fail "$1 has a worktree; a plan executed once is revised instead."
}

# Rewrites the "pr<N>: " prefixes of the stack log through map $2 of
# "<old> <new>" lines; a new number of "-" marks the lines dropped.
remap_log() {
  local dir=$1 tmp
  [[ -f "$dir/log" ]] || return 0
  tmp=$(mktemp "$dir/log.XXXXXX") || fail "Cannot write the log of $dir."
  MAP="$2" awk 'BEGIN { n = split(ENVIRON["MAP"], l, "\n"); for (i = 1; i <= n; i++) if (split(l[i], f, " ") == 2) to[f[1]] = f[2] }
    match($0, /^pr[0-9]+: /) { k = substr($0, 3, RLENGTH - 4); if (k in to) { $0 = (to[k] == "-" ? "dropped pr" k : "pr" to[k]) substr($0, RLENGTH - 1) } }
    { print }' "$dir/log" > "$tmp" || { rm -f -- "$tmp"; fail "Cannot write the log of $dir."; }
  mv -- "$tmp" "$dir/log"
}

# Renumbers plans in root plan $1's stack by "<old>=<new>" pairs, at once:
# renames each file, rewrites each Stacks On line naming it, and remaps the
# log, so the user or autopilot can split, merge, or insert plans before
# approval (skills/dev/plan.md#stacks).
cmd_renumber() {
  local root=$1 dir=${1%/*} pair old new map="" plan k n parent
  local -A to=() taken=()
  shift
  (( $# > 0 )) || { usage >&2; exit 2; }
  stack_plans "$root" >/dev/null || exit 1
  for pair in "$@"; do
    [[ "$pair" =~ ^([1-9][0-9]*)=([1-9][0-9]*)$ ]] || { usage >&2; exit 2; }
    old=${BASH_REMATCH[1]}; new=${BASH_REMATCH[2]}
    [[ -f "$dir/pr$old.spec.md" ]] || fail "No plan pr$old in $dir."
    [[ ! -v to[$old] ]] || fail "pr$old is renumbered twice."
    [[ ! -v taken[$new] ]] || fail "Two plans would become pr$new."
    require_movable "$dir/pr$old.spec.md"
    to[$old]=$new; taken[$new]=1; map+="$old $new"$'\n'
  done
  # The plans that keep their numbers, and every plan's new parent.
  for plan in "$dir"/pr*.spec.md; do
    [[ -f "$plan" ]] || continue
    n=$(plan_number "$plan")
    if [[ ! -v to[$n] ]]; then
      [[ ! -v taken[$n] ]] || fail "pr$n exists and is not renumbered; it cannot become another plan's number."
      to[$n]=$n
    fi
  done
  for plan in "$dir"/pr*.spec.md; do
    [[ -f "$plan" ]] || continue
    n=$(plan_number "$plan")
    parent=$(stacks_on "$plan") || fail "$plan has an unreadable 'Stacks On:' line."
    [[ -n "$parent" ]] || continue
    k=$(plan_number "$parent")
    (( ${to[$k]} < ${to[$n]} )) || fail "pr${to[$n]} would stack on pr${to[$k]}; a parent's number is below its children's."
    [[ "${to[$k]}" == "$k" ]] || [[ "$(status_rank "$(status_of "$plan")")" == 0 && -z "$(approved_hash "$plan")" ]] ||
      fail "$plan is '$(status_of "$plan")' and stacks on pr$k; renumbering its parent would change its frozen spec."
  done
  for plan in "$dir"/pr*.spec.md; do
    [[ -f "$plan" ]] || continue
    parent=$(stacks_on "$plan"); [[ -n "$parent" ]] || continue
    k=$(plan_number "$parent")
    [[ "${to[$k]}" == "$k" ]] || set_header "$plan" 'Stacks On' "pr${to[$k]}" || fail "Cannot write the header of $plan."
  done
  while IFS=' ' read -r old new; do
    [[ -n "$old" ]] && mv -- "$dir/pr$old.spec.md" "$dir/.renumber-pr$old.spec.md"
  done <<<"$map"
  while IFS=' ' read -r old new; do
    [[ -n "$old" ]] && mv -- "$dir/.renumber-pr$old.spec.md" "$dir/pr$new.spec.md"
  done <<<"$map"
  remap_log "$dir" "$map"
  printf 'Renumbered in %s:\n' "$dir"
  while IFS=' ' read -r old new; do [[ -z "$old" ]] || printf '  pr%s -> pr%s\n' "$old" "$new"; done <<<"$map"
}

# Deletes plan $1, which is unapproved and never executed, and restacks its
# children on its parent; when it is the root, its lowest-numbered child
# becomes the root and the others stack on it (skills/dev/plan.md#stacks).
cmd_drop() {
  local plan=$1 dir=${1%/*} parent children child first="" n tmp
  require_movable "$plan"
  parent=$(stacks_on "$plan") || fail "$plan has an unreadable 'Stacks On:' line."
  children=$(child_plans "$plan")
  [[ "$children" != *'!'* ]] || fail "Unreadable 'Stacks On:' lines in: $(grep '^!' <<<"$children" | tr -d '!' | tr '\n' ' ')"
  while IFS= read -r child; do
    [[ -n "$child" ]] || continue
    [[ "$(status_rank "$(status_of "$child")")" == 0 && -z "$(approved_hash "$child")" ]] ||
      fail "$child is '$(status_of "$child")'; dropping its parent would change its frozen spec."
  done <<<"$children"
  while IFS= read -r child; do
    [[ -n "$child" ]] || continue
    if [[ -n "$parent" ]]; then
      set_header "$child" 'Stacks On' "pr$(plan_number "$parent")" || fail "Cannot write the header of $child."
    elif [[ -z "$first" ]]; then
      first=$child
      tmp=$(mktemp "$child.XXXXXX") && chmod --reference="$child" -- "$tmp" &&
        awk '!done && /^## / { done = 1 } done || !/^Stacks On:/' "$child" > "$tmp" && mv -- "$tmp" "$child" ||
        { rm -f -- "${tmp:-}"; fail "Cannot write the header of $child."; }
    else
      set_header "$child" 'Stacks On' "pr$(plan_number "$first")" || fail "Cannot write the header of $child."
    fi
  done <<<"$children"
  rm -- "$plan"
  n=$(plan_number "$plan")
  remap_log "$dir" "$n -"
  printf 'Dropped %s%s\n' "$plan" "${first:+; $first is the root}"
}

# Sets a ready plan auto-approved: the approval an agent records under
# dev-autopilot (run-stack --auto-approve), kept apart from the user's approved. Spec stays,
# so the gates still bind the approval to the reviewed spec.
cmd_approve() {
  local parent prank hash
  [[ "$(status_of "$1")" == ready && "$(review_state "$1" || true)" == ready ]] ||
    fail "$1 is '$(status_of "$1")'; approve needs a ready plan whose review still holds."
  parent=$(stacks_on "$1") || fail "$1 has an unreadable 'Stacks On:' line."
  if [[ -n "$parent" ]]; then
    prank=$(status_rank "$(status_of "$parent")")
    (( ${prank:-0} >= 1 )) || fail "$parent must be approved or auto-approved first."
  fi
  require_open "$1"
  hash=$(plan_hash "$1") || fail "Cannot hash $1: a plan below it is missing or unreadable."
  set_header "$1" Status auto-approved || fail "Cannot write the header of $1."
  log_event "$1" "approve auto-approved at $hash"
  printf 'Status: auto-approved recorded in %s\n' "$1"
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
# frozen (plan.md#changes), so a revision above it still checks; one that
# breaks the approval ratchet blocks, as in next.
cmd_check() {
  local plans plan status rank out frozen failed=0
  # Not a process substitution: its failure would read as an empty, passing stack.
  plans=$(stack_plans "$1") || exit 1
  while IFS= read -r plan; do
    note_approval "$plan"
    status=$(status_of "$plan"); rank=$(status_rank "$status")
    frozen=$(freeze_reason "$plan")
    if [[ -n "$frozen" ]]; then failed=1; printf 'BLOCK %s\nIt is frozen: %s.\n' "$plan" "$frozen"; continue; fi
    if [[ -n "$rank" ]] && (( rank >= 1 && rank <= 3 )); then
      if [[ "$(review_state "$plan" || true)" == ready ]]; then printf 'SKIP %s (%s)\n' "$plan" "$status"; continue; fi
      failed=1
      printf 'BLOCK %s\nIt is %s, but its spec or a plan below it changed since its review; an approved plan is frozen. The user reverts the change, or reopens it with dev-stack.sh reopen (skills/dev/plan.md#changes).\n' "$plan" "$status"
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
# passes now, so next and the gates never disagree. It also records an
# approval the user set by hand (note_approval).
cmd_next() {
  local plans plan status status_case parent pstatus prank all=1 action reason skill state frozen rounds
  # Not inherited by $(...) under set -e: a failed lookup would print a bogus row.
  plans=$(listed_plans "$1") || exit 1
  while IFS= read -r plan; do [[ "$(status_of "$plan")" == reviewed ]] || all=0; done <<<"$plans"
  while IFS= read -r plan; do
    status=$(status_of "$plan"); parent=$(stacks_on "$plan")
    if [[ "$status" == published ]]; then printf '%s\tpublished\t%s\tdone\t-\n' "$plan" "${parent:--}"; continue; fi
    pstatus=""; prank=3
    if [[ -n "$parent" ]]; then pstatus=$(status_of "$parent"); prank=$(status_rank "$pstatus"); fi
    state=$(review_state "$plan") || fail "Cannot hash $plan: a plan below it is missing or unreadable."
    action=""; reason=""; skill=""
    note_approval "$plan"
    frozen=$(freeze_reason "$plan")
    reason=$(stopped_why "$plan")
    round_budget "$plan" review; rounds="$ROUND/$LIMIT"
    if [[ -n "$frozen" ]]; then
      status_case=frozen; reason=$frozen
    elif [[ -n "$reason" ]]; then
      status_case=stopped
    elif [[ "$(status_rank "$status")" != 0 && "$state" == stale ]]; then
      status_case=stale
    else
      status_case=$status
    fi
    case "$status_case" in
      frozen) action=blocked ;;
      stopped) action=stopped ;;
      stale) action=blocked; reason="its spec or a plan below it changed since its review; an approved plan is frozen. The user reverts the change, or reopens it with dev-stack.sh reopen (skills/dev/plan.md#changes)" ;;
      planning|needs-changes|ready)
        if (( ${prank:-0} < 1 )); then action=wait-parent; reason="$parent must be approved or auto-approved first"
        elif [[ "$state" == ready && "$status" == ready ]]; then action=wait-user; reason="review-feature ready ($rounds); the user approves it, or dev-autopilot auto-approves it"
        elif [[ "$state" == needs-changes ]]; then action=revise; reason="review-feature needs-changes ($rounds); revise it (skills/dev/design-feature.md#7-revise-after-review), then review it again"
        else skill=review-feature; fi ;;
      approved|auto-approved|implemented)
        if (( ${prank:-0} < 3 )); then action=wait-parent; reason="$parent must be reviewed first"
        elif [[ "$status" != implemented ]]; then skill=execute-feature
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
      # The round this review-feature would be, once one was recorded.
      [[ "$action" != review-feature ]] || (( ROUND == 0 )) || reason="round $((ROUND + 1))/$LIMIT"
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
    pairs("planning ⚪ needs-changes 🟠 ready 🟤 approved 🔵 auto-approved 🔷 implemented 🟡 reviewed 🟢 published 🟣", dot)
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
[[ $# -eq 2 || ( $# -eq 3 && ( "$1" == review || "$1" == code-review || "$1" == stop || ( "$1" == next && ( "$3" == --tab || "$3" == --tree || "$3" == --md ) ) ) ) || ( $# -ge 3 && "$1" == renumber ) ]] || { usage >&2; exit 2; }
command -v jq >/dev/null || fail 'jq is required.'
REPO_ROOT=$(bash "$SCRIPT_DIR/dev-utils.sh" main-root)
cd "$REPO_ROOT"
. "$SCRIPT_DIR/dev-plan-lib.sh"

case "$1" in
  stack) require_plan "$2"; listed_plans "$PLAN" ;;
  next)
    require_plan "$2"
    if [[ "${3:---tab}" == --tab ]]; then cmd_next "$PLAN"; else rows=$(cmd_next "$PLAN"); "${3#--}_view" <<<"$rows"; fi ;;
  review) [[ $# -eq 3 ]] || { usage >&2; exit 2; }; require_live "$2"; cmd_review "$PLAN" "$3" ;;
  approve) require_live "$2"; cmd_approve "$PLAN" ;;
  code-review) [[ $# -eq 3 ]] || { usage >&2; exit 2; }; require_live "$2"; cmd_code_review "$PLAN" "$3" ;;
  stop) [[ $# -eq 3 ]] || { usage >&2; exit 2; }; require_live "$2"; cmd_stop "$PLAN" "$3" ;;
  resume) require_live "$2"; cmd_resume "$PLAN" ;;
  reopen) require_live "$2"; cmd_reopen "$PLAN" ;;
  auto-reopen) require_live "$2"; cmd_auto_reopen "$PLAN" ;;
  renumber) require_live "$2"; shift 2; cmd_renumber "$PLAN" "$@" ;;
  drop) require_live "$2"; cmd_drop "$PLAN" ;;
  check)
    require_live "$2"
    plans_ignored || fail "Git does not ignore docs/plans in $REPO_ROOT, so a plan could be committed. Add /docs/plans/ to the global excludes file (git config core.excludesFile) or to .git/info/exclude."
    cmd_check "$PLAN" ;;
  *) usage >&2; exit 2 ;;
esac
