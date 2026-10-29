#!/bin/bash
# gate-check.sh against scratch repositories: block and pass cases for each gate.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
GATE="$ROOT/bin/gate-check.sh"
TMP_ROOT=$(mktemp -d /tmp/gate-check-test.XXXXXX)
export AI_PLANS_ROOT="$TMP_ROOT/plans" AI_WORKTREES_ROOT="$TMP_ROOT/worktrees"

new_repo() {
  local repo
  repo=$(mktemp -d "$TMP_ROOT/repo.XXXXXX")
  git -C "$repo" init -q -b main
  git -C "$repo" config user.email gate-check@example.test
  git -C "$repo" config user.name gate-check-test.sh
  printf 'seed\n' > "$repo/README.md"
  git -C "$repo" add README.md
  git -C "$repo" commit -qm seed
  printf '%s\n' "$repo"
}

# A fresh repository in $repo, its plans directory in $PD, and plan paths:
# $P alone in its stack, and $BE with $FE stacked on it.
use_repo() {
  repo=$(new_repo)
  PD="$AI_PLANS_ROOT/$(basename "$repo")"
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

# write_plan <file> <status> [graph] [type] [issue] [extra header line] [branch]
# A bare `reviewed` gets the repository's HEAD as its Tip; `reviewed <sha>`
# gets <sha>.
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
set_reviewed() { sed -i "s/^Status: .*/Status: reviewed/; s/^Tip: .*/Tip: ${2:--}/" "$1"; }

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
    for f in "$AI_PLANS_ROOT/$(basename "$main")"/*/pr*.spec.md; do
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
assert_pass "$(run_gate "$repo" dev-execute-feature "@$P, please")" 'surrounding punctuation is not part of the path'
assert_pass "$(HOME="$TMP_ROOT" run_gate "$repo" dev-execute-feature "~/plans/$(basename "$repo")/12_gate/pr1.spec.md")" 'a path starting with ~ resolves'
assert_block "$(run_gate "$repo" dev-execute-feature "12_gate/pr1.spec.md")" 'not found' 'a relative path does not resolve'
assert_block "$(run_gate "$repo" dev-execute-feature "/other/repo/12_gate/pr1.spec.md")" 'not found' 'a path outside the plans root does not resolve'
write_plan "$AI_PLANS_ROOT/other/12_gate/pr1.spec.md" approved
assert_block "$(run_gate "$repo" dev-execute-feature "$AI_PLANS_ROOT/other/12_gate/pr1.spec.md")" 'not found' "another repository's plan does not resolve"
assert_block "$(run_gate "$repo" dev-execute-feature "$PD/../other/12_gate/pr1.spec.md")" 'not found' 'traversal out of the repository plans does not resolve'
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
assert_block "$(run_gate "$repo" dev-review-code "$P")" "Plan $P has no worktree: neither $(wt_of "$P")" 'an unregistered directory at the worktree path is no worktree'
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
assert_block "$(run_gate "$repo" dev-review-feature "$P")" "write feature, fix, or refactor" 'an unknown type blocks'
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
git -C "$repo" worktree add -q -b feat/gate "$wt" main
dated() { GIT_AUTHOR_DATE="@$1 +0000" GIT_COMMITTER_DATE="@$1 +0000" wt_commit "$wt" "$2" "$3"; }
dated 1700000001 'test(red): s1' tests/s1_test.py
dated 1700000002 'feat(s1): implement' src/s1.py
git -C "$wt" switch -q -c feat/fe feat/gate
dated 1700000003 'test(red): s2' tests/s2_test.py
git -C "$wt" switch -q feat/gate
dated 1700000004 'test(red): s1 repair' tests/s1_test.py
git -C "$wt" switch -q feat/fe
dated 1700000005 'feat(s2): implement' src/s2.py
git -C "$wt" switch -q feat/gate
dated 1700000006 'fix(s1): repair' src/s1.py
git -C "$wt" switch -q feat/fe
GIT_AUTHOR_DATE='@1700000007 +0000' GIT_COMMITTER_DATE='@1700000007 +0000' git -C "$wt" merge -q --no-edit feat/gate
write_plan "$BE" reviewed
write_plan "$FE" implemented "$(valid_graph)" feature '#12' 'Stacks On: pr1' feat/fe
assert_pass "$(run_gate "$repo" dev-review-code "$FE")" 'a parent repair merged forward into a shared worktree passes despite interleaved dates'

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
# A tree: $P has children $C2 and $C3, each in its own worktree, and $C2 has
# its only child $C4, which shares $C2's once its branch exists.
C2="$PD/12_gate/pr2.spec.md"
C3="$PD/12_gate/pr3.spec.md"
C4="$PD/12_gate/pr4.spec.md"
git -C "$repo" worktree add -q --detach "$(wt_of "$C2")" main
git -C "$repo" worktree add -q --detach "$(wt_of "$C3")" main
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
assert_block "$(run_gate "$repo" dev-create-pr "$P")" "Plan $C3 shares $P's worktree, but $P has other children" 'a sibling may not share its parent worktree'
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
git -C "$repo" branch -q -D feat/c4
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

printf 'All gate-check.sh tests passed. Temporary fixtures: %s\n' "$TMP_ROOT"
