#!/bin/bash
# Gate checker for the plan-backed phases (../skills/dev/plan.md#sequence).
# Reads hook JSON from stdin and prints block JSON when a phase's entry
# condition fails. Two events reach it: PreToolUse for a model-invoked Skill
# call (arguments in tool_input.args; the Pi extension sends
# tool_input.arguments), and UserPromptSubmit for a user-typed /dev-<skill>.
#
# Only review-feature, execute-feature, review-code, and create-pr are gated.
# Each checks its entry status; review-feature and review-code also check the
# plan's ID shape (id_report), every gate but review-feature a current READY
# plan review (create-pr for each plan it publishes), and review-code the
# RED/GREEN commit sequence.
# The hook reads identifiers and fields, never prose: whether an AC is right
# or a step satisfies its TC is the reviewer's judgment. It cannot tell who
# set `Status: approved`; only the user does.
#
# Plans resolve by exact path only. A dormant plan never captures unrelated
# work, and a gate fires only for its own plan, except that create-pr reads
# every plan's Stacks On line in its directory so a stack publishes together.
# Plans live outside the repository (dev-plan-lib.sh); Git checks run in the
# main root, and proof checks in the plan's worktree.

set -euo pipefail
# Byte-wise text handling: plan IDs and paths are ASCII, and a multibyte
# locale has crashed awk on invalid bytes, which the hook would read as a pass.
export LC_ALL=C

HOOK_INPUT=$(cat)

# UserPromptSubmit runs on every prompt, so a missing prerequisite blocks only
# input that could invoke a dev skill.
if ! command -v jq >/dev/null 2>&1; then
  if [[ "$HOOK_INPUT" == *'"UserPromptSubmit"'* ]]; then
    [[ "$HOOK_INPUT" =~ \"prompt\"[[:space:]]*:[[:space:]]*\"[[:space:]]*/[Dd][Ee][Vv][-:] ]] || exit 0
  else
    [[ "$HOOK_INPUT" == *[Dd][Ee][Vv][-:]* ]] || exit 0
  fi
  printf '{"continue":false,"stopReason":"gate-check.sh requires jq to parse hook input.","decision":"block","reason":"gate-check.sh requires jq to parse hook input."}\n'
  exit 0
fi

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

block() {
  jq -cn --arg reason "$1" '{continue:false, stopReason:$reason, decision:"block", reason:$reason}'
  exit 0
}

# A gated phase fails closed: a crash or unexpected error prints no verdict,
# which the hook would take as a pass.
trap 'rc=$?; (( rc == 0 )) || block "gate-check.sh failed (exit $rc) before reaching a verdict; this blocks rather than passing. Check the plan for invalid bytes or report the failure."' EXIT

# Exact-path checks canonicalise with realpath -m; probe the flag, since
# macOS ships a realpath without it.
realpath -m -- / >/dev/null 2>&1 || block "gate-check.sh requires realpath with -m support (GNU coreutils) to validate plan paths."

GATE_DIR=$(dirname -- "$(realpath -- "${BASH_SOURCE[0]}")")
REPO_ROOT=$(bash "$GATE_DIR/dev-utils.sh" main-root 2>/dev/null) || block "Cannot resolve the main working-tree root; do not substitute the current linked worktree."
cd "$REPO_ROOT" || block "Cannot access the main working-tree root: $REPO_ROOT"
# Git history checks run here, repointed to the plan's worktree when recorded.
GIT_TREE="$REPO_ROOT"

HOOK_TEXT=$(
  jq -r '[.tool_input.args?, .tool_input.arguments?, .tool_input.command?, .arguments?, .command?, .prompt?]
    | map(select(type == "string")) | join(" ")' <<<"$HOOK_INPUT" 2>/dev/null || true
)

. "$GATE_DIR/dev-plan-lib.sh"

is_registered_worktree() {
  [[ "$1" != "$REPO_ROOT" ]] || return 1
  grep -qxF "worktree $1" <<<"$(git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null)"
}

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
  STATUS=$(field "$PLAN" Status)
  # Before anything else: a published record ends delivery.
  [[ "$STATUS" != published ]] ||
    block "Plan $PLAN is published; no phase resumes it. For follow-up work, start a new stack in a new directory with design-feature."
  WT=$(field "$PLAN" Worktree)
  ACTIVE_WORKTREE=""
  if [[ -n "$WT" ]]; then
    if ! is_registered_worktree "$WT" || [[ ! -d "$WT" ]]; then
      block "Plan records 'Worktree: $WT', which is missing or not a registered worktree. If publication cleanup removed it, rerun dev-publish.sh cleanup $PLAN; otherwise stop and report it; the worktree stays until publication completes (skills/dev/plan.md#worktree)."
    fi
    GIT_TREE="$WT"
    ACTIVE_WORKTREE="$WT"
  fi
}

require_worktree() {
  [[ -n "$ACTIVE_WORKTREE" ]] || block "Plan records no Worktree. Record the path dev-worktree.sh create printed during execution; if none was printed, stop and report it (skills/dev/plan.md#worktree)."
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
  [[ "$type" =~ ^(feature|fix|refactor)$ ]] || block "Plan header has 'Type: $type'; write feature, fix, or refactor (skills/dev/plan.md#schema)."
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
  status=$(field "$PARENT_PLAN" Status)
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

    # A run stop reason is free text, not a citation.
    /^Run stop:/ { next }

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
  block "$(printf 'The ID graph in %s is not closed (skills/dev/plan.md#schema):\n%s\n\nClosure is shape, not correctness: fixing these does not make an edge right.' "$PLAN" "$report")"
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

# The plan needs a proof commit followed by at least one implementation
# commit, and nothing may precede the first proof. Topological order, so a
# repair merged forward reads as one line of history whatever its dates. A
# merge commit implements nothing, so it never completes the proof.
proof_sequence_ok() {
  # ENVIRON, not -v, so awk applies no escape processing to the regex.
  git -C "$GIT_TREE" log --format='%s' --topo-order --no-merges --reverse "$1..HEAD" 2>/dev/null |
    PROOF_RE="$2" awk '
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
    planning) ;;
    approved) block "Plan is already approved. Run execute-feature next." ;;
    implemented|reviewed) block "Plan status is '$STATUS' — too late for review-feature. Continue forward." ;;
    *) block "Plan status is '$STATUS' — expected 'planning'. Run design-feature first." ;;
  esac
  check_name
  require_parent_rank 1 approved
  require_ids
  require_branch
  [[ -z "$PARENT_PLAN" ]] || require_stacked "$PLAN" "$PARENT_PLAN"
}

# The spec, with the specs below it, is the one review-feature passed: a
# change after review voids the user's approval of it.
require_current_review() {
  local plan="${1:-$PLAN}" state
  state=$(review_state "$plan") || block "Cannot hash $plan with the plans below it: one is missing or has an unreadable 'Stacks On:' line."
  [[ "$state" == READY ]] ||
    block "Plan $plan has no 'Plan review: READY' record for its current spec and the specs below it: it changed after review-feature, or no verdict was recorded. Return it to planning, run review-feature, record the verdict with dev-stack.sh review, and have the user approve it again (skills/dev/plan.md#review)."
}

execute_feature_gate() {
  case "$STATUS" in
    approved) ;;
    planning) block "Plan status is 'planning' — not approved. Run review-feature; only the user sets 'Status: approved'." ;;
    implemented) block "Plan is already implemented. Run review-code next." ;;
    reviewed) block "Plan is already reviewed. Run create-pr next." ;;
    *) block "Plan status is '$STATUS' — expected 'approved'." ;;
  esac
  require_parent_rank 3 reviewed
  require_branch
  [[ -z "$PARENT_PLAN" ]] || require_stacked "$PLAN" "$PARENT_PLAN"
  require_current_review
}

review_code_gate() {
  local target branch head proof_re what count
  case "$STATUS" in
    implemented) ;;
    planning|approved) block "Plan status is '$STATUS' — not yet implemented. Run execute-feature first." ;;
    reviewed) block "Plan is already reviewed. Run create-pr next." ;;
    *) block "Plan status is '$STATUS' — expected 'implemented'." ;;
  esac
  require_worktree
  # A parent revised since execution returns this plan to its repair.
  require_parent_rank 3 reviewed
  require_branch
  [[ -z "$PARENT_PLAN" ]] || require_stacked "$PLAN" "$PARENT_PLAN"
  require_current_review
  # Re-checked after execution, which edits the plan.
  require_ids
  # A parent and its only child share a worktree, so HEAD must be this plan's.
  branch=$(field "$PLAN" Branch)
  head=$(git -C "$GIT_TREE" symbolic-ref --quiet --short HEAD 2>/dev/null || true)
  [[ "$head" == "$branch" ]] || block "Worktree $GIT_TREE is on '${head:-a detached HEAD}', not this plan's branch '$branch'; switch it to '$branch' before code review (skills/dev/plan.md#worktree)."
  target=$(pr_target "$PLAN")
  resolve_review_base "$target" || block "The PR target '$target' is missing or is not an ancestor of '$branch'. If a repair landed on the parent plan's branch, merge it forward first (skills/dev/plan.md#worktree)."
  # Refactors prove the preserved behavior with a passing baseline commit.
  if [[ "$(field "$PLAN" Type | tr '[:upper:]' '[:lower:]')" == refactor ]]; then
    proof_re='^test:[[:space:]]*baseline' what="'test: baseline'"
  else
    proof_re='^test\(red\):' what="'test(red):'"
  fi
  count=$(git -C "$GIT_TREE" log --format=%s "$REVIEW_BASE..HEAD" 2>/dev/null | grep -Ec "$proof_re" || true)
  (( count >= 1 )) || block "Found no $what commit between $target and $branch (skills/dev/plan.md#verification)."
  proof_sequence_ok "$REVIEW_BASE" "$proof_re" || block "Proof is out of sequence: each $what commit needs at least one implementation commit after it, and nothing may come before the first (skills/dev/plan.md#verification)."
}

create_pr_gate() {
  case "$STATUS" in
    reviewed) ;;
    implemented) block "Plan status is 'implemented' — run review-code first." ;;
    planning|approved) block "Plan status is '$STATUS' — not yet executed. Continue the workflow." ;;
    *) block "Plan status is '$STATUS' — expected 'reviewed'." ;;
  esac
  require_worktree
  require_current_review
  # create-pr publishes a whole stack at once, from its root.
  local parent plan plan_status parent_green plan_green wt
  parent=$(stacks_on "$PLAN") || block "Plan has a 'Stacks On:' line that is misplaced, repeated, or malformed. $STACKS_ON_HELP"
  [[ -z "$parent" ]] ||
    block "Plan stacks on $parent. create-pr runs once, on the stack's root $(root_plans "$PLAN" | awk 'NR==1'), and publishes every plan in the stack together (skills/dev/plan.md#stacks)."
  while IFS= read -r plan; do
    [[ "$plan" != '!'* ]] || block "${plan#!} has a 'Stacks On:' line that is misplaced, repeated, malformed, or names no plan, or is a symlink; fix it so create-pr can tell whether it stacks on this plan."
    parent=$(stacks_on "$plan")
    require_stacked "$plan" "$parent"
    plan_status=$(field "$plan" Status)
    [[ "$plan_status" == reviewed ]] ||
      block "Plan $plan stacks above this plan and is '$plan_status'. The stack publishes together: run create-pr on this root once every plan in it is reviewed (skills/dev/plan.md#stacks)."
    require_current_review "$plan"
    wt=$(field "$plan" Worktree)
    [[ -n "$wt" && -d "$wt" ]] && is_registered_worktree "$wt" ||
      block "Plan $plan records 'Worktree: $wt', which is missing or not a registered worktree. If publication cleanup removed it, rerun dev-publish.sh cleanup on the plans not yet published, children before parents; otherwise stop and report it; each worktree stays until publication completes (skills/dev/plan.md#worktree)."
    # Only a parent's only child shares its worktree.
    [[ "$wt" != "$(field "$parent" Worktree)" || "$(child_plans "$parent")" != *$'\n'* ]] ||
      block "Plan $plan shares $parent's worktree, but $parent has other children; each of them needs its own worktree (skills/dev/plan.md#worktree)."
    # Reviewed on top of the parent's current reviewed tip, not an older one.
    contains_parent_green "$plan" "$parent" || {
      plan_green=$(green_of "$plan"); parent_green=$(green_of "$parent")
      block "Plan $plan's Green ${plan_green:-(none)} does not contain its parent $parent's Green ${parent_green:-(none)}. Merge the parent forward into $plan (skills/dev/plan.md#worktree), return it to review-code, then run create-pr here."
    }
  done < <(descendant_plans "$PLAN")
}

resolve_plan
load_plan
require_one_root
case "$SKILL_SLUG" in
  review-feature) review_feature_gate ;;
  execute-feature) execute_feature_gate ;;
  review-code) review_code_gate ;;
  create-pr) create_pr_gate ;;
esac
exit 0
