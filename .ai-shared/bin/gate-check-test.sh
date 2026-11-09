#!/bin/bash
# gate-check.sh against scratch repositories: block and pass cases for each gate.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
GATE="$ROOT/bin/gate-check.sh"
TMP_ROOT=$(mktemp -d /tmp/gate-check-test.XXXXXX)
export AI_WORKTREES_ROOT="$TMP_ROOT/worktrees"
# Plans are ignored by each repository's own exclude, never the user's global one.
export GIT_CONFIG_GLOBAL=/dev/null XDG_CONFIG_HOME="$TMP_ROOT/xdg"

new_repo() {
  local repo
  repo=$(mktemp -d "$TMP_ROOT/repo.XXXXXX")
  git -C "$repo" init -q -b main
  git -C "$repo" config user.email gate-check@example.test
  git -C "$repo" config user.name gate-check-test.sh
  printf 'seed\n' > "$repo/README.md"
  git -C "$repo" add README.md
  git -C "$repo" commit -qm seed
  printf '/docs/plans/\n' >> "$repo/.git/info/exclude"
  printf '%s\n' "$repo"
}

# A fresh repository in $repo, its plans directory in $PD, and plan paths:
# $P alone in its stack, and $BE with $FE stacked on it.
use_repo() {
  repo=$(new_repo)
  PD="$repo/docs/plans"
  P="$PD/12_gate/pr1.spec.md"
  BE="$PD/12_orders/pr1.spec.md"
  FE="$PD/12_orders/pr2.spec.md"
}

# Parser fixture, not an authoring exemplar: the gate reads only IDs and
# fields, so the prose is filler that keeps the graph closed.
valid_graph() {
  cat <<'GRAPH'
## Acceptance Criteria
AC-1 — the gate blocks an unapproved plan
  Source: user requirement
  Success: execution is refused
  Failure: execution proceeds

## Test Cases
TC-1 — unapproved plan reaches execute-feature
  Proves: AC-1
  Fixture: a plan at Status: planning
  Action: execute-feature is invoked
  Expected: the hook blocks

## Implementation Steps
ST-1 — add the status gate — satisfies TC-1
GRAPH
}

# A current Spec hash for plan file $1, as dev-stack.sh review writes it.
ready() {
  local hash
  hash=$(REPO_ROOT=/unused bash -c '. "$1"; plan_hash "$2"' _ "$ROOT/bin/dev-plan-lib.sh" "$1") || hash=none
  sed -i "0,/^Spec:/ s/^Spec: .*/Spec: $hash/" "$1"
}

# log_pass <plan> <sha>: the stack log line dev-stack.sh code-review writes
# for a passing review-code verdict at <sha>.
log_pass() { printf 'pr%s: code-review pass (1/3) at %s\n' "$(basename "$1" .spec.md | tr -d pr)" "$2" >> "$(dirname "$1")/log"; }

# write_plan <file> <status> [graph] [type] [issue] [extra header line] [branch]
# A bare `reviewed` gets the repository's HEAD as its Tip; `reviewed <sha>`
# gets <sha>. A reviewed plan gets a logged review-code pass at its Tip.
write_plan() {
  local file="$1" status="$2" graph="${3-$(valid_graph)}" type="${4-feature}" issue="${5-#12}" extra="${6-}" branch="${7-feat/gate}" tip=-
  [[ "$status" != reviewed ]] || status="reviewed $(git -C "$repo" rev-parse HEAD)"
  [[ "$status" != 'reviewed '* ]] || { tip=${status#reviewed }; status=reviewed; }
  mkdir -p "$(dirname "$file")"
  {
    printf '# Gate test\n'
    printf 'Status: %s\nSpec: -\nTip: %s\nType: %s\nBase: main\nBranch: %s\nIssue: %s\n' "$status" "$tip" "$type" "$branch" "$issue"
    if [[ -n "$extra" ]]; then printf '%s\n' "$extra"; fi
    printf '\n## Goal\nGate the phases.\n\n%s\n' "$graph"
  } > "$file"
  [[ "$tip" == - ]] || log_pass "$file" "$tip"
}

# The path the gate looks for plan $1's own worktree at.
wt_of() { printf '%s/%s-%s-pr%s\n' "$AI_WORKTREES_ROOT" "$(basename "$repo")" "$(basename "$(dirname "$1")")" "$(basename "$1" .spec.md | tr -d pr)"; }

# Plan $P with its worktree on feat/gate; a reviewed plan carries its proof
# commits and the tip.
plan_with_worktree() {
  local status="$1" wt
  wt=$(wt_of "$P")
  git -C "$repo" worktree add -q -b feat/gate "$wt" main
  if [[ "$status" == reviewed ]]; then
    wt_commit "$wt" 'test(red): gate' tests/gate_test.py
    wt_commit "$wt" 'feat(gate): implement' src/gate.py
    status="reviewed $(git -C "$repo" rev-parse feat/gate)"
  fi
  write_plan "$P" "$status" "${2-$(valid_graph)}" "${3-feature}"
}

# The Tip SHA of plan $1 when it is reviewed.
green_in() { grep -qx 'Status: reviewed' "$1" && sed -n '0,/^Tip:/ s/^Tip: \([0-9a-f]*\)$/\1/p' "$1"; }
# set_reviewed <plan> [sha]: Status reviewed with Tip <sha>, or none.
set_reviewed() { sed -i "s/^Status: .*/Status: reviewed/; s/^Tip: .*/Tip: ${2:--}/" "$1"; [[ -z "${2-}" ]] || log_pass "$1" "$2"; }

# A proof on top of commit $1: a test(red) commit, then an implementation.
proof_on() {
  local tree red
  tree=$(git -C "$repo" rev-parse "$1^{tree}")
  red=$(git -C "$repo" commit-tree "$tree" -p "$1" -m 'test(red): proof')
  git -C "$repo" commit-tree "$tree" -p "$red" -m 'feat: proof'
}

wt_commit() {
  local wt="$1" subject="$2" f; shift 2
  for f in "$@"; do mkdir -p "$wt/$(dirname "$f")"; printf 'x\n' >> "$wt/$f"; done
  git -C "$wt" add -A
  git -C "$wt" commit -qm "$subject"
}

# The gate for skill $2 on args $3 in repo $1. Fixtures edit specs freely, so
# each plan past planning first gets a current ready Spec, unless
# STALE_OK=1 keeps its records as they are.
run_gate() {
  local main f
  if [[ "${STALE_OK-}" != 1 ]] && main=$(git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
    main=${main%/.git}
    for f in "$main/docs/plans"/*/pr*.spec.md; do
      [[ -f "$f" && ! -L "$f" && "$(grep -m1 '^Status:' "$f")" != 'Status: planning'* ]] && ready "$f" || true
    done
  fi
  jq -cn --arg skill "$2" --arg args "$3" '{tool_input:{skill:$skill,args:$args}}' | (cd "$1" && "$GATE")
}
prompt_gate() {
  jq -cn --arg prompt "$2" '{hook_event_name:"UserPromptSubmit",prompt:$prompt}' | (cd "$1" && "$GATE")
}

assert_pass() {
  [[ -z "$1" ]] || { printf 'FAIL: %s\n%s\n' "$2" "$1" >&2; exit 1; }
  printf 'PASS: %s\n' "$2"
}
assert_block() {
  jq -e --arg e "$2" '.decision == "block" and (.reason | contains($e))' <<<"$1" >/dev/null 2>&1 ||
    { printf 'FAIL: %s\n%s\n' "$3" "$1" >&2; exit 1; }
  printf 'PASS: %s\n' "$3"
}

# A planning plan with graph $2 at review-feature: assert $3 is in the block,
# or a pass when $3 is empty.
review_graph() {
  local label="$1" graph="$2" expected="$3"
  use_repo
  write_plan "$P" planning "$graph"
  if [[ -n "$expected" ]]; then assert_block "$(run_gate "$repo" dev-review-feature "$P")" "$expected" "$label"
  else assert_pass "$(run_gate "$repo" dev-review-feature "$P")" "$label"; fi
}

# A closed graph of $1 ACs, one TC and one step each.
graph_n() {
  awk -v n="$1" 'BEGIN {
    print "## Acceptance Criteria"; for (i = 1; i <= n; i++) printf "AC-%d — outcome %d\n", i, i
    print "## Test Cases"; for (i = 1; i <= n; i++) printf "TC-%d — scenario %d\n  Proves: AC-%d\n", i, i, i
    print "## Implementation Steps"; for (i = 1; i <= n; i++) printf "ST-%d — do %d — satisfies TC-%d\n", i, i, i
  }'
}

# ── plan resolution ──
use_repo
write_plan "$P" approved
assert_block "$(run_gate "$repo" dev-execute-feature '')" 'none was named' 'a lone plan is not adopted without a path'
assert_block "$(run_gate "$repo" dev-execute-feature 'gate')" 'none was named' 'a slug does not resolve'
assert_pass "$(run_gate "$repo" dev-execute-feature "$P")" 'an exact path resolves'
: > "$repo/.git/info/exclude"
assert_block "$(run_gate "$repo" dev-execute-feature "$P")" 'does not ignore docs/plans' 'a plan Git does not ignore blocks'
printf '/docs/plans/\n' > "$repo/.git/info/exclude"
assert_pass "$(run_gate "$repo" dev-execute-feature "@$P, please")" 'surrounding punctuation is not part of the path'
assert_pass "$(HOME="$TMP_ROOT" run_gate "$repo" dev-execute-feature "~/$(basename "$repo")/docs/plans/12_gate/pr1.spec.md")" 'a path starting with ~ resolves'
assert_block "$(run_gate "$repo" dev-execute-feature "12_gate/pr1.spec.md")" 'not found' 'a relative path does not resolve'
assert_block "$(run_gate "$repo" dev-execute-feature "/other/repo/12_gate/pr1.spec.md")" 'not found' "a path outside the repository's docs/plans does not resolve"
write_plan "$TMP_ROOT/other/docs/plans/12_gate/pr1.spec.md" approved
assert_block "$(run_gate "$repo" dev-execute-feature "$TMP_ROOT/other/docs/plans/12_gate/pr1.spec.md")" 'not found' "another repository's plan does not resolve"
assert_block "$(run_gate "$repo" dev-execute-feature "$PD/../../../other/docs/plans/12_gate/pr1.spec.md")" 'not found' 'traversal out of the repository plans does not resolve'
write_plan "$PD/12_gate/nested/pr1.spec.md" approved
assert_block "$(run_gate "$repo" dev-execute-feature "$PD/12_gate/nested/pr1.spec.md")" 'not found' 'a nested path does not resolve'
assert_block "$(run_gate "$repo" dev-execute-feature "$PD/12_gate/pr9.spec.md")" "not found: $PD/12_gate/pr9.spec.md" 'a mistyped path blocks'
write_plan "$PD/12_gate/pr2.spec.md" approved "$(valid_graph)" feature '#12' 'Stacks On: pr1' feat/gate-2
assert_block "$(run_gate "$repo" dev-execute-feature "$P $PD/12_gate/pr2.spec.md")" 'takes one plan path' 'two plans block'
write_plan "$PD/12_gate/gate.md" approved
assert_block "$(run_gate "$repo" dev-execute-feature "$PD/12_gate/gate.md")" 'none was named' 'a .md plan without .spec is not a plan path'
write_plan "$PD/gate/pr1.spec.md" approved
assert_block "$(run_gate "$repo" dev-execute-feature "$PD/gate/pr1.spec.md")" 'Pass the full path of an existing' 'a directory outside <issue>_<slug> blocks'
ln -s pr1.spec.md "$PD/12_gate/pr5.spec.md"
assert_block "$(run_gate "$repo" dev-execute-feature "$PD/12_gate/pr5.spec.md")" 'is a symlink' 'a symlinked plan blocks'

use_repo
write_plan "$P" published
assert_block "$(run_gate "$repo" dev-execute-feature "$P")" 'is published; no phase resumes it' 'a published plan is a record'
write_plan "$PD/12_shipped/pr1.spec.md" published
write_plan "$P" approved
assert_pass "$(run_gate "$repo" dev-execute-feature "$P")" 'a published plan in another directory is inert'

# ── hook input shapes ──
use_repo
write_plan "$P" approved
out=$(jq -cn --arg a "$P" '{hook_event_name:"PreToolUse",tool_name:"Skill",tool_input:{skill:"dev-review-feature",arguments:$a}}' | (cd "$repo" && "$GATE"))
assert_block "$out" 'already approved' 'the Pi arguments shape resolves the plan'
assert_block "$(prompt_gate "$repo" "/dev-review-feature $P")" 'already approved' 'a typed /dev-review-feature is gated'
assert_block "$(prompt_gate "$repo" "/dev-review-feature, $P")" 'already approved' 'punctuation after a typed skill still gates it'
assert_block "$(prompt_gate "$repo" "/Dev-review-feature $P")" 'already approved' 'a typed skill is gated regardless of case'
assert_block "$(prompt_gate "$repo" '/dev-execute-feature')" 'none was named' 'a typed phase without a path blocks'
assert_pass "$(prompt_gate "$repo" "please review-feature $P later")" 'prose that mentions a skill is not gated'
assert_pass "$(prompt_gate "$repo" 'explain /dev-review-feature to me')" 'a slash command not at the start is not gated'
out=$(jq -cn '{hook_event_name:"PreToolUse",tool_name:"run_shell_command",tool_input:{command:"git commit -m \"dev-review-code notes\""}}' | (cd "$repo" && "$GATE"))
assert_pass "$out" 'a shell command that mentions a dev skill is not an invocation'
out=$(jq -cn --arg c "/dev-review-feature $P" '{hook_event_name:"PreToolUse",tool_name:"SlashCommand",tool_input:{command:$c}}' | (cd "$repo" && "$GATE"))
assert_block "$out" 'already approved' 'a slash command in a command field is gated'
nogit=$(mktemp -d "$TMP_ROOT/nogit.XXXXXX")
assert_pass "$(prompt_gate "$nogit" '/dev-explore where is auth handled')" 'an ungated skill runs outside a Git repository'
assert_pass "$(run_gate "$repo" dev-fix-bug "crash mentioned in $P")" 'fix-bug is ungated even when it mentions a plan'

shim=$(mktemp -d "$TMP_ROOT/shim.XXXXXX")
printf '#!/bin/bash\n[[ "$1" == -m ]] && exit 1\nexec %q "$@"\n' "$(command -v realpath)" > "$shim/realpath"
chmod +x "$shim/realpath"
shim_prompt() { jq -cn --arg p "$2" '{hook_event_name:"UserPromptSubmit",prompt:$p}' | (cd "$repo" && PATH="$1" "$GATE"); }
assert_pass "$(shim_prompt "$shim:$PATH" 'fix the login bug')" 'a realpath without -m does not block a plain prompt'
assert_pass "$(shim_prompt "$shim:$PATH" '/dev-explore auth flow')" 'a realpath without -m does not block an ungated skill'
assert_block "$(shim_prompt "$shim:$PATH" "/dev-review-feature $P")" 'realpath with -m support' 'a gated skill reports the missing realpath -m'
nojq=$(mktemp -d "$TMP_ROOT/nojq.XXXXXX")
ln -s "$(command -v cat)" "$nojq/cat"
assert_pass "$(shim_prompt "$nojq" 'fix the login bug')" 'missing jq does not block a plain prompt'
assert_pass "$(shim_prompt "$nojq" 'restart the dev-server')" 'missing jq does not block a prompt that mentions dev-'
out=$(jq -cn --arg p "/dev-review-feature $P" '{hook_event_name:"UserPromptSubmit",prompt:$p}' | (cd "$repo" && PATH="$nojq" "$GATE"))
assert_block "$out" 'requires jq' 'missing jq still blocks a dev skill'

# ── worktree and root ──
use_repo
write_plan "$P" implemented
mkdir -p "$(wt_of "$P")"
assert_block "$(run_gate "$repo" dev-review-code "$P")" "Plan $P has no worktree at $(wt_of "$P")" 'an unregistered directory at the worktree path is no worktree'
write_plan "$P" "reviewed $(git -C "$repo" rev-parse HEAD)"
assert_block "$(run_gate "$repo" dev-create-pr "$P")" 'rerun dev-publish.sh cleanup' 'a missing worktree points to cleanup'

use_repo
plan_with_worktree reviewed
wt=$(wt_of "$P")
assert_pass "$(run_gate "$repo" dev-create-pr "$P")" 'a reviewed plan with a worktree enters create-pr'
assert_pass "$(run_gate "$wt" dev-create-pr "$P")" "from a worktree, the main repository's plans resolve"
out=$(
  git() { if [[ "${1:-}" == worktree && "${2:-}" == list ]]; then return 1; fi; command git "$@"; }
  export -f git
  run_gate "$wt" dev-execute-feature "$P"
)
assert_block "$out" 'main working-tree root' 'failed root discovery does not fall back to a linked worktree'

# ── review-feature ──
use_repo
write_plan "$P" planning
assert_pass "$(run_gate "$repo" dev-review-feature "$P")" 'a closed planning plan enters review-feature'
write_plan "$P" approved
assert_block "$(run_gate "$repo" dev-review-feature "$P")" 'already approved' 'an approved plan does not re-enter review'
write_plan "$P" implemented
assert_block "$(run_gate "$repo" dev-review-feature "$P")" 'too late for review-feature' 'an implemented plan does not re-enter review'
write_plan "$PD/0_gate/pr1.spec.md" planning "$(valid_graph)" feature none
assert_pass "$(run_gate "$repo" dev-review-feature "$PD/0_gate/pr1.spec.md")" 'Issue: none with issue 0 enters review'
write_plan "$P" planning "$(valid_graph)" feature none
assert_block "$(run_gate "$repo" dev-review-feature "$P")" "starts with 12, but the header has 'Issue: none'" 'Issue: none needs issue 0 in the directory'
write_plan "$P" planning "$(valid_graph)" feature '#13'
assert_block "$(run_gate "$repo" dev-review-feature "$P")" "starts with 12, but the header has 'Issue: #13'" 'the directory issue matches the header'
write_plan "$P" planning "$(valid_graph)" feature '#12abc'
assert_block "$(run_gate "$repo" dev-review-feature "$P")" "write 'Issue: #<n>' or 'Issue: none'" 'a malformed issue blocks'
write_plan "$P" planning "$(valid_graph)" fix
assert_pass "$(run_gate "$repo" dev-review-feature "$P")" 'the type lives in the header only'
write_plan "$P" planning "$(valid_graph)" chore
assert_block "$(run_gate "$repo" dev-review-feature "$P")" "write feature, fix, refactor, or config" 'an unknown type blocks'
write_plan "$P" planning
sed -i 's/^Base: main$/Base:/' "$P"
assert_block "$(run_gate "$repo" dev-review-feature "$P")" 'no Base branch' 'review requires a Base'
write_plan "$P" planning "$(valid_graph)" feature '#12' '' ''
assert_block "$(run_gate "$repo" dev-review-feature "$P")" "has 'Branch: '" 'review requires a Branch'
write_plan "$P" planning "$(valid_graph)" feature '#12' '' 'bad..branch'
assert_block "$(run_gate "$repo" dev-review-feature "$P")" "has 'Branch: bad..branch'" 'review requires a valid Branch'
write_plan "$P" planning "$(valid_graph)" feature '#12' '' main
assert_block "$(run_gate "$repo" dev-review-feature "$P")" "Branch is its Base, 'main'" "a plan's Branch is not its Base"

# ── ID shape ──
review_graph 'eight ACs enter review without a cap' "$(graph_n 8)" ''
review_graph 'a bulleted plan resolves the same graph' '## Acceptance Criteria
- AC-1 — outcome
## Test Cases
- TC-1 — scenario
  - Proves: AC-1
## Implementation Steps
- ST-1 — action — satisfies TC-1' ''
review_graph 'a template-verbatim plan enters review' '## Design Decisions
DD-1 — reject at the API so every client gets AC-1
  Options: API or UI | Choice: API, by the user | Why: one enforcement point
## Acceptance Criteria
AC-1 — an archived user cannot check out
  Source: issue #12
  Success: checkout returns 403
  Failure: an order is created
## Test Cases
TC-1 — archived user checks out
  Proves: AC-1
  Fixture: user u1, archived, cart with one item
  Action: POST /checkout as u1
  Expected: 403 and no order row
## Implementation Steps
ST-1 — guard checkout in api/checkout.py — satisfies TC-1
  PC-1 — checkout reads the user before writing — Check: rg -n "get_user" api/checkout.py' ''
review_graph 'an unindented Proves: still belongs to its TC' '## Acceptance Criteria
AC-1 — outcome
## Test Cases
TC-1 — scenario
Proves: AC-1
## Implementation Steps
ST-1 — action — satisfies TC-1' ''
review_graph 'an em-dash title naming another ID is not a range' '## Acceptance Criteria
AC-1 — outcome
## Test Cases
TC-1 — scenario
  Proves: AC-1
TC-2 — TC-1 variant with an empty cart
  Proves: AC-1
## Implementation Steps
ST-1 — action — satisfies TC-1, TC-2' ''
review_graph 'a numeric em-dash summary is not a range' '## Acceptance Criteria
AC-1 — the endpoint returns 200
## Test Cases
TC-1 — 200 returned for a valid request
  Proves: AC-1
## Implementation Steps
ST-1 — add the handler — satisfies TC-1' ''
review_graph 'word-embedded tokens are not IDs' '## Acceptance Criteria
AC-1 — the response carries UTC-7 offsets and an SHA-256 digest
## Test Cases
TC-1 — scenario
  Proves: AC-1
## Implementation Steps
ST-1 — action — satisfies TC-1' ''
review_graph 'fenced text is not parsed' '## Acceptance Criteria
AC-1 — outcome
## Test Cases
TC-1 — scenario
  Proves: AC-1
~~~text
TC-9 sample output, docs/plans/be.md#AC-2
~~~
## Implementation Steps
ST-1 — action — satisfies TC-1' ''
review_graph 'an AC no TC proves blocks' '## Acceptance Criteria
AC-1 — outcome
AC-2 — second outcome
## Test Cases
TC-1 — scenario
  Proves: AC-1
## Implementation Steps
ST-1 — action — satisfies TC-1' 'AC-2 has no TC'
review_graph 'a TC no step names blocks' '## Acceptance Criteria
AC-1 — outcome
## Test Cases
TC-1 — scenario
  Proves: AC-1
TC-2 — second
  Proves: AC-1
## Implementation Steps
ST-1 — action — satisfies TC-1' 'TC-2 is not satisfied by any Implementation Step'
review_graph 'a step naming no TC blocks' '## Acceptance Criteria
AC-1 — outcome
## Test Cases
TC-1 — scenario
  Proves: AC-1
## Implementation Steps
ST-1 — action — satisfies TC-1
ST-2 — unrelated cleanup' 'ST-2 has no satisfies clause naming a TC'
review_graph 'a TC with no Proves: blocks' '## Acceptance Criteria
AC-1 — outcome
## Test Cases
TC-1 — scenario
  Proves: AC-1
TC-2 — scenario with no Proves line
  Fixture: setup
## Implementation Steps
ST-1 — action — satisfies TC-1 and TC-2' 'TC-2 has no Proves: line'
review_graph 'an undeclared TC blocks' '## Acceptance Criteria
AC-1 — outcome
## Test Cases
TC-1 — scenario
  Proves: AC-1
## Implementation Steps
ST-1 — action — satisfies TC-1/TC-9' 'cites TC-9, which is not declared'
review_graph 'an undeclared decision blocks' '## Acceptance Criteria
AC-1 — outcome per DD-2
## Test Cases
TC-1 — scenario
  Proves: AC-1
## Implementation Steps
ST-1 — action — satisfies TC-1' 'cites DD-2, which is not declared: no line in ## Design Decisions'
review_graph 'a checkbox TC is not a declaration' '## Acceptance Criteria
AC-1 — outcome
## Test Cases
TC-1 — scenario
  Proves: AC-1
- [ ] TC-2 — scenario
  Proves: AC-1
## Implementation Steps
ST-1 — action — satisfies TC-1, TC-2' 'cites TC-2, which is not declared'
for case in 'TC-1 through TC-4' 'TC-1 to TC-4' 'TC-1–9' 'TC-1..TC-3'; do
  review_graph "'$case' is an unreadable range" "## Acceptance Criteria
AC-1 — outcome
## Test Cases
TC-1 — scenario
  Proves: AC-1
## Implementation Steps
ST-1 — action — satisfies $case" 'uses an ID range'
done
review_graph 'a Proves: naming no AC is unreadable' '## Acceptance Criteria
AC-1 — outcome
## Test Cases
TC-1 — scenario
  Proves: the login AC
## Implementation Steps
ST-1 — action — satisfies TC-1' 'unparseable Proves:'
review_graph 'a TC proving two ACs is unreadable' '## Acceptance Criteria
AC-1 — outcome
AC-2 — outcome
## Test Cases
TC-1 — scenario
  Proves: AC-1, AC-2
## Implementation Steps
ST-1 — action — satisfies TC-1' 'exactly one is required'
review_graph 'two Proves: lines are unreadable' '## Acceptance Criteria
AC-1 — outcome
AC-2 — outcome
## Test Cases
TC-1 — scenario
  Proves: AC-1
  Proves: AC-2
## Implementation Steps
ST-1 — action — satisfies TC-1' 'more than one Proves:'
for id in AC TC ST; do
  review_graph "a duplicate $id is unreadable" "$(graph_n 2 | sed "s/$id-2/$id-1/")" 'declared more than once'
done
review_graph 'a leading zero is unreadable' "$(graph_n 1 | sed 's/AC-1/AC-01/g')" 'leading zero'
review_graph 'an ID of zero is unreadable' "$(graph_n 1 | sed 's/AC-1/AC-0/g')" 'IDs start at 1'
for cite in 'docs/plans/be.md#AC-2' 'docs/plans/be#AC-2' 'api/orders.yaml#DD-1'; do
  review_graph "'$cite' cites another artifact" "$(graph_n 1)
## Context
Relies on $cite" "cites another artifact's IDs"
done

review_graph 'a satisfies clause on a continuation line counts' '## Acceptance Criteria
AC-1 — outcome
## Test Cases
TC-1 — scenario
  Proves: AC-1
## Implementation Steps
ST-1 — do 1
  satisfies TC-1' ''
review_graph 'a step that only mentions a TC in prose satisfies nothing' "$(graph_n 1)
ST-2 — extend the TC-1 handler" 'ST-2 has no satisfies clause naming a TC'
review_graph 'PR rows are not IDs' "$(graph_n 1)
## Notes
PR-1 ships ST-1" ''

# ── failing closed ──
use_repo
write_plan "$P" planning
printf '\xff\xfe stray bytes\n' >> "$P"
assert_pass "$(run_gate "$repo" dev-review-feature "$P")" 'invalid bytes in a plan reach a verdict'
crash=$(mktemp -d "$TMP_ROOT/crash.XXXXXX")
printf '#!/bin/bash\nfor a; do [[ "$a" == *owner*AC* ]] && exit 134; done\nexec %q "$@"\n' "$(command -v awk)" > "$crash/awk"
chmod +x "$crash/awk"
out=$(jq -cn --arg a "$P" '{tool_input:{skill:"dev-review-feature",args:$a}}' | (cd "$repo" && PATH="$crash:$PATH" "$GATE") || true)
assert_block "$out" 'gate-check.sh failed (exit 134)' 'a crash in a gated phase blocks'

# ── Stacks On: a stacked plan waits for its parent ──
fe_repo() {
  use_repo
  write_plan "$BE" "$1"
  write_plan "$FE" "$2" "$(valid_graph)" feature '#12' 'Stacks On: pr1' feat/fe
}
fe_repo planning planning
assert_block "$(run_gate "$repo" dev-review-feature "$FE")" "Parent plan $BE is 'planning'; review-feature needs it 'approved' or later" 'review waits for the parent approval'
assert_block "$(run_gate "$repo" dev-review-feature "$FE $BE")" 'takes one plan path' 'naming the parent beside the plan blocks'
assert_pass "$(run_gate "$repo" dev-review-feature "$BE")" 'the root plan reviews on its own'
fe_repo approved planning
assert_pass "$(run_gate "$repo" dev-review-feature "$FE")" 'review enters once the parent is approved'
sed -i 's/^Branch: feat\/fe$/Branch: feat\/gate/' "$FE"
assert_block "$(run_gate "$repo" dev-review-feature "$FE")" "its PR targets its parent plan's branch, 'feat/gate'" 'a stacked plan has its own branch'
sed -i 's/^Branch: feat\/gate$/Branch: feat\/fe/; s/^Base: main$/Base: feat\/gate/' "$FE"
assert_block "$(run_gate "$repo" dev-review-feature "$FE")" "a stacked plan uses its parent's Base" 'a stacked plan must share the parent Base'
sed -i 's/^Base: feat\/gate$/Base: main/' "$FE"
sed -i '/^Status:/a Stacks On: pr2' "$BE"
assert_block "$(run_gate "$repo" dev-execute-feature "$BE")" "'Stacks On:' line that is misplaced, repeated, or malformed" 'a plan stacks only on a lower number, so no cycle forms'
sed -i '/^Stacks On:/d' "$BE"
write_plan "$PD/12_orders/pr3.spec.md" planning "$(valid_graph)" feature '#12' '' feat/other
assert_block "$(run_gate "$repo" dev-review-feature "$FE")" 'holds 2 plans without a' 'a directory holds one root'
rm "$PD/12_orders/pr3.spec.md"
fe_repo implemented approved
assert_block "$(run_gate "$repo" dev-execute-feature "$FE")" "is 'implemented'; execute-feature needs it 'reviewed' or later" 'execution waits for the parent review'
fe_repo reviewed approved
assert_pass "$(run_gate "$repo" dev-execute-feature "$FE")" 'execution enters once the parent is reviewed'
sed -i 's/^Branch: feat\/gate$/Branch: feat\/fe/' "$BE"
assert_block "$(run_gate "$repo" dev-execute-feature "$FE")" "its PR targets its parent plan's branch, 'feat/fe'" 'execution rechecks stacking after a parent revision'
fe_repo published approved
assert_block "$(run_gate "$repo" dev-execute-feature "$FE")" 'a published plan never becomes a parent' 'a published plan cannot be a parent'
fe_repo reviewed approved
write_plan "$PD/12_orders/pr5.spec.md" approved "$(valid_graph)" feature '#12' 'Stacks On: pr4' feat/five
assert_block "$(run_gate "$repo" dev-execute-feature "$PD/12_orders/pr5.spec.md")" "pr4.spec.md does not exist. Fix the 'Stacks On:' line" 'a Stacks On naming a missing plan blocks'
for value in '<pr<K> of the parent plan; stacked plans only>' '../elsewhere/pr1.spec.md' "$BE" 'pr1.spec.md' './pr1' 'pr01'; do
  sed -i "s#^Stacks On: .*#Stacks On: $value#" "$FE"
  assert_block "$(run_gate "$repo" dev-execute-feature "$FE")" "'Stacks On:' line that is misplaced, repeated, or malformed" "Stacks On: '$value' blocks"
done
for line in '  Stacks On: pr1' '- Stacks On: pr1' '**Stacks On:** pr1' 'Stacks On:' 'stacks on: pr1'; do
  awk -v l="$line" 'tolower($0) ~ /stacks on/ { next } { print } /^Status:/ { print l }' "$FE" > "$TMP_ROOT/fe" && cp "$TMP_ROOT/fe" "$FE"
  assert_block "$(run_gate "$repo" dev-execute-feature "$FE")" "'Stacks On:' line that is misplaced" "a Stacks On line written as '$line' blocks"
done

# ── execute-feature ──
use_repo
write_plan "$P" planning
assert_block "$(run_gate "$repo" dev-execute-feature "$P")" 'not approved' 'a planning plan does not execute'
write_plan "$P" implemented
assert_block "$(run_gate "$repo" dev-execute-feature "$P")" 'already implemented' 'an implemented plan does not re-execute'
use_repo
plan_with_worktree approved
assert_pass "$(run_gate "$repo" dev-execute-feature "$P")" 'an approved plan with a worktree resumes'

use_repo
write_plan "$P" planning
sed -i '2i ```\nStatus: approved\n```' "$P"
assert_block "$(run_gate "$repo" dev-execute-feature "$P")" "Plan status is 'planning'" 'a fenced Status line is not the header'

# ── review-code ──
use_repo
write_plan "$P" implemented
assert_block "$(run_gate "$repo" dev-review-code "$P")" "Plan $P has no worktree" 'review-code needs the worktree'
write_plan "$P" reviewed
assert_block "$(run_gate "$repo" dev-review-code "$P")" 'already reviewed' 'status is checked before the worktree'
use_repo
plan_with_worktree approved
wt=$(wt_of "$P")
assert_block "$(run_gate "$repo" dev-review-code "$P")" 'not yet implemented' 'an approved plan is not reviewed'
sed -i 's/Status: approved/Status: implemented/' "$P"
assert_block "$(run_gate "$repo" dev-review-code "$P")" "Found no 'test(red):' commit" 'review requires a RED commit'
wt_commit "$wt" 'test(red): gate' tests/gate_test.py
wt_commit "$wt" 'feat(gate): implement' src/gate.py
assert_pass "$(run_gate "$repo" dev-review-code "$P")" 'RED then implementation enters review'
assert_pass "$(run_gate "$wt" dev-review-code "$P")" 'from the worktree, the plan and worktree history combine'
git -C "$wt" switch -q -c feat/other
assert_block "$(run_gate "$repo" dev-review-code "$P")" "not this plan's branch 'feat/gate'" "the worktree must be on the plan's branch"
git -C "$wt" switch -q feat/gate
write_plan "$P" implemented '## Acceptance Criteria
AC-1 — outcome
## Test Cases
TC-1 — scenario
  Proves: AC-1
TC-2 — added during execution
  Proves: AC-1
## Implementation Steps
ST-1 — action — satisfies TC-1'
assert_block "$(run_gate "$repo" dev-review-code "$P")" 'TC-2 is not satisfied by any Implementation Step' 'review-code re-checks closure'

use_repo
plan_with_worktree implemented
wt=$(wt_of "$P")
wt_commit "$wt" 'chore: setup' src/gate.py
wt_commit "$wt" 'test(red): gate' tests/gate_test.py
wt_commit "$wt" 'feat(gate): implement' src/gate.py
assert_block "$(run_gate "$repo" dev-review-code "$P")" 'out of sequence' 'a commit before RED blocks'

use_repo
plan_with_worktree implemented
wt=$(wt_of "$P")
wt_commit "$wt" 'test(red): gate' tests/gate_test.py
printf 'base moved\n' >> "$repo/README.md"
git -C "$repo" commit -qam 'chore: base moves'
git -C "$wt" merge -q --no-edit main
assert_block "$(run_gate "$repo" dev-review-code "$P")" 'out of sequence' 'a merge after RED is not an implementation'

use_repo
plan_with_worktree implemented
wt=$(wt_of "$P")
wt_commit "$wt" 'test(red): gate' tests/gate_test.py
wt_commit "$wt" 'test(update): gate' tests/gate_test.py
assert_block "$(run_gate "$repo" dev-review-code "$P")" 'out of sequence' 'a test(update) after RED is not an implementation'
wt_commit "$wt" 'feat(gate): implement' src/gate.py
assert_pass "$(run_gate "$repo" dev-review-code "$P")" 'RED, test(update), then implementation enters review'
wt_commit "$wt" 'test(update): gate again' tests/gate_test.py
assert_pass "$(run_gate "$repo" dev-review-code "$P")" 'a trailing test(update) leaves the proof complete'

use_repo
plan_with_worktree implemented "$(valid_graph)" refactor
wt=$(wt_of "$P")
wt_commit "$wt" 'test(red): gate' tests/gate_test.py
wt_commit "$wt" 'refactor: split' src/gate.py
assert_block "$(run_gate "$repo" dev-review-code "$P")" "Found no 'test: baseline' commit" 'a refactor proves with a baseline commit'
git -C "$wt" reset -q --hard main
wt_commit "$wt" 'test: baseline gate' tests/gate_test.py
wt_commit "$wt" 'refactor: split' src/gate.py
assert_pass "$(run_gate "$repo" dev-review-code "$P")" 'baseline then refactor enters review'

# A stacked plan's proof starts at its parent plan's branch, which its branch
# contains; the parent's history is not this plan's. The branch may be only on
# origin after cleanup.
use_repo
git -C "$repo" worktree add -q -b feat/gate "$(wt_of "$BE")" main
wt_commit "$(wt_of "$BE")" 'test(red): be' tests/be_test.py
wt_commit "$(wt_of "$BE")" 'feat(be): implement' src/be.py
write_plan "$BE" reviewed
git -C "$repo" worktree add -q -b feat/fe "$(wt_of "$FE")" feat/gate
write_plan "$FE" implemented "$(valid_graph)" feature '#12' 'Stacks On: pr1' feat/fe
wt_commit "$(wt_of "$FE")" 'test(red): fe' tests/fe_test.py
wt_commit "$(wt_of "$FE")" 'feat(fe): implement' src/fe.py
assert_pass "$(run_gate "$repo" dev-review-code "$FE")" "proof starts at the parent plan's branch"
git -C "$repo" update-ref refs/remotes/origin/feat/gate feat/gate
git -C "$repo" worktree remove "$(wt_of "$BE")"
git -C "$repo" branch -q -D feat/gate
assert_pass "$(run_gate "$repo" dev-review-code "$FE")" "a parent branch only on origin resolves"
git -C "$repo" worktree add -q "$repo-late" origin/feat/gate 2>/dev/null
wt_commit "$repo-late" 'feat(be): late change' src/be.py
git -C "$repo" update-ref refs/remotes/origin/feat/gate "$(git -C "$repo-late" rev-parse HEAD)"
assert_block "$(run_gate "$repo" dev-review-code "$FE")" "The PR target 'feat/gate' is missing or is not an ancestor" 'a change on the parent branch not merged forward blocks'
git -C "$repo-late" mv src/be.py notes.md && git -C "$repo-late" commit -qm 'chore: move be'
git -C "$repo" update-ref refs/remotes/origin/feat/gate "$(git -C "$repo-late" rev-parse HEAD)"
assert_block "$(run_gate "$repo" dev-review-code "$FE")" "The PR target 'feat/gate' is missing or is not an ancestor" 'any commit on the parent branch not merged forward blocks'

# A repair to the parent merged forward into the child reads as one line of
# history even when commit dates interleave the plans.
use_repo
wt=$(wt_of "$BE")
wtf=$(wt_of "$FE")
git -C "$repo" worktree add -q -b feat/gate "$wt" main
dated() { GIT_AUTHOR_DATE="@$1 +0000" GIT_COMMITTER_DATE="@$1 +0000" wt_commit "$2" "$3" "$4"; }
dated 1700000001 "$wt" 'test(red): s1' tests/s1_test.py
dated 1700000002 "$wt" 'feat(s1): implement' src/s1.py
git -C "$repo" worktree add -q -b feat/fe "$wtf" feat/gate
dated 1700000003 "$wtf" 'test(red): s2' tests/s2_test.py
dated 1700000004 "$wt" 'test(red): s1 repair' tests/s1_test.py
dated 1700000005 "$wtf" 'feat(s2): implement' src/s2.py
dated 1700000006 "$wt" 'fix(s1): repair' src/s1.py
GIT_AUTHOR_DATE='@1700000007 +0000' GIT_COMMITTER_DATE='@1700000007 +0000' git -C "$wtf" merge -q --no-edit feat/gate
write_plan "$BE" reviewed
write_plan "$FE" implemented "$(valid_graph)" feature '#12' 'Stacks On: pr1' feat/fe
assert_pass "$(run_gate "$repo" dev-review-code "$FE")" 'a parent repair merged forward passes despite interleaved dates'

# Base may advance without the plan merging it; review starts at the fork.
use_repo
plan_with_worktree implemented
wt=$(wt_of "$P")
wt_commit "$wt" 'test(red): gate' tests/gate_test.py
wt_commit "$wt" 'feat(gate): implement' src/gate.py
printf 'moved\n' >> "$repo/README.md" && git -C "$repo" commit -qam 'chore: base moves'
assert_pass "$(run_gate "$repo" dev-review-code "$P")" 'Base advancing without a merge does not block review'

# origin/<Base> wins over a stale local Base, as in dev-publish.sh.
use_repo
git -C "$repo" checkout -qb up
printf 'upstream\n' > "$repo/up.txt" && git -C "$repo" add up.txt && git -C "$repo" commit -qm 'feat: upstream'
git -C "$repo" update-ref refs/remotes/origin/main up
git -C "$repo" checkout -q main && git -C "$repo" branch -q -D up
git -C "$repo" worktree add -q -b feat/gate "$(wt_of "$P")" origin/main
write_plan "$P" implemented
wt_commit "$(wt_of "$P")" 'test(red): gate' tests/gate_test.py
wt_commit "$(wt_of "$P")" 'feat(gate): implement' src/gate.py
assert_pass "$(run_gate "$repo" dev-review-code "$P")" 'a plan from origin/<Base> reviews from it when local Base is behind'

fe_repo implemented implemented
git -C "$repo" worktree add -q -b feat/fe "$(wt_of "$FE")" main
assert_block "$(run_gate "$repo" dev-review-code "$FE")" "Parent plan $BE is 'implemented'; review-code needs it 'reviewed'" 'code review waits for a revised parent'

# ── create-pr ──
use_repo
plan_with_worktree reviewed
set_reviewed "$P"
assert_block "$(run_gate "$repo" dev-create-pr "$P")" "Plan status is 'reviewed without its SHA'" 'create-pr needs the root reviewed SHA'
use_repo
write_plan "$P" "reviewed $(git -C "$repo" rev-parse HEAD)"
assert_block "$(run_gate "$repo" dev-create-pr "$P")" "Plan $P has no worktree" 'create-pr needs the worktree'
use_repo
plan_with_worktree implemented
assert_block "$(run_gate "$repo" dev-create-pr "$P")" 'run review-code first' 'an implemented plan cannot skip review-code'
wt_commit "$(wt_of "$P")" 'feat(gate): no test first' src/gate.py
set_reviewed "$P" "$(git -C "$repo" rev-parse feat/gate)"
assert_block "$(run_gate "$repo" dev-create-pr "$P")" "has no 'test(red):' commit followed by implementation after" 'a reviewed status set by hand does not skip the proof'
use_repo
plan_with_worktree reviewed
printf 'pr1: code-review needs-changes (2/3) at %s\n' "$(git -C "$repo" rev-parse feat/gate)" >> "$(dirname "$P")/log"
assert_block "$(run_gate "$repo" dev-create-pr "$P")" "its last review-code verdict in the stack log is not a pass" 'a reviewed status after a needs-changes verdict blocks publication'
log_pass "$P" "$(git -C "$repo" rev-parse main)"
assert_block "$(run_gate "$repo" dev-create-pr "$P")" "its last review-code verdict in the stack log is not a pass" 'a pass logged at another SHA does not cover the Tip'
use_repo
plan_with_worktree reviewed
# A tree: $P has children $C2 and $C3, and $C2 has its only child $C4, each
# in its own worktree.
C2="$PD/12_gate/pr2.spec.md"
C3="$PD/12_gate/pr3.spec.md"
C4="$PD/12_gate/pr4.spec.md"
git -C "$repo" worktree add -q --detach "$(wt_of "$C2")" main
git -C "$repo" worktree add -q --detach "$(wt_of "$C3")" main
git -C "$repo" worktree add -q --detach "$(wt_of "$C4")" main
git -C "$repo" branch -q feat/c4 main
green=$(git -C "$repo" rev-parse feat/gate)
stack_on() {  # stack_on <plan> <status> <parent pr<K>> <own branch>; reviewed with a proof on the parent's reviewed SHA
  local status="$2"
  [[ "$status" != reviewed ]] || status="reviewed $(proof_on "$(green_in "$PD/12_gate/${3#./}.spec.md")")"
  write_plan "$1" "$status" "$(valid_graph)" feature '#12' "Stacks On: $3" "$4"
}
stack_on "$C2" implemented pr1 feat/gate
assert_block "$(run_gate "$repo" dev-create-pr "$P")" "Plan $C2 has 'Branch: feat/gate', but its PR targets its parent plan's branch" 'publication rechecks that each plan above stacks correctly'
stack_on "$C2" implemented pr1 feat/c2
assert_block "$(run_gate "$repo" dev-create-pr "$P")" "Plan $C2 stacks above this plan and is 'implemented'" 'the root waits for its child to be reviewed'
write_plan "$C2" planning "$(valid_graph)" feature '#12' 'Stacks On: docs/plan/typo.spec.md' feat/c2
assert_block "$(run_gate "$repo" dev-create-pr "$P")" "$C2 has a 'Stacks On:' line that is misplaced" 'a malformed Stacks On elsewhere blocks publication'
stack_on "$C2" reviewed pr1 feat/c2
stack_on "$C3" reviewed pr1 feat/c3
stack_on "$C4" approved pr2 feat/c4
assert_block "$(run_gate "$repo" dev-create-pr "$P")" "Plan $C4 stacks above this plan and is 'approved'" 'the root waits for a grandchild to be reviewed'
stack_on "$C4" reviewed pr2 feat/c4
assert_pass "$(run_gate "$repo" dev-create-pr "$P")" 'the root publishes once every plan in its tree is reviewed'
set_reviewed "$C4" "$(green_in "$C2")"
assert_block "$(run_gate "$repo" dev-create-pr "$P")" "Plan $C4's reviewed SHA $(green_in "$C2") has no 'test(red):' commit followed by implementation" 'a child without its own proof blocks publication'
stack_on "$C4" reviewed pr2 feat/c4
git -C "$repo" worktree remove "$(wt_of "$C3")"
assert_block "$(run_gate "$repo" dev-create-pr "$P")" "Plan $C3 has no worktree" 'a plan without its worktree or branch has no worktree'
git -C "$repo" branch -q feat/c3 main
assert_block "$(run_gate "$repo" dev-create-pr "$P")" "Plan $C3 has no worktree" "a plan never uses its parent's worktree"
git -C "$repo" worktree add -q --detach "$(wt_of "$C3")" main
set_reviewed "$C2"
assert_block "$(run_gate "$repo" dev-create-pr "$P")" "Plan $C2 stacks above this plan and is 'reviewed without its SHA'" 'each plan above needs its reviewed SHA'
stack_on "$C2" reviewed pr1 feat/c2
run_gate "$repo" dev-create-pr "$P" >/dev/null
printf 'Note: added later\n' >> "$C4"
assert_block "$(STALE_OK=1 run_gate "$repo" dev-create-pr "$P")" "Plan $C4 has no ready 'Spec:' hash" 'a line added after review voids it'
stack_on "$C4" reviewed pr2 feat/c4
sed -i 's/^Gate the phases\./Gate every phase./' "$C4"
assert_block "$(STALE_OK=1 run_gate "$repo" dev-create-pr "$P")" "Plan $C4 has no ready 'Spec:' hash" 'a stack plan edited after review blocks publication'
sed -i 's/^Gate the phases\./Gate every phase./' "$P"
assert_block "$(STALE_OK=1 run_gate "$repo" dev-create-pr "$P")" "Plan $P has no ready 'Spec:' hash" 'a root edited after review blocks publication'
stale=$(green_in "$C2")
wt_commit "$(wt_of "$P")" 'fix: root repair' src/root.py
green=$(git -C "$(wt_of "$P")" rev-parse HEAD)
set_reviewed "$P" "$green"
assert_block "$(run_gate "$repo" dev-create-pr "$P")" "Plan $C2's reviewed SHA $stale does not contain its parent $P's, $green" 'a child reviewed before a root repair blocks publication'
stack_on "$C2" reviewed pr1 feat/c2
stack_on "$C3" reviewed pr1 feat/c3
stack_on "$C4" reviewed pr2 feat/c4
assert_pass "$(run_gate "$repo" dev-create-pr "$P")" 'children re-reviewed on the repaired root publish'
printf 'pr3: stop review-code round limit (3/3) at %s\n' "$(printf '0%.0s' {1..40})" >> "$PD/12_gate/log"
assert_block "$(run_gate "$repo" dev-create-pr "$P")" "Plan $C3 stacks above this plan and is stopped" 'a stopped plan above the root blocks publication'
sed -i '/^pr3: stop /d' "$PD/12_gate/log"
printf '\n```\nStacks On: pr3\n```\n' >> "$C4"
assert_pass "$(run_gate "$repo" dev-create-pr "$P")" 'a Stacks On line in a fenced block is not the header'
stack_on "$C4" reviewed ./pr2 feat/c4
assert_block "$(run_gate "$repo" dev-create-pr "$P")" "$C4 has a 'Stacks On:' line that is misplaced" 'a Stacks On value other than pr<K> blocks'
stack_on "$C4" reviewed pr2 feat/c4
sed -i '2i ```' "$C4"
assert_block "$(run_gate "$repo" dev-create-pr "$P")" "$C4 has a 'Stacks On:' line that is misplaced" 'an unclosed fence blocks'
stack_on "$C4" reviewed pr2 feat/c4
ln -s pr4.spec.md "$PD/12_gate/pr9.spec.md"
assert_block "$(run_gate "$repo" dev-create-pr "$P")" "pr9.spec.md has a 'Stacks On:' line" 'a symlinked plan blocks publication'
rm "$PD/12_gate/pr9.spec.md"
sed -i "/^Stacks On:/d; /^## Goal/a Stacks On: pr2" "$C4"
assert_block "$(run_gate "$repo" dev-create-pr "$P")" "$C4 has a 'Stacks On:' line that is misplaced" 'a Stacks On line below the header blocks'
stack_on "$C4" reviewed pr2 feat/c4
write_plan "$PD/12_gate/pr6.spec.md" reviewed "$(valid_graph)" feature '#12' 'Stacks On: pr5' feat/c6
assert_block "$(run_gate "$repo" dev-create-pr "$P")" "pr6.spec.md has a 'Stacks On:' line that is misplaced, repeated, malformed, or names no plan" 'a child of a missing plan blocks publication'
rm "$PD/12_gate/pr6.spec.md"
assert_block "$(run_gate "$repo" dev-create-pr "$C2")" "create-pr runs once, on the stack's root $P" 'create-pr on a stacked plan names the root'
git -C "$repo" worktree remove "$(wt_of "$C4")"
assert_block "$(run_gate "$repo" dev-create-pr "$P")" "Plan $C4 has no worktree" 'publication needs every worktree in the stack'
sed -i 's/^Status: reviewed$/Status: published/' "$C4"
assert_pass "$(run_gate "$repo" dev-create-pr "$P")" 'a plan published by an earlier cleanup leaves the stack'


# ── a current ready Spec ──
NO_REVIEW="no ready 'Spec:' hash for its current spec"
use_repo
write_plan "$P" approved
assert_block "$(STALE_OK=1 run_gate "$repo" dev-execute-feature "$P")" "$NO_REVIEW" 'execution needs a recorded review'
ready "$P"
assert_pass "$(STALE_OK=1 run_gate "$repo" dev-execute-feature "$P")" 'a current review admits execution'
sed -i 's/^Gate the phases\./Gate every phase./' "$P"
assert_block "$(STALE_OK=1 run_gate "$repo" dev-execute-feature "$P")" "$NO_REVIEW" 'a spec edit after review blocks execution'
sed -i 's/^Spec: .*/Spec: nothex/' "$P"
assert_block "$(STALE_OK=1 run_gate "$repo" dev-execute-feature "$P")" "$NO_REVIEW" 'a malformed Spec hash blocks execution'
sed -i 's/^Status: approved$/Status: needs-changes/' "$P"; ready "$P"
assert_block "$(STALE_OK=1 run_gate "$repo" dev-execute-feature "$P")" "Plan status is 'needs-changes' — not approved. Revise it" 'a needs-changes verdict blocks execution'
assert_pass "$(STALE_OK=1 run_gate "$repo" dev-review-feature "$P")" 'a needs-changes plan re-enters review'
(cd "$repo" && bash "$ROOT/bin/dev-stack.sh" review "$P" needs-changes >/dev/null)
sed -i 's/^Status: needs-changes$/Status: approved/' "$P"
assert_block "$(STALE_OK=1 run_gate "$repo" dev-execute-feature "$P")" "$NO_REVIEW" 'approving a needs-changes verdict by hand blocks execution'
sed -i 's/^Status: approved$/Status: needs-changes/' "$P"
sed -i 's/^Status: needs-changes$/Status: ready/' "$P"
assert_pass "$(STALE_OK=1 run_gate "$repo" dev-review-feature "$P")" 'a ready plan may be reviewed again'
fe_repo reviewed approved
ready "$FE"
assert_pass "$(STALE_OK=1 run_gate "$repo" dev-execute-feature "$FE")" 'a stacked plan with a current review executes'
sed -i 's/^Gate the phases\./Gate every phase./' "$BE"
assert_block "$(STALE_OK=1 run_gate "$repo" dev-execute-feature "$FE")" "$NO_REVIEW" 'a parent spec edit voids the child review'
use_repo
plan_with_worktree implemented
assert_block "$(STALE_OK=1 run_gate "$repo" dev-review-code "$P")" "$NO_REVIEW" 'code review needs a current review'


# ── stops and the approval ratchet ──
STACK_SH="$ROOT/bin/dev-stack.sh"
use_repo
write_plan "$P" planning
(cd "$repo" && bash "$STACK_SH" stop "$P" 'needs a decision' >/dev/null)
assert_block "$(run_gate "$repo" dev-review-feature "$P")" 'is stopped: needs a decision' 'a stopped plan is blocked at its gate'
assert_block "$(prompt_gate "$repo" "/dev-review-feature $P")" 'is stopped' "the user's typed phase is blocked too until resume"
assert_pass "$(cd "$repo" && bash "$GATE" --design "$P" </dev/null)" "design-feature's stack check ignores a stop"
(cd "$repo" && bash "$STACK_SH" resume "$P" >/dev/null)
assert_pass "$(run_gate "$repo" dev-review-feature "$P")" 'resume reopens the gate'
use_repo
write_plan "$P" planning
(cd "$repo" && bash "$STACK_SH" review "$P" ready >/dev/null && bash "$STACK_SH" approve "$P" >/dev/null)
assert_pass "$(STALE_OK=1 run_gate "$repo" dev-execute-feature "$P")" 'an auto-approved plan executes'
sed -i 's/^Gate the phases\./Gate every phase./' "$P"
assert_block "$(STALE_OK=1 run_gate "$repo" dev-execute-feature "$P")" 'is frozen: its spec, or a spec below it, changed since its approval' 'an approved plan whose spec changed is frozen'
sed -i 's/^Gate every phase\./Gate the phases./; s/^Status: .*/Status: planning/' "$P"
assert_block "$(STALE_OK=1 run_gate "$repo" dev-review-feature "$P")" 'never returns to planning' 'an approved plan returned to planning is frozen'
assert_block "$(cd "$repo" && bash "$GATE" --design "$P" </dev/null)" 'never returns to planning' "design-feature's stack check refuses it too"
(cd "$repo" && bash "$STACK_SH" reopen "$P" >/dev/null)
assert_pass "$(STALE_OK=1 run_gate "$repo" dev-review-feature "$P")" "the user's reopen lifts the freeze"

# ── PC checks ──
pc_graph() { valid_graph; printf '%s\n' "$@"; }
review_graph 'a PC without a Check blocks' "$(pc_graph '  PC-1 — the gate exists')" 'PC-1 has no "— Check: <command>"'
review_graph 'a PC Check that counts with grep -c blocks' "$(pc_graph '  PC-1 — three callers — Check: test "$(grep -rc gate src)" = 3')" 'PC-1 counts matches'
review_graph 'a PC Check that counts with wc -l blocks' "$(pc_graph '  PC-1 — three callers — Check: grep -r gate src | wc -l | grep -qx 3')" 'PC-1 counts matches'
review_graph 'a PC Check that counts with rg -c blocks' "$(pc_graph '  PC-1 — three callers — Check: rg -c gate src')" 'PC-1 counts matches'
review_graph 'a count inside a command substitution with its own quotes blocks' "$(pc_graph '  PC-1 — one gate — Check: test "$(grep "def gate" -c src/x.py)" = 1')" 'PC-1 counts matches'
review_graph 'wc -l closing a command substitution blocks' "$(pc_graph '  PC-1 — three callers — Check: test "$(grep -r "gate(" src | wc -l)" -eq 3')" 'PC-1 counts matches'
review_graph 'rg --count closing a command substitution blocks' "$(pc_graph '  PC-1 — three callers — Check: [ "$(rg gate src --count)" = 3 ]')" 'PC-1 counts matches'
review_graph 'a structural PC Check passes' "$(pc_graph '  PC-1 — gate() exists — Check: grep -q "def gate" src/gate.py' '  PC-2 — no caller of old() — Check: ! grep -rq "old(" src')" ''

# ── Type: config ──
use_repo
plan_with_worktree implemented "$(valid_graph)" config
wt=$(wt_of "$P")
assert_block "$(run_gate "$repo" dev-review-code "$P")" 'Found no implementation commit between' 'a config plan needs a commit of its own'
wt_commit "$wt" 'chore(i18n): add strings' locales/en.json
assert_pass "$(run_gate "$repo" dev-review-code "$P")" 'a config plan enters review-code without a proof commit'
write_plan "$P" "reviewed $(git -C "$repo" rev-parse feat/gate)" "$(valid_graph)" config
assert_pass "$(run_gate "$repo" dev-create-pr "$P")" 'a reviewed config plan publishes without a proof commit'
write_plan "$P" "reviewed $(git -C "$repo" rev-parse main)" "$(valid_graph)" config
assert_block "$(run_gate "$repo" dev-create-pr "$P")" "has no implementation commit after" 'a config plan reviewed without a commit of its own blocks publication'

# ── record guard: Bash, Edit, and Write calls ──
use_repo
guard() { jq -cn --arg t "$1" --argjson i "$2" '{hook_event_name:"PreToolUse",tool_name:$t,tool_input:$i}' | (cd "$repo" && "$GATE"); }
bash_guard() { guard Bash "$(jq -cn --arg c "$1" '{command:$c}')"; }
LOG="$(dirname "$P")/log"
assert_block "$(bash_guard "~/.dotfiles/.ai-shared/bin/dev-stack.sh resume $P")" "dev-stack.sh resume is the user's alone" 'an agent cannot run resume'
assert_block "$(bash_guard "bash dev-stack.sh reopen '$P'")" "dev-stack.sh reopen is the user's alone" 'an agent cannot run reopen'
assert_block "$(bash_guard "cd /tmp && env FOO=1 \"\$HOME/.dotfiles/.ai-shared/bin/dev-stack.sh\" resume $P")" "dev-stack.sh resume is the user's alone" 'resume after a separator and a quoted path is caught'
assert_block "$(bash_guard $'true\ndev-stack.sh resume '"$P")" "dev-stack.sh resume is the user's alone" 'resume on a later line is caught'
assert_pass "$(bash_guard "grep -n 'dev-stack.sh resume' README.md; echo 'ask the user to run dev-stack.sh reopen'")" 'a mention of resume or reopen in an argument passes'
assert_pass "$(bash_guard "~/.dotfiles/.ai-shared/bin/dev-stack.sh next $P")" 'an agent runs next'
assert_pass "$(bash_guard "git log --oneline -5 && grep resume README.md")" 'an unrelated command passes'
assert_block "$(bash_guard "echo 'pr1: cleared' >> $LOG")" 'written only by dev-stack.sh' 'an agent cannot append to the stack log'
assert_pass "$(bash_guard "cat $LOG 2>/dev/null; tail -3 $LOG")" 'an agent reads the stack log'
assert_pass "$(bash_guard "grep review $LOG > /tmp/out; tail -3 $LOG >> /tmp/out")" 'reading the log into another file passes'
assert_pass "$(bash_guard "cp x.go ~/work/wt/repo-12_slug-pr1/log/handler.go && echo x > ~/work/wt/repo-12_slug-pr1/log/a.go")" "a worktree's log/ directory is not the stack log"
assert_block "$(bash_guard "cd $(dirname "$(dirname "$P")") && printf x >> 12_gate/log")" 'written only by dev-stack.sh' 'a relative write to the stack log is caught'
assert_block "$(bash_guard "cp /tmp/x $LOG")" 'written only by dev-stack.sh' 'a copy over the stack log is caught'
assert_block "$(bash_guard "cd $repo && cp /tmp/a docs/plans/12_gate/log")" 'written only by dev-stack.sh' 'a write relative to the repository root is caught'
assert_block "$(bash_guard "cd $repo/docs && cp /tmp/a plans/12_gate/log")" 'written only by dev-stack.sh' 'a write relative to docs/ is caught'
assert_block "$(bash_guard "sed --in-place 's/x/y/' $LOG")" 'written only by dev-stack.sh' 'sed --in-place on the stack log is caught'
assert_block "$(bash_guard "echo x >& $LOG")" 'written only by dev-stack.sh' 'a >& redirection into the stack log is caught'
assert_block "$(bash_guard "cd $(dirname "$P") && echo x >> ../12_gate/log")" 'written only by dev-stack.sh' 'a ../ path to the stack log is caught'
assert_block "$(guard Write "$(jq -cn --arg f "$LOG" '{file_path:$f,content:"x"}')")" 'written only by dev-stack.sh' 'Write cannot touch the stack log'
write_plan "$P" ready
assert_block "$(guard Edit "$(jq -cn --arg f "$P" '{file_path:$f,old_string:"Status: ready",new_string:"Status: approved"}')")" "Only the user sets 'Status: approved'" 'an agent cannot approve'
assert_block "$(guard Edit "$(jq -cn --arg f "$P" '{file_path:$f,old_string:"Status: ready",new_string:"Status: auto-approved"}')")" 'Only dev-stack.sh approve' 'an agent cannot auto-approve by hand'
assert_pass "$(guard Edit "$(jq -cn --arg f "$P" '{file_path:$f,old_string:"Gate the phases.",new_string:"Gate every phase."}')")" 'a plan before approval is edited freely'
write_plan "$P" approved
assert_pass "$(guard Edit "$(jq -cn --arg f "$P" '{file_path:$f,old_string:"Status: approved",new_string:"Status: implemented"}')")" "an approved plan's Status moves forward"
assert_block "$(guard Edit "$(jq -cn --arg f "$P" '{file_path:$f,old_string:"Status: approved",new_string:"Status: planning"}')")" 'never returns to planning' "an approved plan's Status never returns to planning"
assert_block "$(guard Edit "$(jq -cn --arg f "$P" '{file_path:$f,old_string:"Status: approved",new_string:"Status: aproved"}')")" 'or to an unknown value' "an approved plan's Status never becomes an unknown value"
assert_block "$(guard Edit "$(jq -cn --arg f "$P" '{file_path:$f,old_string:"Gate the phases.",new_string:"Gate every phase."}')")" 'frozen: after approval only its Status and Tip' "an approved plan's spec is frozen"
assert_block "$(guard MultiEdit "$(jq -cn --arg f "$P" '{file_path:$f,edits:[{old_string:"Status: approved",new_string:"Status: implemented"},{old_string:"Gate the phases.",new_string:"Gate all."}]}')")" 'frozen' 'MultiEdit is checked edit by edit'
assert_block "$(guard Write "$(jq -cn --arg f "$P" --arg c "$(sed 's/Gate the phases\./Gate all./' "$P")" '{file_path:$f,content:$c}')")" 'frozen' 'Write is checked against the frozen spec'
assert_pass "$(guard Edit "$(jq -cn --arg f "$P" '{file_path:$f,old_string:"no such text",new_string:"x"}')")" 'an edit that matches nothing is left to fail on its own'
# A shell command runs between its PreToolUse snapshot and its PostToolUse check.
shell_run() {
  local id="t$RANDOM$RANDOM"
  jq -cn --arg c "$1" --arg id "$id" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_use_id:$id,tool_input:{command:$c}}' | (cd "$repo" && "$GATE") >/dev/null
  (cd "$repo" && bash -c "$1") >/dev/null 2>&1 || true
  jq -cn --arg c "$1" --arg id "$id" '{hook_event_name:"PostToolUse",tool_name:"Bash",tool_use_id:$id,tool_input:{command:$c}}' | (cd "$repo" && "$GATE")
}
D=$(dirname "$P"); n=$(basename "$P" .spec.md)
cp "$P" "$TMP_ROOT/approved.md"
assert_block "$(shell_run "sed -i 's/^Status: approved/Status: planning/' $P")" 'never returns below approved' 'a shell rollback of an approved plan is undone'
cmp -s "$P" "$TMP_ROOT/approved.md" || { printf "FAIL: rollback not restored\n" >&2; exit 1; }
assert_block "$(shell_run "python3 -c 'import sys; p=sys.argv[1]; open(p,\"a\").write(\"x\\n\")' $P")" 'its spec changed' 'any shell write to an approved spec is undone, python included'
cmp -s "$P" "$TMP_ROOT/approved.md" || { printf 'FAIL: spec not restored\n' >&2; exit 1; }
assert_block "$(shell_run "rm -f $P")" 'moved or deleted' 'deleting an approved plan is undone'
[[ -f "$P" ]] || { printf 'FAIL: deleted plan not restored\n' >&2; exit 1; }
assert_pass "$(shell_run "sed -i 's/^Status: approved/Status: implemented/' $P; cat $P > /dev/null; cp $P /tmp/copy")" "an approved plan's Status moves forward by shell, and reads pass"
grep -qx 'Status: implemented' "$P" || { printf 'FAIL: forward Status reverted\n' >&2; exit 1; }
# dev-stack.sh's own flows pass the check, and a plan removed with rm while
# the log holds its lines comes back.
SD="$PD/13_flow"; mkdir -p "$SD"
write_plan "$SD/pr1.spec.md" planning; write_plan "$SD/pr2.spec.md" planning "$(valid_graph)" feature '#13' 'Stacks On: pr1' feat/f2
assert_pass "$(shell_run "'$ROOT/bin/dev-stack.sh' review $SD/pr2.spec.md needs-changes && '$ROOT/bin/dev-stack.sh' stop $SD/pr2.spec.md 'x' && '$ROOT/bin/dev-stack.sh' next $SD/pr1.spec.md")" 'review, stop, and next pass the check'
assert_block "$(shell_run "rm $SD/pr2.spec.md")" 'still holds its lines' 'a plan removed with rm while the log holds its lines comes back'
[[ -f "$SD/pr2.spec.md" ]] || { printf 'FAIL: removed plan not restored\n' >&2; exit 1; }
(cd "$repo" && "$ROOT/bin/dev-stack.sh" resume "$SD/pr2.spec.md" >/dev/null)
assert_pass "$(shell_run "'$ROOT/bin/dev-stack.sh' renumber $SD/pr1.spec.md 2=3")" 'renumber passes the check'
assert_pass "$(shell_run "'$ROOT/bin/dev-stack.sh' drop $SD/pr3.spec.md")" 'drop passes the check'
[[ ! -e "$SD/pr3.spec.md" && ! -e "$SD/pr2.spec.md" ]] || { printf 'FAIL: renumber or drop undone\n' >&2; exit 1; }
rm -rf "$SD"
# dev-stack.sh auto-reopen passes the check; a second auto-reopen, or one
# over the user's approval, forged by a shell command, is undone.
SD="$PD/14_auto"; mkdir -p "$SD"; SP="$SD/pr1.spec.md"
write_plan "$SP" planning "$(valid_graph)" feature '#14'
(cd "$repo" && "$ROOT/bin/dev-stack.sh" review "$SP" ready >/dev/null && "$ROOT/bin/dev-stack.sh" approve "$SP" >/dev/null)
assert_block "$(shell_run "sed -i 's/^Status: auto-approved/Status: planning/' $SP")" 'never returns below approved' 'a shell rollback of an auto-approved plan is undone'
grep -qx 'Status: auto-approved' "$SP" || { printf 'FAIL: auto-approved rollback not undone\n' >&2; exit 1; }
assert_pass "$(shell_run "'$ROOT/bin/dev-stack.sh' auto-reopen $SP")" 'auto-reopen passes the check'
grep -qx 'Status: planning' "$SP" || { printf 'FAIL: auto-reopen undone\n' >&2; exit 1; }
(cd "$repo" && "$ROOT/bin/dev-stack.sh" review "$SP" ready >/dev/null && "$ROOT/bin/dev-stack.sh" approve "$SP" >/dev/null)
assert_block "$(shell_run "sed -i 's/^Status: auto-approved/Status: planning/' $SP && echo 'pr1: auto-reopened' >> $SD/lo''g")" 'never returns below approved' 'a second auto-reopen line never lifts the freeze'
grep -qx 'Status: auto-approved' "$SP" || { printf 'FAIL: second auto-reopen not undone\n' >&2; exit 1; }
assert_block "$(shell_run "sed -i '/auto-reopened/d' $SD/lo''g")" 'lost a line only dev-stack.sh writes' 'a shell command cannot drop an auto-reopen line'
rm -rf "$SD"; mkdir -p "$SD"
write_plan "$SP" planning "$(valid_graph)" feature '#14'
(cd "$repo" && "$ROOT/bin/dev-stack.sh" review "$SP" ready >/dev/null && "$ROOT/bin/dev-stack.sh" approve "$SP" >/dev/null)
sed -i 's/^Status: auto-approved/Status: approved/' "$SP"
assert_block "$(shell_run "sed -i 's/^Status: approved/Status: planning/' $SP && echo 'pr1: auto-reopened' >> $SD/lo''g")" 'never returns below approved' "an auto-reopen line never lifts the user's approval over autopilot's"
grep -qx 'Status: approved' "$SP" || { printf 'FAIL: forged auto-reopen over the user approval not undone\n' >&2; exit 1; }
rm -rf "$SD"
write_plan "$P" approved
assert_block "$(shell_run "sed -i 's/^Status: approved/Status: planning/' $P && echo '$n: auto-reopened' >> $D/lo''g")" 'never returns below approved' "an auto-reopen line never lifts the user's approval"
grep -qx 'Status: approved' "$P" || { printf 'FAIL: forged auto-reopen not undone\n' >&2; exit 1; }
rm -f "$D/log"
# A command that writes the log through a path the text check cannot see
# (here lo''g) is still judged after it runs.
write_plan "$P" approved
assert_block "$(shell_run "sed -i 's/^Status: approved/Status: planning/' $P && echo '$n: reopened' >> $D/lo''g")" 'never returns below approved' "a reopen line a shell command writes never lifts the freeze"
grep -qx 'Status: approved' "$P" || { printf 'FAIL: forged reopen not undone\n' >&2; exit 1; }
[[ ! -e "$D/log" ]] || { printf 'FAIL: forged reopen line kept\n' >&2; exit 1; }
printf '%s: stop review-code round limit (3/3) at %040d\n' "$n" 0 > "$D/log"
assert_block "$(shell_run ": > $D/lo''g")" 'lost a line only dev-stack.sh writes' 'a shell command cannot drop a stop line'
grep -q ': stop ' "$D/log" || { printf 'FAIL: stop line not restored\n' >&2; exit 1; }
rm -f "$D/log"
write_plan "$P" published
assert_block "$(shell_run "sed -i 's/^Status: published/Status: reviewed/' $P")" 'is published and changed' 'a shell edit to a published plan is undone'
assert_block "$(shell_run "sed -i 's/^Status: published/Status: planning/' $P && echo '$n: reopened' >> $D/lo''g")" 'is published and changed' 'a reopen line never unfreezes a published plan'
rm -f "$D/log"
write_plan "$P" ready
assert_pass "$(shell_run "sed -i 's/Gate the phases\./Gate all./' $P")" 'a shell edit before approval passes'
assert_block "$(shell_run "sed -i 's/^Status: ready/Status: approved/' $P")" 'which only the user sets' 'a shell command cannot approve'
grep -qx 'Status: ready' "$P" || { printf 'FAIL: approval not undone\n' >&2; exit 1; }
assert_block "$(shell_run "sed -i 's/^Status: ready/Status: implemented/' $P")" 'skipping approval' 'a shell command cannot skip approval'
grep -qx 'Status: ready' "$P" || { printf 'FAIL: skipped approval not undone\n' >&2; exit 1; }
assert_block "$(guard Edit "$(jq -cn --arg f "$P" '{file_path:$f,old_string:"Status: ready",new_string:"Status: implemented"}')")" 'only through approval' 'an edit cannot skip approval'
assert_block "$(shell_run "sed -i 's/^Status: ready/Status: auto-approved/' $P")" 'only dev-stack.sh approve sets' 'a shell command cannot auto-approve by hand'
assert_block "$(shell_run "sed -i 's/^Status: ready/Status: auto-approved/' $P && echo '$n: approve auto-approved at abc' >> $D/lo''g")" 'only dev-stack.sh approve sets' "a forged approve line at the wrong hash does not pass"
rm -f "$D/log"
assert_pass "$(shell_run "'$ROOT/bin/dev-stack.sh' review $P ready && '$ROOT/bin/dev-stack.sh' approve $P")" 'dev-stack.sh review and approve pass the check'
grep -qx 'Status: auto-approved' "$P" || { printf 'FAIL: dev-stack.sh approve undone\n' >&2; exit 1; }
rm -f "$D/log"; write_plan "$P" approved
assert_pass "$(guard Edit "$(jq -cn --arg f "$P" '{file_path:$f,old_string:"Status: approved",new_string:"Status: reviewed"}')")" 'reviewed before its Tip ranks as reviewed'
assert_pass "$(shell_run "ln $P $TMP_ROOT/hard; sed 's/^Status: approved/Status: planning/' $P > $TMP_ROOT/soft; ln -sf $TMP_ROOT/soft $D/pr2.spec.md")" 'links pass'
[[ "$(stat -c %h "$P")" == 1 && ! -L "$D/pr2.spec.md" ]] || { printf 'FAIL: plan links not replaced with copies\n' >&2; exit 1; }
rm -f "$D/pr2.spec.md" "$TMP_ROOT/hard" "$TMP_ROOT/soft"
mkdir -m 000 "$PD/99_locked"
assert_block "$(shell_run "sed -i 's/^Status: approved/Status: planning/' $P")" 'never returns below approved' 'an unreadable entry leaves the guard on'
chmod 700 "$PD/99_locked"; rmdir "$PD/99_locked"
other="$TMP_ROOT/other-repo/docs/plans/5_x/pr1.spec.md"
mkdir -p "${other%/*}"; printf '# O\nStatus: ready\nSpec: -\n' > "$other"
assert_pass "$(shell_run "sed -i 's/^Status: ready/Status: approved/' $other")" "another repository's plans are out of the call's scope"
grep -qx 'Status: approved' "$other" || { printf "FAIL: another repository's approval reverted\n" >&2; exit 1; }
rm -rf "$TMP_ROOT/other-repo"
jq -cn '{hook_event_name:"PreToolUse",tool_name:"Bash",session_id:"s1",tool_input:{command:"true"}}' | (cd "$repo" && "$GATE") >/dev/null
[[ ! -e "${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/dev-gate-check-$(id -u)/s1" ]] || { printf 'FAIL: snapshot keyed by session\n' >&2; exit 1; }
printf 'PASS: no snapshot without a tool_use_id\n'
rm -f "$D/log"; write_plan "$P" ready
assert_block "$(shell_run "printf '# New\nStatus: approved\n' > $D/pr7.spec.md")" 'which only the user sets' 'a new plan cannot be written approved'
grep -qx 'Status: planning' "$D/pr7.spec.md" || { printf 'FAIL: new approved plan not set to planning\n' >&2; exit 1; }
rm -f "$D/pr7.spec.md"
assert_pass "$(shell_run "sed -i 's/Gate/Skip/' $P && grep 'Status: approved' $P; echo 'wait for Status: approved'")" 'a mention of approved in another command passes'
id=failed$RANDOM
jq -cn --arg id "$id" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_use_id:$id,tool_input:{command:"x"}}' | (cd "$repo" && "$GATE") >/dev/null
sed -i 's/^Status: ready/Status: approved/' "$P"
assert_block "$(jq -cn --arg id "$id" '{hook_event_name:"PostToolUseFailure",tool_name:"Bash",tool_use_id:$id,tool_input:{command:"x"}}' | (cd "$repo" && "$GATE"))" 'which only the user sets' 'a failed command is checked too'
assert_pass "$(jq -cn '{hook_event_name:"PostToolUse",tool_name:"Bash",tool_use_id:"never-snapshotted",tool_input:{command:"true"}}' | (cd "$repo" && "$GATE"))" 'a post check without its snapshot passes'
write_plan "$P" approved
write_plan "$P" published
assert_block "$(guard Edit "$(jq -cn --arg f "$P" '{file_path:$f,old_string:"Status: published",new_string:"Status: reviewed"}')")" 'is published' 'a published plan takes no edit'
assert_pass "$(guard Edit "$(jq -cn --arg f "$repo/README.md" '{file_path:$f,old_string:"seed",new_string:"x"}')")" "files outside docs/plans pass"

printf 'All gate-check.sh tests passed. Temporary fixtures: %s\n' "$TMP_ROOT"
