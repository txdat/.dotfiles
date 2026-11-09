#!/bin/bash
# Gate checker for the plan-backed phases (../skills/dev/plan.md#sequence).
# Reads hook JSON from stdin, or a plan after --design (below), and prints
# block JSON when a phase's entry condition fails. Two hook events reach it: PreToolUse for a model-invoked Skill
# call (arguments in tool_input.args; the Pi extension sends
# tool_input.arguments), and UserPromptSubmit for a user-typed /dev-<skill>.
#
# Claude Code also runs it before Bash, Edit, Write, and MultiEdit calls
# (record_guard below) and after Bash calls (bash_post_check), which never
# invoke a phase: it refuses the user's commands, writes to the stack log,
# approvals, and changes to a frozen plan. It is a guardrail against an
# agent's mistakes and shortcuts, not a sandbox (bash_post_check).
#
# Only review-feature, execute-feature, review-code, and create-pr are gated.
# Each checks its entry status; review-feature and review-code also check the
# plan's ID shape (id_report), every gate but review-feature a current ready
# Spec (create-pr for each plan it publishes), and review-code the
# RED/GREEN commit sequence.
# The hook reads identifiers and fields, never prose: whether an AC is right
# or a step satisfies its TC is the reviewer's judgment. It cannot tell who
# set `Status: approved`; only the user does. An agent's approval is
# `auto-approved`, set by dev-stack.sh approve, and passes the same gates.
#
# Plans resolve by exact path only. A dormant plan never captures unrelated
# work, and a gate fires only for its own plan, except that create-pr reads
# every plan's Stacks On line in its directory so a stack publishes together.
# Plans live in the main root's docs/plans, untracked (dev-plan-lib.sh); Git
# checks run in the main root, and proof checks in the plan's worktree.

set -euo pipefail
# Byte-wise text handling: plan IDs and paths are ASCII, and a multibyte
# locale has crashed awk on invalid bytes, which the hook would read as a pass.
export LC_ALL=C

# `--design <plan>`, which hooks never pass, runs the review-feature gate
# without its parent-approval and stop checks, for design-feature
# (dev-stack.sh check, which needs jq itself). Without jq it exits 127 with
# no verdict, never a pass.
DESIGN_CHECK=0
if [[ "${1-}" == --design ]]; then
  DESIGN_CHECK=1
  HOOK_INPUT=$(jq -cn --arg a "${2-}" '{tool_input:{skill:"dev-review-feature",args:$a}}')
else
  HOOK_INPUT=$(cat)
fi

# UserPromptSubmit runs on every prompt, so a missing prerequisite blocks only
# input that could invoke a dev skill.
if ! command -v jq >/dev/null 2>&1; then
  # The record guard fails open without jq: it never gates a phase.
  [[ ! "$HOOK_INPUT" =~ \"tool_name\"[[:space:]]*:[[:space:]]*\"(Bash|Edit|Write|MultiEdit)\" ]] || exit 0
  if [[ "$HOOK_INPUT" == *'"UserPromptSubmit"'* ]]; then
    [[ "$HOOK_INPUT" =~ \"prompt\"[[:space:]]*:[[:space:]]*\"[[:space:]]*/[Dd][Ee][Vv][-:] ]] || exit 0
  else
    [[ "$HOOK_INPUT" == *[Dd][Ee][Vv][-:]* ]] || exit 0
  fi
  printf '{"continue":false,"stopReason":"gate-check.sh requires jq to parse hook input.","decision":"block","reason":"gate-check.sh requires jq to parse hook input."}\n'
  exit 0
fi

block() {
  jq -cn --arg reason "$1" '{continue:false, stopReason:$reason, decision:"block", reason:$reason}'
  exit 0
}

# ── record guard ──────────────────────────────────────────────────────

# What plan.md keeps from agents (skills/dev/plan.md#changes): resume and
# reopen are the user's, only dev-stack.sh writes the stack log, only the
# user sets `approved` and only dev-stack.sh approve `auto-approved` (no
# unapproved plan reaches a later Status otherwise), and an approved plan's
# Status never returns to planning nor its spec changes. An
# edit tool's call is simulated and refused before it lands. A shell command
# is matched as text only for resume, reopen, and log writes; its plan writes
# are judged after it runs, against a snapshot. Anything it cannot read
# passes: it never gates a phase.
record_guard() {
  local tool="$1" cmd probe path real dir old_status new_status old_rank new_rank
  if [[ "$tool" == Bash ]]; then
    cmd=$(jq -r '.tool_input.command? // ""' <<<"$HOOK_INPUT" 2>/dev/null) || return 0
    # dev-stack.sh resume or reopen in command position: at the start, after a
    # separator or newline, or after a runner such as bash or env. A mention
    # inside an argument, such as a grep pattern or a message, passes.
    local user_re="(^|[;&|(]|"$'\n'")[[:space:]]*((bash|sh|exec|env|command|sudo|time|nohup)[[:space:]]+|[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*['\"]?[^[:space:];&|'\"]*dev-stack(\\.sh)?['\"]?[[:space:]]+(resume|reopen)([^A-Za-z0-9_-]|\$)"
    # A stack log path under a repository's docs/plans (a worktree's log/
    # directory is not one), and a write to it: a redirection into it, or a
    # writing tool anywhere in the command.
    local log_path log_re redir_re write_re
    # Either under plans/, or relative from a word's start (cd'd into
    # docs/plans or a stack directory's parent); never followed by "/", as a
    # log/ directory is.
    log_path="plans/[0-9]+_[a-z0-9-]+/log"
    local rel_path="((\\.\\./)*|\\./)?([^/[:space:]'\"]+/)?[0-9]+_[a-z0-9-]+/log" end="([^A-Za-z0-9_./-]|\$)"
    log_re="$log_path$end|(^|[[:space:]'\"=<>])$rel_path$end"
    redir_re="[0-9]*(>>?\|?|>&|&>>?)[[:space:]]*['\"]?([^[:space:]'\"]*$log_path|$rel_path)$end"
    write_re='(^|[^A-Za-z0-9_-])(tee|rm|mv|cp|truncate|dd|install|ln|perl|python3?|ruby|node)([[:space:]]|$)|sed[[:space:]]+(-[A-Za-z]+[[:space:]]+)*-[A-Za-z]*i|sed[[:space:]].*--in-place'
    if [[ "$cmd" =~ $user_re ]]; then
      local verb=resume
      [[ "${BASH_REMATCH[0]}" != *reopen* ]] || verb=reopen
      block "dev-stack.sh $verb is the user's alone: it clears a stop, grants more rounds or fix attempts, or reopens an approved plan. Report the stop and what the user would decide (skills/dev/run-stack.md#stops)."
    fi
    # Redirections to /dev/null or another descriptor write nothing.
    probe=$(sed -E 's#[0-9]*>>?[[:space:]]*/dev/null##g; s#[0-9]*>&[0-9-]##g' <<<"$cmd")
    if [[ "$probe" =~ $redir_re ]] || [[ "$probe" =~ $log_re && "$probe" =~ $write_re ]]; then
      block "The stack log is written only by dev-stack.sh (review, code-review, approve, stop, and autopilot's auto-reopen; resume and reopen are the user's). Read it, never write it (skills/dev/plan.md#changes)."
    fi
    # Plan writes by a shell command are judged after it runs, against this
    # snapshot (bash_post_check): exactly, with no parsing of the command.
    snapshot_plans
    return 0
  fi
  path=$(jq -r '.tool_input.file_path? // ""' <<<"$HOOK_INPUT" 2>/dev/null) || return 0
  [[ -n "$path" ]] || return 0
  real=$(realpath -m -- "$path" 2>/dev/null) || return 0
  [[ "$real" =~ ^(/.*)/docs/plans/[0-9]+_[a-z0-9-]+/[^/]+$ ]] || return 0
  dir=${BASH_REMATCH[1]}
  case "${real##*/}" in
    log) block "The stack log is written only by dev-stack.sh (review, code-review, approve, stop, and autopilot's auto-reopen; resume and reopen are the user's). Read it, never write it (skills/dev/plan.md#changes)." ;;
    pr[1-9]*.spec.md) ;;
    *) return 0 ;;
  esac
  # The plan library resolves plans under REPO_ROOT/docs/plans; the plan's own
  # repository root serves, since no Git call follows.
  REPO_ROOT=$dir
  . "$GATE_DIR/dev-plan-lib.sh" || return 0
  # The plan's text after the call: Write's content, or Edit's and
  # MultiEdit's replacements applied as literal strings to the current file.
  GUARD_TMP=$(mktemp) || return 0
  trap 'rm -f -- "$GUARD_TMP"' EXIT
  local new=$GUARD_TMP
  if [[ "$tool" == Write ]]; then
    jq -j '.tool_input.content? // ""' <<<"$HOOK_INPUT" > "$new" 2>/dev/null || return 0
  else
    [[ -f "$real" ]] || return 0
    jq -j --rawfile f "$real" '
      def apply($e): (split($e.old_string // "")) as $p
        | if ($e.old_string // "") == "" or ($p | length) < 2 then error("no match")
          elif $e.replace_all then $p | join($e.new_string // "")
          else $p[0] + ($e.new_string // "") + ($p[1:] | join($e.old_string)) end;
      .tool_input as $t
      | reduce (if $t.edits then $t.edits[] else $t end) as $e ($f; apply($e))' <<<"$HOOK_INPUT" > "$new" 2>/dev/null || return 0
  fi
  load_plans "$new"
  # Raw Status values: a reviewed plan whose Tip comes later ranks reviewed.
  field_get "$new" Status; new_status=$REPLY
  old_status=""
  if [[ -f "$real" ]]; then field_get "$real" Status; old_status=$REPLY; fi
  [[ "$old_status" != published ]] ||
    block "Plan $real is published; no phase resumes or edits it (skills/dev/plan.md#sequence)."
  if [[ "$new_status" == approved && "$old_status" != approved ]]; then
    block "Only the user sets 'Status: approved' (skills/dev/plan.md#sequence). Under dev-autopilot, run-stack --auto-approve runs dev-stack.sh approve, which sets auto-approved."
  fi
  if [[ "$new_status" == auto-approved && "$old_status" != auto-approved ]]; then
    block "Only dev-stack.sh approve sets 'Status: auto-approved', under run-stack --auto-approve (skills/dev/plan.md#sequence)."
  fi
  old_rank=$(status_rank "$old_status"); new_rank=$(status_rank "$new_status")
  if [[ -z "$old_rank" || "$old_rank" == 0 ]] && { [[ ! -f "$real" ]] || [[ -z "$(approved_hash "$real")" ]]; }; then
    [[ -z "$new_rank" || "$new_rank" == 0 ]] ||
      block "Plan $real is '${old_status:-new}'; it reaches '$new_status' only through approval: the user's 'Status: approved' or dev-stack.sh approve (skills/dev/plan.md#sequence)."
    return 0
  fi
  [[ -n "$new_rank" && "$new_rank" != 0 ]] ||
    block "Plan $real is '$old_status'; an approved plan's Status never returns to planning or to an unknown value. Leave it as it is: a change goes where skills/dev/plan.md#changes says, or the user reopens it with dev-stack.sh reopen."
  spec_get "$real"; local before=$REPLY
  spec_get "$new"
  [[ "$REPLY" == "$before" ]] ||
    block "Plan $real is '$old_status' and frozen: after approval only its Status and Tip lines change. Leave it as it is: a change goes where skills/dev/plan.md#changes says, or the user reopens it with dev-stack.sh reopen."
  return 0
}

# A Bash call's snapshot directory, keyed by its tool_use_id. Fails without
# one: a key shared by parallel calls would let one call's check delete or
# replace another's snapshot. The parent directory must be the user's own.
snap_dir() {
  local id base
  id=$(jq -r '.tool_use_id? // ""' <<<"$HOOK_INPUT" 2>/dev/null) || return 1
  id=${id//[^A-Za-z0-9_-]/}
  [[ -n "$id" ]] || return 1
  base="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/dev-gate-check-$(id -u)"
  mkdir -p -m 700 -- "$base" 2>/dev/null || return 1
  [[ -O "$base" && ! -L "$base" ]] || return 1
  chmod 700 -- "$base" 2>/dev/null || return 1
  printf '%s/%s\n' "$base" "$id"
}

# The main root of the repository the hook input's cwd belongs to; fails when
# cwd resolves to no repository. A command that changes another repository's
# plans goes unchecked.
snap_scope() {
  local cwd
  cwd=$(jq -r '.cwd? // ""' <<<"$HOOK_INPUT" 2>/dev/null) || cwd=""
  [[ -d "$cwd" ]] || cwd=$PWD
  (cd -- "$cwd" && bash "$GATE_DIR/dev-utils.sh" main-root 2>/dev/null)
}

# Plan specs and stack logs under directory $1, relative to it, one per line.
# Follows symlinks, so a stack directory linked elsewhere is still covered.
plan_files() {
  (cd -- "$1" 2>/dev/null && find -L . -mindepth "$2" -maxdepth "$2" -type f \( -name 'pr[1-9]*.spec.md' -o -name log \) 2>/dev/null) | sed 's#^\./##'
}

# Before a Bash call: copies every plan spec and stack log in the docs/plans
# of the cwd's repository (snap_scope). A file it cannot read is skipped, and
# the check after treats it as new. Snapshots older than a day, left by calls
# that never finished, go.
snapshot_plans() {
  local snap scope base
  scope=$(snap_scope) || return 0
  base="$scope/docs/plans"
  snap=$(snap_dir) || return 0
  find "${snap%/*}" -mindepth 1 -maxdepth 1 -mmin +1440 -exec rm -rf -- {} + 2>/dev/null || true
  rm -rf -- "$snap"; mkdir -m 700 -- "$snap" 2>/dev/null || return 0
  printf '%s\n' "$scope" > "$snap/.scope"
  mkdir -p -- "$snap/files"
  [[ ! -d "$base" ]] || plan_files "$base" 2 | tr '\n' '\0' |
    (cd -- "$base" && xargs -0 -r cp -L --parents -p -t "$snap/files" 2>/dev/null) || true
  : > "$snap/.complete"
}

# Plan $1's count of log lines matching the extended regex $2.
log_count() { log_lines "$1" | grep -cE "$2" || true; }
# File $1's count of lines matching the extended regex $2; 0 when missing.
line_count() { [[ -f "$1" ]] || { echo 0; return; }; grep -cE "$2" -- "$1" || true; }

# Restores $2 from snapshot copy $1, replacing whatever stands at $2 (a
# symlink, a hard link, a directory, an unwritable file) with a new file.
restore_file() {
  mkdir -p -- "${2%/*}" && rm -rf -- "$2" && cp -p -- "$1" "$2"
}

# After a Bash call: compares the cwd repository's plans with the snapshot
# and restores any change only dev-stack.sh or the user may make: a frozen
# or published plan changed, moved, or deleted, an approved plan back below
# approved, a plan moved or deleted while the stack log holds its lines, an
# unapproved plan moved to approved or later except by
# dev-stack.sh approve, an approved plan back to planning except by
# dev-stack.sh auto-reopen, or a stack log that lost a stop, review, or
# auto-reopen line, or gained a resume or reopen. It catches an agent's mistakes and shortcuts,
# not an agent set on evading it: a command still running after the call
# returns (a background job) is never compared, a forged log line it cannot
# tell from dev-stack.sh's, and a change the user makes during the call to
# the same repository's plans is restored as the agent's.
bash_post_check() {
  local snap scope base depth=2 rel old new os ns or nr ob frozen why msgs=() logs=() f
  snap=$(snap_dir) || return 0
  [[ -f "$snap/.complete" ]] || return 0
  GUARD_TMP=$snap
  trap 'rm -rf -- "$GUARD_TMP"' EXIT
  scope=$(<"$snap/.scope")
  base="$scope/docs/plans"
  REPO_ROOT=$scope
  . "$GATE_DIR/dev-plan-lib.sh" || return 0
  # Stack logs first: a lost stop or review line acts as the user's resume,
  # and a resume or reopen line is the user's alone (refused before the call).
  while IFS= read -r rel; do
    [[ "$rel" == */log ]] || continue
    old="$snap/files/$rel"; new="$base/$rel"
    why=""
    if (( $(line_count "$new" ': (cleared|reopened)$') > $(line_count "$old" ': (cleared|reopened)$') )); then
      why="it gained a resume or reopen line, which only the user's dev-stack.sh writes"
    else
      for f in ': stop ' ': review ' ': code-review ' ': approve ' ': auto-reopened$'; do
        (( $(line_count "$new" "$f") >= $(line_count "$old" "$f") )) || { why="it lost a line only dev-stack.sh writes"; break; }
      done
    fi
    [[ -n "$why" ]] || continue
    if [[ ! -f "$old" ]]; then
      if rm -f -- "$new"; then msgs+=("$new: $why. Removed: it did not exist before the command.")
      else msgs+=("$new: $why. Could not remove it; tell the user."); fi
    elif restore_file "$old" "$new"; then msgs+=("$new: $why. Restored from before the command.")
    else msgs+=("$new: $why. Could not restore it; tell the user."); fi
  done < <({ plan_files "$snap/files" "$depth"; plan_files "$base" "$depth"; } | sort -u)
  while IFS= read -r rel; do
    old="$snap/files/$rel"; new="$base/$rel"
    [[ ! -f "$old" || ! -f "$new" ]] || ! cmp -s -- "$old" "$new" || continue
    os="" ns="" or="" nr="" ob="" frozen="" why=""
    # load_plans reads only files that exist: awk stops at a missing one.
    [[ ! -f "$old" ]] || load_plans "$old"
    [[ ! -f "$new" ]] || load_plans "$new"
    # Raw Status values: a reviewed plan whose Tip comes later ranks reviewed.
    if [[ -f "$old" ]]; then
      field_get "$old" Status; os=$REPLY; or=$(status_rank "$os")
      spec_get "$old"; ob=$REPLY
      if [[ "$os" == published ]] || { [[ -n "$or" ]] && (( or >= 1 )); } || [[ -n "$(approved_hash "$old")" ]]; then frozen=1; fi
    fi
    if [[ -f "$new" ]]; then field_get "$new" Status; ns=$REPLY; nr=$(status_rank "$ns"); fi
    if [[ -n "$frozen" ]]; then
      spec_get "$new"
      if [[ ! -f "$new" ]]; then why="it is '$os' and was moved or deleted"
      elif [[ "$os" == published ]]; then why="it is published and changed"
      elif [[ "$REPLY" != "$ob" ]]; then why="it is '$os' and its spec changed; after approval only its Status and Tip lines change"
      elif [[ -z "$nr" || "$nr" == 0 ]]; then
        # dev-stack.sh auto-reopen's step: an approval of its own, never
        # auto-reopened before, back to planning with an auto-reopened line.
        [[ "$ns" == planning && "$os" != approved && "$(approval_kind "$old")" == auto-approved ]] &&
          (( $(auto_reopens "$old") == 0 && $(auto_reopens "$new") == 1 )) ||
          why="it is '$os' and its Status went to '$ns'; an approved plan never returns below approved"
      fi
    elif [[ ! -f "$new" ]]; then
      # A plan removed with its log lines left would hand its rounds and stops
      # to the next plan written at its number; dev-stack.sh renumber and drop
      # relabel them.
      f=${rel##*/}; f=${f%.spec.md}
      (( $(line_count "${new%/*}/log" "^$f: ") == 0 )) ||
        why="it was moved or deleted while the stack log still holds its lines; dev-stack.sh renumber moves a plan and drop removes one"
    elif [[ -n "$nr" ]] && (( nr >= 1 )); then
      # Unapproved (or new) and now approved or later: only dev-stack.sh
      # approve's step, from ready to auto-approved at the plan's hash, passes.
      if [[ "$ns" == approved ]]; then why="its Status was set to approved, which only the user sets"
      elif [[ "$ns" != auto-approved ]]; then why="its Status went from '${os:-none}' to '$ns', skipping approval"
      elif [[ "$os" != ready ]] ||
        (( $(log_count "$new" '^approve auto-approved at ') <= $(log_count "$old" '^approve auto-approved at ') )) ||
        [[ "$(log_lines "$new" | grep -E '^approve auto-approved at ' | tail -n 1)" != "approve auto-approved at $(plan_hash "$new" 2>/dev/null || true)" ]]; then
        why="its Status was set to auto-approved, which only dev-stack.sh approve sets, from ready"
      fi
    fi
    [[ -n "$why" ]] || continue
    if [[ -f "$old" ]]; then
      if restore_file "$old" "$new"; then msgs+=("$new: $why. Restored from before the command.")
      else msgs+=("$new: $why. Could not restore it; tell the user."); fi
    elif set_header "$new" Status planning 2>/dev/null; then msgs+=("$new: $why. Set to 'Status: planning'.")
    else msgs+=("$new: $why. Could not set it to planning; tell the user."); fi
  done < <({ plan_files "$snap/files" "$depth"; plan_files "$base" "$depth"; } | grep -E '(^|/)pr[1-9][0-9]*\.spec\.md$' | sort -u)
  # A symlink or hard link to a plan file or stack directory lets an edit
  # tool change a plan through a path outside docs/plans: each gets its
  # own copy again.
  while IFS= read -r f; do
    [[ -L "$base/$f" || ( -f "$base/$f" && "$(stat -c %h -- "$base/$f")" -gt 1 ) ]] || continue
    { cp -rpL -- "$base/$f" "$base/$f.gate.$$" && rm -rf -- "$base/$f" && mv -- "$base/$f.gate.$$" "$base/$f"; } 2>/dev/null ||
      { rm -rf -- "$base/$f.gate.$$"; msgs+=("$base/$f: a link to a plan that could not be replaced with a copy; tell the user."); }
  done < <(cd -- "$base" 2>/dev/null && find -L . -mindepth $((depth - 1)) -maxdepth "$depth" \( -type d -path './*' -name '[0-9]*_*' -o -type f \( -name 'pr[1-9]*.spec.md' -o -name log \) \) 2>/dev/null | sed 's#^\./##' | sort -r)
  (( ${#msgs[@]} )) || return 0
  jq -cn --arg r "$(printf 'A shell command changed plans in a way only dev-stack.sh or the user may (skills/dev/plan.md#changes):\n%s\nChange Status and Tip with the Edit tool; any other change goes where skills/dev/plan.md#changes says, or the user reopens the plan with dev-stack.sh reopen.' "$(printf -- '- %s\n' "${msgs[@]}")")" '{decision:"block", reason:$r}'
}

TOOL_NAME=$(jq -r '.tool_name? // ""' <<<"$HOOK_INPUT" 2>/dev/null || true)
if [[ "$TOOL_NAME" == Bash && "$(jq -r '.hook_event_name? // ""' <<<"$HOOK_INPUT" 2>/dev/null)" == PostToolUse* ]]; then
  GATE_DIR=$(dirname -- "$(realpath -- "${BASH_SOURCE[0]}")")
  bash_post_check
  exit 0
fi
case "$TOOL_NAME" in
  Bash|Edit|Write|MultiEdit) GATE_DIR=$(dirname -- "$(realpath -- "${BASH_SOURCE[0]}")"); record_guard "$TOOL_NAME"; exit 0 ;;
esac

DEV_SKILL_SLUG_RE='create-issue|create-pr|design-feature|design-infra|design-system|execute-feature|explore|fix-bug|review-code|review-feature|review-infra|review-system'

extract_skill_slug() {
  local raw="${1#/}"
  raw="${raw,,}"
  raw="${raw//_/-}"
  case "$raw" in
    dev:*|dev-*) raw="${raw:4}"; [[ "$raw" =~ ^($DEV_SKILL_SLUG_RE)$ ]] && { echo "$raw"; return; } ;;
  esac
  if [[ "$raw" =~ dev[:-]($DEV_SKILL_SLUG_RE) ]]; then echo "${BASH_REMATCH[1]}"; return; fi
  if [[ "$raw" =~ (^|[[:space:]/])($DEV_SKILL_SLUG_RE)([[:space:]]|$) ]]; then echo "${BASH_REMATCH[2]}"; return; fi
  echo ""
}

HOOK_EVENT=$(jq -r '.hook_event_name? // ""' <<<"$HOOK_INPUT" 2>/dev/null || true)
if [[ "$HOOK_EVENT" == UserPromptSubmit ]]; then
  # Only a leading slash command invokes a skill; prose that mentions one is
  # never gated.
  PROMPT=$(jq -r '.prompt? // ""' <<<"$HOOK_INPUT" 2>/dev/null || true)
  [[ "$PROMPT" =~ ^[[:space:]]*/([Dd][Ee][Vv][-:][A-Za-z_-]+)([^A-Za-z0-9_-]|$) ]] || exit 0
  RAW_SKILL="${BASH_REMATCH[1]}"
else
  RAW_SKILL=$(
    jq -r '
      [
        .tool_input.skill?, .tool_input.skill_name?, .tool_input.name?, .tool_input.arguments?,
        .skill?, .skill_name?, .arguments.skill?,
        # A command field names a skill only as a slash command: Gemini runs
        # this hook for every tool, and a shell command mentioning one is not
        # an invocation.
        (.tool_input.command?, .command? | select(type == "string" and test("^\\s*/dev[-:]"; "i")))
      ]
      | map(select(type == "string" and length > 0))
      | .[0] // ""
    ' <<<"$HOOK_INPUT" 2>/dev/null || true
  )
fi
SKILL_SLUG=$(extract_skill_slug "$RAW_SKILL")
case "$SKILL_SLUG" in
  review-feature|execute-feature|review-code|create-pr) ;;
  # Everything else is ungated and runs outside a Git repository too.
  *) exit 0 ;;
esac

# A gated phase fails closed: a crash or unexpected error prints no verdict,
# which the hook would take as a pass.
trap 'rc=$?; (( rc == 0 )) || block "gate-check.sh failed (exit $rc) before reaching a verdict; this blocks rather than passing. Check the plan for invalid bytes or report the failure."' EXIT

# Exact-path checks canonicalise with realpath -m; probe the flag, since
# macOS ships a realpath without it.
realpath -m -- / >/dev/null 2>&1 || block "gate-check.sh requires realpath with -m support (GNU coreutils) to validate plan paths."

GATE_DIR=$(dirname -- "$(realpath -- "${BASH_SOURCE[0]}")")
REPO_ROOT=$(bash "$GATE_DIR/dev-utils.sh" main-root 2>/dev/null) || block "Cannot resolve the main working-tree root; do not substitute the current linked worktree."
cd "$REPO_ROOT" || block "Cannot access the main working-tree root: $REPO_ROOT"
# Git history checks run here, repointed to the plan's worktree when it has one.
GIT_TREE="$REPO_ROOT"

HOOK_TEXT=$(
  jq -r '[.tool_input.args?, .tool_input.arguments?, .tool_input.command?, .arguments?, .command?, .prompt?]
    | map(select(type == "string")) | join(" ")' <<<"$HOOK_INPUT" 2>/dev/null || true
)

. "$GATE_DIR/dev-plan-lib.sh"

# ── plan resolution ───────────────────────────────────────────────────

# Exactly one plan path, which must resolve: a typo or foreign path blocks
# rather than leaving another path to bind.
resolve_plan() {
  local mention doc seen=$'\n' named=()
  while IFS= read -r mention; do
    [[ -n "$mention" ]] || continue
    doc=$(canonical_plan "$mention") || block "Named plan not found: $mention. Pass the full path of an existing $PLAN_FORMAT of this repository."
    if [[ "$seen" == *$'\n'"$doc"$'\n'* ]]; then continue; fi
    seen+="$doc"$'\n'
    named+=("$doc")
  done < <(plan_mentions "$HOOK_TEXT")
  (( ${#named[@]} > 0 )) || block "${SKILL_SLUG} operates on a plan and none was named. Pass its exact path: ${SKILL_SLUG} $PLAN_FORMAT. A slug or the only plan in a directory does not resolve. No plan yet → run design-feature first."
  (( ${#named[@]} == 1 )) || block "${SKILL_SLUG} takes one plan path; ${#named[@]} were named: ${named[*]}. Pass only the plan; its Stacks On parent is read from its header."
  [[ -f "${named[0]}" ]] || block "Named plan not found: ${named[0]}. Pass an existing $PLAN_FORMAT."
  PLAN="${named[0]}"
}

load_plan() {
  [[ ! -L "$PLAN" ]] || block "Plan $PLAN is a symlink; a plan is a regular file (skills/dev/plan.md#artifact)."
  STATUS=$(status_of "$PLAN")
  # Before anything else: a published record ends delivery.
  [[ "$STATUS" != published ]] ||
    block "Plan $PLAN is published; no phase resumes it. For follow-up work, start a new stack in a new directory with design-feature."
  local wt reason
  reason=$(freeze_reason "$PLAN")
  [[ -z "$reason" ]] || block "Plan $PLAN is frozen: $reason."
  # design-feature's stack check runs on plans run-stack may hold stopped.
  if (( ! DESIGN_CHECK )); then
    reason=$(stop_reason "$PLAN") || block "Cannot hash $PLAN with the plans below it: one is missing or has an unreadable 'Stacks On:' line."
    [[ -z "$reason" ]] || block "Plan $PLAN is stopped: $reason. Only the user clears it, with dev-stack.sh resume (skills/dev/run-stack.md#stops)."
  fi
  wt=$(worktree_of "$PLAN")
  [[ -z "$wt" ]] || GIT_TREE="$wt"
}

# Plan $1 has a worktree; the block names where it belongs.
require_worktree() {
  local plan="${1-$PLAN}" name
  [[ -z "$(worktree_of "$plan")" ]] || return 0
  name=$(worktree_name "$plan")
  block "Plan $plan has no worktree at $(worktree_path "$name"). Create it with dev-worktree.sh create $name $(field "$plan" Branch) <PR target>, which reattaches an existing Branch. If publication cleanup removed it, rerun dev-publish.sh cleanup on the plans not yet published (skills/dev/plan.md#worktree)."
}

# The plan's worktree is on its Branch.
require_head() {
  local branch head
  branch=$(field "$PLAN" Branch)
  head=$(git -C "$GIT_TREE" symbolic-ref --quiet --short HEAD 2>/dev/null || true)
  [[ "$head" == "$branch" ]] || block "Worktree $GIT_TREE is on '${head:-a detached HEAD}', not this plan's branch '$branch'; switch it to '$branch' before $SKILL_SLUG (skills/dev/plan.md#worktree)."
}

# The directory's issue agrees with the header, and the type is known.
check_name() {
  local num issue type want
  num=$(basename -- "$(dirname -- "$PLAN")"); num="${num%%_*}"
  issue=$(field "$PLAN" Issue)
  case "$issue" in
    none) want=0 ;;
    \#[1-9]*) want="${issue#\#}"; [[ "$want" =~ ^[0-9]+$ ]] || want="" ;;
    *) want="" ;;
  esac
  [[ -n "$want" ]] || block "Plan header has 'Issue: $issue'; write 'Issue: #<n>' or 'Issue: none' (skills/dev/plan.md#schema)."
  [[ "$num" == "$want" ]] || block "Plan directory starts with $num, but the header has 'Issue: $issue'. The directory's <issue> is the issue number, or 0 for none; fix the header, or move the stack."
  type=$(field "$PLAN" Type); type="${type,,}"
  [[ "$type" =~ ^(feature|fix|refactor|config)$ ]] || block "Plan header has 'Type: $type'; write feature, fix, refactor, or config (skills/dev/plan.md#schema)."
}

STACKS_ON_HELP="Write it as one plain header line, 'Stacks On: pr<K>', naming a plan in the same directory with a lower number, or delete it for the stack's root (skills/dev/plan.md#stacks)."

# A stacked plan enters review once its parent is approved, and execution and
# code review once it is reviewed. The whole stack publishes at once, so the
# parent is unpublished until then. Sets PARENT_PLAN, empty for the root.
require_parent_rank() {
  local need="$1" need_name="$2" status rank
  PARENT_PLAN=$(stacks_on "$PLAN") || block "Plan has a 'Stacks On:' line that is misplaced, repeated, or malformed. $STACKS_ON_HELP"
  [[ -n "$PARENT_PLAN" ]] || return 0
  [[ -f "$PARENT_PLAN" ]] || block "Parent plan $PARENT_PLAN does not exist. Fix the 'Stacks On:' line."
  status=$(status_of "$PARENT_PLAN")
  [[ "$status" != published ]] ||
    block "Parent plan $PARENT_PLAN is published, and a published plan never becomes a parent. Wait until its stack merges, then start a new stack in a new directory on Base (skills/dev/plan.md#stacks)."
  rank=$(status_rank "$status")
  [[ -n "$rank" ]] && (( rank >= need )) ||
    block "Parent plan $PARENT_PLAN is '$status'; ${SKILL_SLUG} needs it '$need_name' or later (skills/dev/plan.md#stacks)."
}

# A directory holds one stack: exactly one plan in it has no Stacks On line.
require_one_root() {
  local roots n
  roots=$(root_plans "$PLAN")
  n=$(grep -c . <<<"$roots" || true)
  # None is left to the checks of the plan's own Stacks On line and parent.
  (( n <= 1 )) || block "Plan directory $(dirname -- "$PLAN") holds $n plans without a 'Stacks On:' line; a directory holds one stack with one root. Stack the others on a plan in it, or move them to their own directory (skills/dev/plan.md#stacks)."
}

# ── ID shape ──────────────────────────────────────────────────────────

# Format and closure of a plan's IDs (../skills/dev/plan.md#schema): AC <- TC
# (Proves:) <- ST (satisfies).
# It proves every ID is well formed, declared once, and linked, never that an
# edge is true.
#
# Output classes the caller keeps apart: `!` means the IDs could not be read
# (ranges, leading zeros, duplicates, a missing section, a bad
# Proves:), so no closure verdict follows; a false traceability block would
# teach readers to distrust the hook. `@` is a citation of another artifact's
# ID. Anything else is a closure finding.
id_report() {
  awk '
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    function bad(msg) { printf "!%s\n", msg; unreadable = 1 }
    # Registry IDs on s into ids[1..n]. awk has no \b: an ID must not continue
    # a longer word ("UTC-7", "fix-ST-1"), and a #-qualified ID belongs to
    # another artifact. "TC-2/TC-9" yields both.
    function scan(s,   n, tok, pre, post, off, at) {
      n = 0; off = 0; split("", ids)
      while (match(substr(s, off + 1), /[A-Z][A-Z]-[0-9]+/)) {
        at = off + RSTART
        tok = substr(s, at, RLENGTH)
        pre = at > 1 ? substr(s, at - 1, 1) : ""
        post = substr(s, at + RLENGTH, 1)
        off = at + RLENGTH - 1
        if (pre ~ /[A-Za-z0-9_#-]/ || post ~ /[A-Za-z0-9_]/) continue
        if (!(substr(tok, 1, 2) in owner)) continue
        ids[++n] = tok
      }
      return n
    }
    function pfx(id) { return substr(id, 1, 2) }

    BEGIN {
      owner["AC"] = "Acceptance Criteria"; owner["TC"] = "Test Cases"
      owner["ST"] = "Implementation Steps"; owner["PC"] = "Implementation Steps"
      owner["DD"] = "Design Decisions"
    }

    /^[[:space:]]*(```|~~~)/ { fenced = !fenced; next }
    fenced { next }

    /^## / { sec = trim(substr($0, 4)); next }

    {
      line = $0

      # A range hides IDs the parser must see. Both operands carry the prefix
      # (or the second is a bare number), and a dash separator is unspaced, so
      # "TC-1 - 200 returned" and "TC-2 — TC-1 variant" are not ranges.
      for (p in owner) {
        if (line ~ (p "-[0-9]+([[:space:]]+(through|thru|to)[[:space:]]+|[[:space:]]*\\.\\.[[:space:]]*|–|-)" p "-[0-9]+") ||
            line ~ (p "-[0-9]+[[:space:]]+(through|thru|to)[[:space:]]+[0-9]+") ||
            line ~ (p "-[0-9]+(–|-)[0-9]+") ||
            line ~ (p "-[0-9]+[[:space:]]*\\.\\.[[:space:]]*[0-9]+")) {
          bad(sprintf("line %d uses an ID range (%s) — list IDs one by one", NR, trim(line)))
          break
        }
      }

      # A plan cites only its own IDs. Any path-like token before #ID counts
      # (be.md#, be#, x.yaml#, `be.md`#).
      if (match(line, /[A-Za-z0-9_\/.`-]#[A-Z][A-Z]-[0-9]+/))
        printf "@line %d cites another artifact\047s ID (%s)\n", NR, trim(line)

      n = scan(line)
      lead = line
      sub(/^[[:space:]]*([-*|][[:space:]]*|#+[[:space:]]+)?/, "", lead)
      # A line in the owning section that begins with an ID declares it.
      decl = ""
      if (n > 0 && index(lead, ids[1]) == 1 && owner[pfx(ids[1])] == sec) decl = ids[1]

      if (sec == "Test Cases") {
        if (decl ~ /^TC-/) {
          curtc = decl; proves[curtc] = ""; provesline[curtc] = 0
        } else if (line ~ /^[^[:space:]]/ && line !~ /^([-*][[:space:]]*)?[A-Za-z][A-Za-z ]*:/) {
          # A new unindented item that is not a TC or one of its fields ends
          # the current TC, so a later Proves: is not misattributed.
          curtc = ""
        }
        if (line ~ /^[[:space:]]*([-*][[:space:]]*)?Proves:/ && curtc != "") {
          np = 0
          for (i = 1; i <= n; i++) if (pfx(ids[i]) == "AC") { np++; last = ids[i] }
          if (provesline[curtc] > 0)
            bad(sprintf("%s has more than one Proves: line (lines %d and %d) — exactly one is required", curtc, provesline[curtc], NR))
          provesline[curtc] = NR
          if (np == 0) bad(sprintf("%s has an unparseable Proves: line (%s)", curtc, trim(line)))
          else if (np > 1) bad(sprintf("%s names %d ACs in Proves: — exactly one is required", curtc, np))
          else proves[curtc] = last
        }
      }

      if (n == 0) next
      for (i = 1; i <= n; i++) {
        if (ids[i] ~ /-0+$/) bad(sprintf("line %d: %s — IDs start at 1", NR, ids[i]))
        else if (ids[i] ~ /-0/) bad(sprintf("line %d: %s has a leading zero — write %s-%d", NR, ids[i], pfx(ids[i]), substr(ids[i], 4) + 0))
      }

      if (decl != "") {
        # A reused ID is two items wearing one name, so it is unreadable.
        if (decl in declared) bad(sprintf("%s is declared more than once (lines %d and %d) — IDs must be unique", decl, declared[decl], NR))
        else { declared[decl] = NR; order[++nd] = decl; count[pfx(decl)]++ }
      }

      for (i = (decl != "" ? 2 : 1); i <= n; i++)
        if (!(ids[i] in refline)) { refline[ids[i]] = NR; reforder[++nr] = ids[i] }

      # A PC carries a Check, never a count of matches, which an unrelated
      # merge can change (skills/dev/design-feature.md#3-write-the-spec).
      if (decl ~ /^PC-/) {
        if (!match(line, /(—|–|-)[[:space:]]*Check:[[:space:]]*[^[:space:]]/))
          printf "%s has no \"— Check: <command>\": %s\n", decl, trim(line)
        else {
          chk = substr(line, RSTART); chk = substr(chk, index(chk, "Check:") + 6)
          if (chk ~ /(^|[^A-Za-z0-9_-])(grep|rg)[[:space:]]([^|;&]*[[:space:]])?(-[A-Za-z]*c[A-Za-z]*|--count)([[:space:]);|&"\047`]|$)/ ||
              chk ~ /(^|[^A-Za-z0-9_-])wc[[:space:]]([^|;&]*[[:space:]])?(-[A-Za-z]*l[A-Za-z]*|--lines)([[:space:]);|&"\047`]|$)/)
            printf "%s counts matches (grep -c, rg -c, wc -l); check the structure instead, such as a definition with grep -q or a forbidden use with ! grep -q: %s\n", decl, trim(line)
        }
      }

      # A step satisfies the TCs its satisfies clause names, on its own line
      # or a continuation line. A TC mentioned in prose is only a reference.
      if (sec == "Implementation Steps") {
        if (decl ~ /^ST-/) { curst = decl; stref[curst] = 0; sttxt[curst] = trim(line) }
        if (curst != "" && (at = index(tolower(line), "satisfies")) > 0) {
          m = scan(substr(line, at))
          for (i = 1; i <= m; i++) if (pfx(ids[i]) == "TC") { tcsat[ids[i]] = tcsat[ids[i]] " " curst; stref[curst]++ }
        }
      }
    }

    END {
      if (!count["AC"]) bad("no AC- entries under ## Acceptance Criteria")
      if (!count["TC"]) bad("no TC- entries under ## Test Cases")
      if (!count["ST"]) bad("no ST- entries under ## Implementation Steps")
      if (unreadable) exit
      for (i = 1; i <= nr; i++) {
        id = reforder[i]
        if (!(id in declared)) printf "line %d cites %s, which is not declared: no line in ## %s begins with it\n", refline[id], id, owner[pfx(id)]
      }
      for (i = 1; i <= nd; i++) {
        id = order[i]
        if (id ~ /^AC-/) {
          found = 0
          for (t in proves) if (proves[t] == id) found = 1
          if (!found) printf "%s has no TC — no Test Case names it in Proves:\n", id
        } else if (id ~ /^TC-/) {
          if (proves[id] == "") printf "%s has no Proves: line — every TC names exactly one AC\n", id
          if (!(id in tcsat)) printf "%s is not satisfied by any Implementation Step\n", id
        } else if (id ~ /^ST-/) {
          if (stref[id] == 0) printf "%s has no satisfies clause naming a TC: %s\n", id, sttxt[id]
        }
      }
    }
  ' "$1" 2>/dev/null
}

require_ids() {
  local report
  report=$(id_report "$PLAN")
  [[ -n "$report" ]] || return 0
  if [[ "$report" == *$'\n'!* || "$report" == !* ]]; then
    block "$(printf 'gate-check.sh cannot read the IDs in %s; fix them per skills/dev/plan.md#schema and re-run. This is NOT a traceability verdict:\n%s' "$PLAN" "$(sed 's/^[!@]//' <<<"$report")")"
  fi
  if [[ "$report" == *$'\n'@* || "$report" == @* ]]; then
    block "$(printf "%s cites another artifact's IDs. A plan cites only its own IDs; refer to other artifacts by path and restate contract facts as PCs (skills/dev/plan.md#schema):\n%s" "$PLAN" "$(sed -n 's/^@//p' <<<"$report")")"
  fi
  block "$(printf 'The plan shape in %s fails: its ID graph is not closed, or a PC lacks a Check or counts matches (skills/dev/plan.md#schema, skills/dev/design-feature.md#3-write-the-spec):\n%s\n\nThis is shape, not correctness: fixing these does not make an edge or a Check right.' "$PLAN" "$report")"
}

# ── branch and proof ──────────────────────────────────────────────────

# The plan names its own branch, distinct from Base.
require_branch() {
  local branch base
  branch=$(field "$PLAN" Branch); base=$(field "$PLAN" Base)
  [[ -n "$base" ]] || block "Plan header has no Base branch. Set it to the branch the stack is based on, then re-run."
  [[ -n "$branch" ]] && git check-ref-format --branch "$branch" >/dev/null 2>&1 ||
    block "Plan header has 'Branch: $branch'; set it to the valid, new branch this plan's PR comes from (skills/dev/plan.md#schema)."
  [[ "$branch" != "$base" ]] || block "Plan's Branch is its Base, '$base'; the plan's PR needs its own branch."
}

# A commit in the plan's tree, or failure.
tree_sha() { git -C "$GIT_TREE" rev-parse --verify -q "$1^{commit}" 2>/dev/null; }

# Sets REVIEW_BASE, where the plan's branch leaves its PR target. For Base,
# the fork point from origin/<Base> (or the local branch without one), as
# dev-publish.sh resolves it: Base may advance without the plan merging it.
# For a parent plan's branch, its tip, which the branch must contain; that
# branch may exist only as origin/<branch> after cleanup.
resolve_review_base() {
  local sha
  if [[ -z "$PARENT_PLAN" ]]; then
    sha=$(tree_sha "refs/remotes/origin/$1" || tree_sha "refs/heads/$1") || return 1
    REVIEW_BASE=$(git -C "$GIT_TREE" merge-base "$sha" HEAD 2>/dev/null)
  else
    sha=$(tree_sha "refs/heads/$1" || tree_sha "refs/remotes/origin/$1") || return 1
    git -C "$GIT_TREE" merge-base --is-ancestor "$sha" HEAD 2>/dev/null && REVIEW_BASE="$sha"
  fi
}

# PROOF_RE and PROOF_WHAT for plan $1: refactors prove the preserved behavior
# with a passing baseline commit, config plans with their TC checks at the
# tip and no proof commit (PROOF_RE empty), the rest with a failing test.
proof_kind() {
  case "$(field "$1" Type | tr '[:upper:]' '[:lower:]')" in
    refactor) PROOF_RE='^test:[[:space:]]*baseline' PROOF_WHAT="'test: baseline'" ;;
    config) PROOF_RE='' PROOF_WHAT='implementation' ;;
    *) PROOF_RE='^test\(red\):' PROOF_WHAT="'test(red):'" ;;
  esac
}

# Plan $1's reviewed SHA holds its proof after base $2, as review-code checked;
# a status set by hand does not skip it.
require_reviewed_proof() {
  local green
  green=$(green_of "$1")
  proof_kind "$1"
  local what="$PROOF_WHAT commit followed by implementation"
  [[ -n "$PROOF_RE" ]] || what="implementation commit"
  [[ -n "$2" ]] && proof_sequence_ok "$2" "$PROOF_RE" "$green" ||
    block "Plan $1's reviewed SHA $green has no $what after ${2:-its PR target}; run review-code on it (skills/dev/plan.md#verification)."
}

# The plan needs a proof commit followed by at least one implementation
# commit, and nothing may precede the first proof. Topological order, so a
# repair merged forward reads as one line of history whatever its dates. A
# merge commit implements nothing, so it never completes the proof; a
# test(update) commit, a revised plan's test change, is neither proof nor
# implementation (plan.md#verification).
proof_sequence_ok() {
  # A config plan needs only a commit of its own.
  if [[ -z "$2" ]]; then
    [[ -n "$(git -C "$GIT_TREE" log --format=%H --no-merges "$1..${3:-HEAD}" 2>/dev/null)" ]]
    return
  fi
  # ENVIRON, not -v, so awk applies no escape processing to the regex.
  git -C "$GIT_TREE" log --format='%s' --topo-order --no-merges --reverse "$1..${3:-HEAD}" 2>/dev/null |
    PROOF_RE="$2" awk '
      /^test\(update\):/ { next }
      $0 ~ ENVIRON["PROOF_RE"] { if (waiting) bad = 1; proofs++; waiting = 1; seen = 1; next }
      { if (!seen) bad = 1; waiting = 0 }
      END { if (proofs < 1 || waiting || bad) exit 1 }'
}

# Plan $1 shares parent plan $2's Base and has its own branch; rechecked
# until the parent publishes, since its revision can change either.
require_stacked() {
  local base parent_base branch parent_branch
  base=$(field "$1" Base); parent_base=$(field "$2" Base)
  [[ "$base" == "$parent_base" ]] ||
    block "Plan $1 has 'Base: $base', but its parent plan $2 has 'Base: $parent_base'; a stacked plan uses its parent's Base (skills/dev/plan.md#stacks)."
  branch=$(field "$1" Branch); parent_branch=$(field "$2" Branch)
  [[ -n "$parent_branch" && "$branch" != "$parent_branch" ]] ||
    block "Plan $1 has 'Branch: $branch', but its PR targets its parent plan's branch, '${parent_branch:-none recorded}'; each plan has its own branch (skills/dev/plan.md#stacks)."
}


# ── gates ─────────────────────────────────────────────────────────────

review_feature_gate() {
  case "$STATUS" in
    planning|needs-changes|ready) ;;
    approved|auto-approved) block "Plan is already $STATUS. Run execute-feature next." ;;
    implemented|reviewed) block "Plan status is '$STATUS' — too late for review-feature. Continue forward." ;;
    *) block "Plan status is '$STATUS' — expected 'planning', 'needs-changes', or 'ready'. Run design-feature first." ;;
  esac
  check_name
  # design-feature checks a stack before the user approves any of it.
  if (( DESIGN_CHECK )); then require_parent_rank 0 planning; else require_parent_rank 1 approved; fi
  require_ids
  require_branch
  [[ -z "$PARENT_PLAN" ]] || require_stacked "$PLAN" "$PARENT_PLAN"
}

# The spec, with the specs below it, is the one review-feature passed, by its
# Spec: a change after review voids the user's approval of it.
require_current_review() {
  local plan="${1:-$PLAN}" state
  state=$(review_state "$plan") || block "Cannot hash $plan with the plans below it: one is missing or has an unreadable 'Stacks On:' line."
  [[ "$state" == ready ]] ||
    block "Plan $plan has no ready 'Spec:' hash for its current spec and the specs below it: it changed after review-feature, its verdict was needs-changes, or no verdict was recorded. An approved plan is frozen: the user reverts the change, or reopens it with dev-stack.sh reopen (skills/dev/plan.md#changes)."
}

execute_feature_gate() {
  case "$STATUS" in
    approved|auto-approved) ;;
    planning) block "Plan status is 'planning' — not approved. Run review-feature; then the user sets 'Status: approved', or dev-autopilot 'auto-approved'." ;;
    needs-changes) block "Plan status is 'needs-changes' — not approved. Revise it, then run review-feature again." ;;
    ready) block "Plan status is 'ready' — awaiting approval: the user sets 'Status: approved', or dev-autopilot 'auto-approved'." ;;
    implemented) block "Plan is already implemented. Run review-code next." ;;
    reviewed) block "Plan is already reviewed. Run create-pr next." ;;
    *) block "Plan status is '$STATUS' — expected 'approved' or 'auto-approved'." ;;
  esac
  require_parent_rank 3 reviewed
  require_branch
  [[ -z "$PARENT_PLAN" ]] || require_stacked "$PLAN" "$PARENT_PLAN"
  require_current_review
  # Resuming on an existing Branch happens in the plan's worktree, on it.
  if branch_exists "$(field "$PLAN" Branch)"; then require_worktree; require_head; fi
}

review_code_gate() {
  local target branch count
  case "$STATUS" in
    implemented) ;;
    planning|needs-changes|ready|approved|auto-approved) block "Plan status is '$STATUS' — not yet implemented. Run execute-feature first." ;;
    reviewed) block "Plan is already reviewed. Run create-pr next." ;;
    *) block "Plan status is '$STATUS' — expected 'implemented'." ;;
  esac
  require_worktree
  # A parent revised since execution returns this plan to its repair.
  require_parent_rank 3 reviewed
  require_branch
  [[ -z "$PARENT_PLAN" ]] || require_stacked "$PLAN" "$PARENT_PLAN"
  require_current_review
  # Re-checked here: the gate before execution may not have run.
  require_ids
  require_head
  branch=$(field "$PLAN" Branch)
  target=$(pr_target "$PLAN")
  resolve_review_base "$target" || block "The PR target '$target' is missing or is not an ancestor of '$branch'. If a repair landed on the parent plan's branch, merge it forward first (skills/dev/plan.md#worktree)."
  proof_kind "$PLAN"
  if [[ -n "$PROOF_RE" ]]; then
    count=$(git -C "$GIT_TREE" log --format=%s "$REVIEW_BASE..HEAD" 2>/dev/null | grep -Ec "$PROOF_RE" || true)
  else
    count=$(git -C "$GIT_TREE" log --format=%H --no-merges "$REVIEW_BASE..HEAD" 2>/dev/null | grep -c . || true)
  fi
  (( count >= 1 )) || block "Found no $PROOF_WHAT commit between $target and $branch (skills/dev/plan.md#verification)."
  proof_sequence_ok "$REVIEW_BASE" "$PROOF_RE" || block "Proof is out of sequence: each $PROOF_WHAT commit needs at least one implementation commit after it, and nothing may come before the first (skills/dev/plan.md#verification)."
}

# Plan $1's Status of reviewed rests on a review-code pass logged at its Tip.
require_passed() {
  passed_at_tip "$1" ||
    block "Plan $1 is reviewed, but its last review-code verdict in the stack log is not a pass at its Tip $(green_of "$1"). Run review-code and record its verdict with dev-stack.sh code-review; the main agent sets reviewed only after a logged pass (skills/dev/review-code.md#finalize)."
}

create_pr_gate() {
  case "$STATUS" in
    reviewed) ;;
    implemented) block "Plan status is 'implemented' — run review-code first." ;;
    planning|needs-changes|ready|approved|auto-approved) block "Plan status is '$STATUS' — not yet executed. Continue the workflow." ;;
    *) block "Plan status is '$STATUS' — expected 'reviewed'." ;;
  esac
  require_worktree
  require_current_review
  require_passed "$PLAN"
  # create-pr publishes a whole stack at once, from its root.
  local parent plan plan_status reason target base=""
  parent=$(stacks_on "$PLAN") || block "Plan has a 'Stacks On:' line that is misplaced, repeated, or malformed. $STACKS_ON_HELP"
  [[ -z "$parent" ]] ||
    block "Plan stacks on $parent. create-pr runs once, on the stack's root $(root_plans "$PLAN" | awk 'NR==1'), and publishes every plan in the stack together (skills/dev/plan.md#stacks)."
  target=$(field "$PLAN" Base)
  if target=$(tree_sha "refs/remotes/origin/$target" || tree_sha "refs/heads/$target"); then
    base=$(git -C "$GIT_TREE" merge-base "$target" "$(green_of "$PLAN")" 2>/dev/null || true)
  fi
  require_reviewed_proof "$PLAN" "$base"
  while IFS= read -r plan; do
    [[ "$plan" != '!'* ]] || block "${plan#!} has a 'Stacks On:' line that is misplaced, repeated, malformed, or names no plan, or is a symlink; fix it so create-pr can tell whether it stacks on this plan."
    parent=$(stacks_on "$plan")
    require_stacked "$plan" "$parent"
    plan_status=$(status_of "$plan")
    [[ "$plan_status" == reviewed ]] ||
      block "Plan $plan stacks above this plan and is '$plan_status'. The stack publishes together: run create-pr on this root once every plan in it is reviewed (skills/dev/plan.md#stacks)."
    require_current_review "$plan"
    reason=$(stop_reason "$plan") || block "Cannot hash $plan with the plans below it: one is missing or has an unreadable 'Stacks On:' line."
    [[ -z "$reason" ]] || block "Plan $plan stacks above this plan and is stopped: $reason. Only the user clears it, with dev-stack.sh resume (skills/dev/run-stack.md#stops)."
    require_worktree "$plan"
    require_passed "$plan"
    # Reviewed on top of the parent's current reviewed tip, not an older one.
    contains_parent_green "$plan" "$parent" ||
      block "Plan $plan's reviewed SHA $(green_of "$plan") does not contain its parent $parent's, $(green_of "$parent"). Merge the parent forward into $plan (skills/dev/plan.md#worktree), return it to review-code, then run create-pr here."
    require_reviewed_proof "$plan" "$(green_of "$parent")"
  done < <(descendant_plans "$PLAN")
}

resolve_plan
plans_ignored || block "Git does not ignore docs/plans in $REPO_ROOT, so a plan could be committed. Add /docs/plans/ to the global excludes file (git config core.excludesFile) or to .git/info/exclude (skills/dev/plan.md#artifact)."
index_stack "$PLAN"
load_plan
require_one_root
case "$SKILL_SLUG" in
  review-feature) review_feature_gate ;;
  execute-feature) execute_feature_gate ;;
  review-code) review_code_gate ;;
  create-pr) create_pr_gate ;;
esac
exit 0
