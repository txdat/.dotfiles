#!/bin/bash
# dev-stack.sh against scratch repositories: the stack listing, check, review
# verdicts, and next, whose runnable actions must pass their gates.
set -euo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
STACK="$SCRIPT_DIR/dev-stack.sh"
GATE="$SCRIPT_DIR/gate-check.sh"
TEST_ROOT=$(mktemp -d /tmp/dev-stack-test.XXXXXX)
export AI_WORKTREES_ROOT="$TEST_ROOT/worktrees"
# Plans are ignored by each repository's own exclude, never the user's global one.
export GIT_CONFIG_GLOBAL=/dev/null XDG_CONFIG_HOME="$TEST_ROOT/xdg"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$*"; }

REPO="$TEST_ROOT/repo"
git init -q -b main "$REPO"
git -C "$REPO" config user.email dev-stack@example.test
git -C "$REPO" config user.name dev-stack-test.sh
printf 'seed\n' > "$REPO/README.md"
git -C "$REPO" add README.md && git -C "$REPO" commit -qm seed
printf '/docs/plans/\n' >> "$REPO/.git/info/exclude"
DIR="$REPO/docs/plans/12_stack"
mkdir -p "$DIR"

R="$DIR/pr1.spec.md"
C="$DIR/pr2.spec.md"
S="$DIR/pr3.spec.md"
G="$DIR/pr4.spec.md"
name_of() { case "$1" in "$R") echo root ;; "$C") echo child ;; "$S") echo sib ;; "$G") echo grand ;; *) basename "$1" ;; esac; }

# write_plan <plan> <status> <branch> [parent pr<K>]
write_plan() {
  {
    printf '# Stack test\nStatus: %s\nSpec: -\nTip: -\nType: feature\nBase: main\nBranch: %s\nIssue: #12\n' "$2" "$3"
    [[ -z "${4-}" ]] || printf 'Stacks On: %s\n' "$4"
    printf '\n## Goal\nA %s.\n\n' "$(basename "$1")"
    printf '## Acceptance Criteria\nAC-1 — outcome\n  Source: request\n  Success: yes\n  Failure: no\n\n'
    printf '## Test Cases\nTC-1 — scenario\n  Proves: AC-1\n  Fixture: f\n  Action: a\n  Expected: e\n\n'
    printf '## Implementation Steps\nST-1 — change — satisfies TC-1\n'
  } > "$1"  # A rewritten fixture is a new plan: it drops the old one's log lines.
  [[ ! -f "${1%/*}/log" ]] || sed -i "/^pr$(n=${1##*/pr}; printf '%s' "${n%.spec.md}"): /d" "${1%/*}/log"
}
# set_status <plan> <status> [tip]
set_status() { sed -i "s/^Status: .*/Status: $2/; s/^Tip: .*/Tip: ${3:--}/" "$1"; }
run() { (cd "$REPO" && bash "$STACK" "$@"); }
expect_fail() {
  local label="$1" want="$2" out code=0; shift 2
  out=$(run "$@" 2>&1) || code=$?
  [[ "$code" -ne 0 && "$out" == *"$want"* ]] || fail "$label: $code $out"
  pass "$label"
}

# next, checking that each runnable action passes its gate; prints
# "<plan> <action>" lines.
next() {
  local out plan status parent action reason
  out=$(run next "$R") || fail "next: $out"
  while IFS=$'\t' read -r plan status parent action reason; do
    case "$action" in
      review-feature|execute-feature|review-code|create-pr)
        [[ -z "$(jq -cn --arg s "dev-$action" --arg a "$plan" '{tool_input:{skill:$s,args:$a}}' | (cd "$REPO" && "$GATE"))" ]] ||
          fail "next offers $action for $plan, which its gate blocks" ;;
    esac
    printf '%s %s\n' "$(name_of "$plan")" "$action"
  done <<<"$out"
}
expect_next() { local got; got=$(next | paste -sd' ' -); [[ "$got" == "$1" ]] || fail "$2: got '$got'"; pass "$2"; }

# ── stack ──
write_plan "$R" planning feat/root
write_plan "$C" planning feat/child pr1
write_plan "$S" planning feat/sib pr1
write_plan "$G" planning feat/grand pr2
out=$(run stack "$R")
[[ "$out" == "$R"$'\n'"$C"$'\n'"$S"$'\n'"$G" ]] || fail "stack: $out"
pass 'stack lists the root, then every stacked plan, parents first'
out=$(HOME="$TEST_ROOT" run stack '~/repo/docs/plans/12_stack/pr1.spec.md')
[[ "$out" == "$R"$'\n'* ]] || fail "stack with ~: $out"
pass 'a plan path may start with ~'
WT="$AI_WORKTREES_ROOT/repo-12_stack-pr1"  # the root's own worktree
out=$(cd "$REPO" && git worktree add -q "$WT" -b feat/root main && cd "$WT" && bash "$STACK" stack "$R")
[[ "$(wc -l <<<"$out")" -eq 4 ]] || fail "stack from a worktree: $out"
pass 'stack reads the main root from inside a worktree'
expect_fail 'stack needs the root' "stacks on $R; pass the stack's root" stack "$C"
expect_fail 'a plan outside the layout is refused' 'Plan must be' stack "$REPO/README.md"
expect_fail "another repository's plan is refused" 'Plan must be' stack "$TEST_ROOT/other/docs/plans/12_stack/pr1.spec.md"
sed -i 's#^Stacks On: .*#- Stacks On: pr2#' "$G"
expect_fail 'stack fails on an unreadable Stacks On line' "Unreadable 'Stacks On:' lines in: $G" stack "$R"
write_plan "$G" planning feat/grand pr4
expect_fail 'a plan stacks only on a lower number' "Unreadable 'Stacks On:' lines in: $G" stack "$R"
write_plan "$G" planning feat/grand
expect_fail 'a directory holds one root' 'more than one plan without a' stack "$R"
write_plan "$G" planning feat/grand pr2

# ── check ──
out=$(run check "$R") || fail "check: $out"
[[ "$out" == "PASS $R"$'\n'"PASS $C"$'\n'"PASS $S"$'\n'"PASS $G" ]] || fail "check: $out"
pass 'check passes every plan in the stack before any parent is approved'
cp "$REPO/.git/info/exclude" "$TEST_ROOT/exclude"; : > "$REPO/.git/info/exclude"
expect_fail 'check refuses plans Git does not ignore' 'does not ignore docs/plans' check "$R"
cp "$TEST_ROOT/exclude" "$REPO/.git/info/exclude"
pass 'check refuses plans Git does not ignore'
sed -i 's/^  Proves: AC-1$/  Proves: AC-9/' "$S"
out=$(run check "$R" 2>&1) && fail "check passed a broken plan: $out"
[[ "$out" == *"BLOCK $S"$'\n'*"AC-9"* && "$out" == *"PASS $G"* ]] || fail "check block: $out"
pass 'check reports the block of each broken plan and checks the rest'
write_plan "$S" planning feat/sib pr1
run review "$R" ready >/dev/null; set_status "$R" approved
spec_r=$(sed -n 's/^Spec: //p' "$R")
sed -i 's/^  Proves: AC-1$/  Proves: AC-9/' "$C"
out=$(run check "$R" 2>&1) && fail "check passed a broken child of an approved root: $out"
[[ "$out" == "SKIP $R (approved)"$'\n'"BLOCK $C"$'\n'* ]] || fail "check under an approved root: $out"
pass 'check skips an approved plan and still checks the plans revised under it'
write_plan "$C" planning feat/child pr1
sed -i 's/^A pr1/An edited pr1/' "$R"
out=$(run check "$R" 2>&1) && fail "check passed an approved plan whose spec changed: $out"
[[ "$out" == "BLOCK $R"$'\n'"It is frozen: its spec, or a spec below it, changed since its approval at "* ]] || fail "check on a stale approval: $out"
grep -qx "pr1: approve approved at $spec_r" "$DIR/log" || fail "check did not record the user's approval: $(cat "$DIR/log")"
pass "check records the user's approval and blocks the approved plan once its spec changes"
run reopen "$R" >/dev/null
write_plan "$R" planning feat/root
sed -i 's#^Branch: .*#Branch: main#' "$R"
out=$(run check "$R" 2>&1) && fail "check passed a root whose Branch is its Base: $out"
[[ "$out" == "BLOCK $R"$'\n'*"Branch is its Base"* ]] || fail "check root branch: $out"
write_plan "$R" planning feat/root
sed -i 's#^Branch: .*#Branch: main#' "$S"
out=$(run check "$R" 2>&1) && fail "check passed a plan whose Branch is its Base: $out"
[[ "$out" == *"BLOCK $S"$'\n'*"Branch is its Base"* ]] || fail "check branch: $out"
pass 'check keeps the branch checks, on the root and on a stacked plan'
write_plan "$S" planning feat/sib pr1
expect_fail 'check needs the root' "stacks on $R; pass the stack's root" check "$C"
sed -i 's#^Stacks On: .*#- Stacks On: pr2#' "$G"
expect_fail 'check fails on an unreadable Stacks On line' "Unreadable 'Stacks On:' lines in: $G" check "$R"
write_plan "$G" planning feat/grand
expect_fail 'check fails on a second root' 'more than one plan without a' check "$R"
write_plan "$G" planning feat/grand pr2
set_status "$R" needs-changes; set_status "$C" ready
out=$(run check "$R") || fail "check on needs-changes and ready plans: $out"
pass 'check passes plans awaiting revision or approval'
set_status "$C" planning; set_status "$R" published
expect_fail 'check refuses a published stack' 'is published; no phase resumes it' check "$R"
out=$(cd "$REPO" && bash "$GATE" --design "$C" </dev/null)
[[ "$out" == *"is published, and a published plan never becomes a parent"* ]] || fail "design check under a published parent: $out"
pass 'a design check refuses a child of a published parent'
set_status "$R" planning
CRASH="$TEST_ROOT/crash-bin"
mkdir -p "$CRASH" && cp "$SCRIPT_DIR"/dev-stack.sh "$SCRIPT_DIR"/dev-plan-lib.sh "$SCRIPT_DIR"/dev-utils.sh "$CRASH"/
printf '#!/bin/bash\nexit 1\n' > "$CRASH/gate-check.sh"
out=$(cd "$REPO" && bash "$CRASH/dev-stack.sh" check "$R" 2>&1) && fail "check passed a crashing gate: $out"
[[ "$out" == "BLOCK $R"$'\n'"gate-check.sh failed without a verdict."* && "$out" == *"BLOCK $G"* ]] || fail "check with a crashing gate: $out"
pass 'a gate crash blocks each plan without stopping the check'
out=$(cd "$REPO" && bash "$GATE" --design '' </dev/null)
[[ "$out" == *'none was named'* ]] || fail "design check with no plan: $out"
pass 'a design check with no plan blocks'
[[ "$(jq -cn --arg a "$C" '{tool_input:{skill:"dev-review-feature",args:$a}}' | (cd "$REPO" && "$GATE"))" == *"needs it 'approved'"* ]] ||
  fail 'the review-feature hook let a child of an unapproved parent through'
pass 'the review-feature hook still needs an approved parent'

# ── next and review verdicts ──
expect_next 'root review-feature child wait-parent sib wait-parent grand wait-parent' 'only the root is reviewable at first'
expect_fail 'review needs a verdict' 'Usage' review "$R" maybe
lines=$(wc -l < "$R")
out=$(run review "$R" ready)
[[ "$out" == "Status: ready, Spec: "*" recorded in $R, review-feature round 1/3" ]] || fail "review: $out"
[[ "$(sed -n 2,8p "$R" | tr '\n' ' ')" =~ ^'Status: ready Spec: '[0-9a-f]{40}' Tip: - Type: feature Base: main Branch: feat/root Issue: #12 '$ ]] || fail "review fields: $(sed -n 2,8p "$R")"
[[ "$(wc -l < "$R")" -eq "$lines" ]] || fail 'review appended a line'
pass 'review sets Status and Spec in place'
expect_next 'root wait-user child wait-parent sib wait-parent grand wait-parent' 'a ready verdict waits for the user to approve'
sed -i 's/^A pr1/An edited pr1/' "$R"
expect_next 'root review-feature child wait-parent sib wait-parent grand wait-parent' 'a spec edit voids the review'
run review "$R" needs-changes >/dev/null
grep -qx 'Status: needs-changes' "$R" && grep -qE '^Spec: [0-9a-f]{40}$' "$R" || fail 'needs-changes fields'
expect_next 'root revise child wait-parent sib wait-parent grand wait-parent' 'needs-changes asks for a revision'
sed -i 's/^An edited pr1/A revised pr1/' "$R"
expect_next 'root review-feature child wait-parent sib wait-parent grand wait-parent' 'a revision after needs-changes returns to review-feature'
run review "$R" ready >/dev/null
spec=$(sed -n 's/^Spec: //p' "$R")
set_status "$R" approved
grep -qx "Spec: $spec" "$R" || fail 'approval changed the Spec hash'
expect_fail 'review records only for a planning plan' "a verdict records only before approval" review "$R" ready
expect_next 'root execute-feature child review-feature sib review-feature grand wait-parent' 'an approved root opens its children to review'
run review "$C" ready >/dev/null
sed -i '/^## Goal/a Revised contract.' "$R"
expect_next 'root blocked child review-feature sib review-feature grand wait-parent' 'a spec change voids the reviews of the plan and the plans above it'
set_status "$R" planning
expect_fail 'review refuses a plan returned to planning after approval' 'is frozen: it was approved at' review "$R" ready
[[ "$(run next "$R" | awk -F'\t' 'NR==1 { print $4 "|" $5 }')" == 'blocked|it was approved at '* ]] || fail 'next let a plan returned to planning through'
pass 'next blocks a plan returned to planning after approval'
run reopen "$R" >/dev/null
grep -qx 'Status: planning' "$R" || fail 'reopen kept the approval'
pass 'reopen returns an approved plan to planning'
run review "$R" ready >/dev/null; set_status "$R" approved
run review "$C" ready >/dev/null
set_status "$C" approved
expect_next 'root execute-feature child wait-parent sib review-feature grand review-feature' 'an approved child waits for its parent to be reviewed'

# ── approve: an agent's approval, as auto-approved ──
expect_fail 'approve needs a ready verdict' 'approve needs a ready plan whose review still holds' approve "$S"
run review "$S" ready >/dev/null
sed -i '/^## Goal/a Edited after review.' "$S"
expect_fail 'approve refuses a ready verdict the spec no longer matches' 'approve needs a ready plan whose review still holds' approve "$S"
write_plan "$S" planning feat/sib pr1
run review "$S" ready >/dev/null
run stop "$S" 'Failed fixes: 3/3 — test' >/dev/null
expect_fail 'approve refuses a stopped plan' 'is stopped' approve "$S"
run resume "$S" >/dev/null
spec=$(sed -n 's/^Spec: //p' "$S")
out=$(run approve "$S")
[[ "$out" == "Status: auto-approved recorded in $S" ]] || fail "approve: $out"
grep -qx 'Status: auto-approved' "$S" && grep -qx "Spec: $spec" "$S" || fail "approve fields: $(sed -n 2,3p "$S")"
pass 'approve sets Status: auto-approved and keeps the Spec hash'
expect_fail 'approve records only from ready' 'approve needs a ready plan whose review still holds' approve "$S"
[[ "$(jq -cn --arg a "$S" '{tool_input:{skill:"dev-review-feature",args:$a}}' | (cd "$REPO" && "$GATE"))" == *'already auto-approved'* ]] ||
  fail 'review-feature ran on an auto-approved plan'
pass 'review-feature refuses an auto-approved plan'
expect_next 'root execute-feature child wait-parent sib wait-parent grand review-feature' 'an auto-approved child waits for its parent to be reviewed'
set_status "$R" auto-approved; set_status "$C" ready
run review "$G" ready >/dev/null
expect_fail 'approve needs the parent approved' "$C must be approved or auto-approved first" approve "$G"
set_status "$C" auto-approved
expect_next 'root execute-feature child wait-parent sib wait-parent grand wait-user' 'an auto-approved plan runs execute-feature and opens its children to review'
[[ -z "$(jq -cn --arg a "$G" '{tool_input:{skill:"dev-review-feature",args:$a}}' | (cd "$REPO" && "$GATE"))" ]] ||
  fail 'the review-feature gate refused a child of an auto-approved parent'
pass 'the review-feature gate accepts a child of an auto-approved parent'
out=$(run next "$R" --md | sed -n 3p)
[[ "$out" == '| pr1 | 🔷 auto-approved | - | ▶ execute-feature | - |' ]] || fail "md auto-approved row: $out"
pass 'next marks auto-approved with its own dot'
out=$(run check "$R") || fail "check under auto-approved plans: $out"
[[ "$(sed -n 1p <<<"$out")" == "SKIP $R (auto-approved)" ]] || fail "check auto-approved: $out"
pass 'check skips an auto-approved plan whose review holds'
for pair in 'dev-review-code|not yet implemented' 'dev-create-pr|not yet executed'; do
  [[ "$(jq -cn --arg s "${pair%%|*}" --arg a "$R" '{tool_input:{skill:$s,args:$a}}' | (cd "$REPO" && "$GATE"))" == *"${pair#*|}"* ]] ||
    fail "${pair%%|*} ran on an auto-approved plan"
done
pass 'review-code and create-pr refuse an auto-approved plan'
sed -i '/^## Goal/a Stale edit.' "$R"
[[ "$(run next "$R" | awk -F'\t' 'NR==1 { print $4 }')" == blocked ]] || fail 'an auto-approved plan with a changed spec was not blocked'
pass 'an auto-approved plan whose spec changed is blocked'
sed -i '/^Stale edit\.$/d' "$R"
expect_fail 'approve takes one plan' 'Usage' approve "$G" extra
set_status "$G" published
expect_fail 'approve refuses a published plan' 'is published; no phase resumes it' approve "$G"
write_plan "$G" planning feat/grand pr2
run review "$G" ready >/dev/null; set_status "$G" planning
expect_fail 'approve refuses a plan returned to planning with a ready Spec' 'approve needs a ready plan whose review still holds' approve "$G"
[[ "$(run next "$R" | awk -F'\t' -v g="$G" '$1 == g { print $4 }')" == revise ]] || fail 'a plan returned to planning with a ready Spec was not sent to revise'
pass 'a plan returned to planning goes to revise, not wait-user'
run review "$G" needs-changes >/dev/null
expect_fail 'approve refuses a needs-changes verdict' 'approve needs a ready plan whose review still holds' approve "$G"
[[ -z "$(jq -cn --arg p "/dev-autopilot $R answers" '{hook_event_name:"UserPromptSubmit",prompt:$p}' | (cd "$REPO" && "$GATE"))" ]] ||
  fail 'the gate checked a /dev-autopilot prompt'
pass 'a /dev-autopilot prompt naming a plan is not gated'
set_status "$R" approved; set_status "$C" approved
write_plan "$S" planning feat/sib pr1; write_plan "$G" planning feat/grand pr2

out=$(run next "$R" --md)
[[ "$(sed -n 1,2p <<<"$out")" == $'| plan | status | parent | action | reason |\n|---|---|---|---|---|' ]] || fail "md header: $out"
[[ "$(sed -n 3p <<<"$out")" == '| pr1 | 🔵 approved | - | ▶ execute-feature | - |' ]] || fail "md row: $out"
[[ "$(sed -n 4p <<<"$out")" == '| pr2 | 🔵 approved | pr1 | ⏳ wait-parent | pr1 must be reviewed first |' ]] || fail "md child row: $out"
[[ "$(wc -l <<<"$out")" -eq 6 ]] || fail "md rows: $out"
expect_fail 'next takes only --tab, --tree, or --md as an option' 'Usage' next "$R" --json
[[ "$(run next "$R" --tab)" == "$(run next "$R")" ]] || fail 'next --tab differs from the default rows'
pass 'next --tab prints the default tab-separated rows'
pass 'next --md prints a Markdown table with a dot per status and a mark per action'
out=$(run next "$R" --tree)
want='pr1 🔵 approved  ▶ execute-feature
├─ pr2 🔵 approved  ⏳ wait-parent — pr1 must be reviewed first
│  └─ pr4 ⚪ planning  ▶ review-feature
└─ pr3 ⚪ planning  ▶ review-feature'
[[ "$out" == "$want" ]] || fail "tree: $out"
pass 'next --tree draws the stack with a dot per status and a mark per action'

# ── runnable actions are the gate's ──
set_status "$R" implemented
out=$(run next "$R" | awk -F'\t' 'NR==1 { print $4 "|" $5 }')
[[ "$out" == "blocked|review-code: Found no 'test(red):' commit between main and feat/root "* ]] || fail "gate reason: $out"
[[ "$(run next "$R" --md | sed -n 3p)" == *"| ⛔ blocked | review-code: Found no 'test(red):' commit"* ]] || fail 'md gate reason'

pass "next reports the gate's reason when it blocks a phase"
seed=$(git -C "$REPO" rev-parse HEAD)
for p in "$R" "$C" "$S"; do set_status "$p" reviewed "$seed"; done
expect_next 'root done child done sib done grand review-feature' 'the root waits until every plan is reviewed'
set_status "$R" implemented
expect_next 'root blocked child blocked sib blocked grand review-feature' 'a reviewed child of a parent back in implementation is blocked'
git -C "$REPO" commit -q --allow-empty -m 'fix: root repair'
set_status "$R" reviewed "$(git -C "$REPO" rev-parse HEAD)"
[[ "$(run next "$R" | awk -F'\t' -v p="$C" '$1 == p { print $4 "|" $5 }')" == "blocked|its reviewed SHA does not contain $R's"* ]] || fail 'stale child review'
pass "a child reviewed before its parent's repair is blocked"
for p in "$C" "$S" "$G"; do set_status "$p" reviewed "$(git -C "$REPO" rev-parse HEAD)"; done
[[ "$(run next "$R" | awk -F'\t' 'NR==1 { print $4 "|" $5 }')" == 'blocked|create-pr: '* ]] || fail 'create-pr gate'
pass 'a fully reviewed stack offers create-pr on the root, through its gate'
set_status "$G" bogus
[[ "$(run next "$R" | awk -F'\t' -v p="$G" '$1 == p { print $4 "|" $5 }')" == "blocked|unknown status 'bogus'" ]] || fail 'unknown status'
pass 'an unknown status blocks'
set_status "$G" published
[[ "$(run next "$R" | grep -c .)" -eq 3 ]] || fail 'a published plan is listed'
expect_fail 'a published plan takes no command' 'is published' review "$G" ready
pass 'a published plan leaves the stack and takes no command'
for p in "$R" "$C" "$S"; do set_status "$p" published; done
expect_next 'root done child done sib done grand done' 'a published stack lists every plan, done'
out=$(run next "$R" | awk -F'\t' '{ print $2 }' | sort -u)
[[ "$out" == published ]] || fail "a published stack shows each plan published: $out"
out=$(run next "$R" --tree)
want=$'pr1 🟣 published  ✅ done\n├─ pr2 🟣 published  ✅ done\n│  └─ pr4 🟣 published  ✅ done\n└─ pr3 🟣 published  ✅ done'
[[ "$out" == "$want" ]] || fail "published stack tree: $out"
[[ "$(run stack "$R" | grep -c .)" -eq 4 ]] || fail 'stack on a published stack lists every plan'
[[ "$(run next "$R" --md | sed -n 3p)" == '| pr1 | 🟣 published | - | ✅ done | - |' ]] || fail 'published stack md'
expect_fail 'a published root refuses stop' 'is published' stop "$R" why
expect_fail 'a published root refuses review' 'is published' review "$R" ready
expect_fail 'a published root refuses resume' 'is published' resume "$R"
expect_fail 'a published root refuses check' 'is published' check "$R"
out=$(INCLUDE_PUBLISHED=1 run next "$C" --tree 2>&1) && fail "next --tree on a non-root exits 0: $out"
[[ "$out" == *"pass the stack's root"* && "$out" != *blocked* ]] || fail "next --tree on a non-root: $out"
pass 'next --tree fails on a non-root, ignoring an inherited INCLUDE_PUBLISHED'
pass 'a published stack prints its tree'
for p in "$R" "$C" "$S"; do set_status "$p" reviewed "$(git -C "$REPO" rev-parse HEAD)"; done
write_plan "$G" planning feat/grand pr2

# ── run stops ──
write_plan "$S" planning feat/sib pr1
reason_of() { run next "$R" | awk -F'\t' -v p="$1" '$1 == p { print $4 "|" $5 }'; }
expect_fail 'a stop reason is one line' 'one nonempty line' stop "$S" $'a\tb'
run stop "$S" 'review round limit; Failed fixes: 2/3 — x' >/dev/null
[[ "$(reason_of "$S")" == 'stopped|review round limit; Failed fixes: 2/3 — x' ]] || fail "stop: $(reason_of "$S")"
pass 'next shows a stopped plan with its reason'
expect_fail 'review refuses a stopped plan' 'is stopped: review round limit' review "$S" ready
[[ "$(reason_of "$S")" == stopped* ]] || fail 'a refused verdict cleared the stop'
sed -i '/^## Goal/a Revised scope.' "$S"
[[ "$(reason_of "$S")" == review-feature* ]] || fail "spec edit: $(reason_of "$S")"
pass 'a spec edit clears a stop'
run stop "$S" 'needs a decision' >/dev/null
set_status "$S" approved
[[ "$(reason_of "$S")" != stopped* ]] || fail 'a status change kept the stop'
pass 'a status change clears a stop'
set_status "$S" planning
run stop "$S" 'needs a decision' >/dev/null
run resume "$S" >/dev/null
[[ "$(reason_of "$S")" != stopped* ]] || fail 'resume kept the stop'
pass 'resume clears a stop'
run review "$S" ready >/dev/null; run stop "$S" x >/dev/null; run resume "$S" >/dev/null
[[ "$(reason_of "$S")" == wait-user* ]] || fail "a stop voided the review: $(reason_of "$S")"
pass 'a stop does not void a plan review'
git -C "$WT" switch -q -c feat/sib
run stop "$S" 'three failed fixes' >/dev/null
[[ "$(reason_of "$S")" == stopped* ]] || fail 'branch stop'
git -C "$WT" switch -q feat/root
git -C "$WT" commit -q --allow-empty -m 'fix: the parent'
[[ "$(reason_of "$S")" == stopped* ]] || fail 'switching the worktree or committing to another branch cleared the stop'
pass "a worktree's branch switches and other branches' commits keep a stop"
git -C "$WT" switch -q feat/sib
git -C "$WT" commit -q --allow-empty -m 'fix: by hand'
[[ "$(reason_of "$S")" != stopped* ]] || fail "a new commit on the plan's branch kept the stop"
pass "a new commit on the plan's branch clears a stop"
run stop "$S" 'Failed fixes: 3/3 — TC-1 fails' >/dev/null
git -C "$WT" commit -q --allow-empty -m 'fix: another try'
sed -i '/^## Goal/a Narrowed scope.' "$S"
[[ "$(reason_of "$S")" == 'stopped|Failed fixes: 3/3 — TC-1 fails' ]] || fail "three failed fixes: $(reason_of "$S")"
run resume "$S" >/dev/null
[[ "$(reason_of "$S")" != stopped* ]] || fail 'resume kept three failed fixes'
pass 'three failed fixes hold through changes until resume'
run stop "$S" 'Failed fixes: 1/3 — a; Failed fixes: 3/3 — b' >/dev/null
run stop "$S" 'needs repair' >/dev/null
git -C "$WT" commit -q --allow-empty -m 'fix: one more'
[[ "$(reason_of "$S")" == 'stopped|Failed fixes: 1/3 — a; Failed fixes: 3/3 — b' ]] || fail "a later stop released three failed fixes: $(reason_of "$S")"
run resume "$S" >/dev/null
run stop "$S" 'Failed fixes: 3/30 — below its limit' >/dev/null
git -C "$WT" commit -q --allow-empty -m 'fix: and another'
[[ "$(reason_of "$S")" != stopped* ]] || fail 'a count below its limit held'
pass 'three failed fixes hold through later stops, read from every count'
run stop "$S" 'Failed fixes: 4/6 — after a grant' >/dev/null
git -C "$WT" commit -q --allow-empty -m 'fix: under the raised limit'
[[ "$(reason_of "$S")" != stopped* ]] || fail 'a count below its raised limit held'
run stop "$S" 'Failed fixes: 6/6 — at the raised limit' >/dev/null
git -C "$WT" commit -q --allow-empty -m 'fix: past it'
[[ "$(reason_of "$S")" == 'stopped|Failed fixes: 6/6 — at the raised limit' ]] || fail "a count at its raised limit did not hold: $(reason_of "$S")"
run resume "$S" >/dev/null
pass 'failed fixes hold at their limit, which a grant raises'
[[ "$(run next "$R" --md | grep -c '^| ')" -ge 5 ]] || fail 'md after stops'

# ── records and failures ──
write_plan "$S" planning feat/sib pr1
run review "$S" ready >/dev/null
sed -i 's/^Spec: .*/Spec: nothex/' "$S"
[[ "$(run next "$R" | awk -F'\t' -v p="$S" '$1 == p { print $4 }')" == review-feature ]] || fail 'malformed Spec'
pass 'a malformed Spec hash does not count as a verdict'
write_plan "$S" planning feat/sib pr1
sed -i '/^Spec: -$/d; /^Tip: -$/d' "$S"
run review "$S" ready >/dev/null
[[ "$(sed -n 2,4p "$S" | tr '\n' ' ')" =~ ^'Status: ready Spec: '[0-9a-f]{40}' Type: feature '$ ]] || fail "missing Spec: $(sed -n 2,4p "$S")"
[[ "$(run next "$R" | awk -F'\t' -v p="$S" '$1 == p { print $4 }')" == wait-user ]] || fail 'added Spec is not current'
pass 'review adds a missing Spec field after Status'
X="$DIR/pr7.spec.md"
write_plan "$X" planning feat/x pr6
expect_fail 'stop needs a hash' 'Cannot hash' stop "$X" x
grep -qs '^pr7: stop' "$DIR/log" && fail 'a failed stop wrote a record'
pass 'a failed stop writes no record'
expect_fail 'review fails when a plan below is missing' 'Cannot hash' review "$X" ready
grep -qx 'Status: planning' "$X" || fail 'review changed Status after a hash failure'
pass 'review writes nothing when the hash fails'
expect_fail 'next fails on a stack it cannot read' 'Unreadable' next "$R"

# ── views of a second stack: multi-line reasons and number order ──
E="$REPO/docs/plans/12_extra"
mkdir -p "$E"; write_plan "$E/pr1.spec.md" planning feat/e1
write_plan "$E/pr2.spec.md" planning feat/e2 pr1
write_plan "$E/pr10.spec.md" planning feat/e10 pr1
printf 'ST-2 — orphan\n' >> "$E/pr1.spec.md"
out=$(run next "$E/pr1.spec.md" --tree)
[[ "$(wc -l <<<"$out")" -eq 3 && "$(sed -n 1p <<<"$out")" == *'is not closed'*'ST-2 has no satisfies clause'* ]] || fail "multi-line reason in tree: $out"
[[ "$(sed -n 2,3p <<<"$out" | awk '{ print $1, $2 }')" == $'├─ pr2\n└─ pr10' ]] || fail "children out of number order: $out"
[[ "$(run next "$E/pr1.spec.md" --md | wc -l)" -eq 5 ]] || fail 'multi-line reason in md'
[[ "$(run next "$E/pr1.spec.md" | wc -l)" -eq 3 ]] || fail 'multi-line reason in tsv'
pass 'a multi-line gate reason stays on its plan line, and children list by number'
expect_fail 'next takes one view option' 'Usage' next "$E/pr1.spec.md" --md --tree

# ── which lines the review hash ignores ──
state_of() { (cd "$REPO" && REPO_ROOT="$REPO" && . "$SCRIPT_DIR/dev-plan-lib.sh" && review_state "$1"); }
H="$E/pr1.spec.md"
write_plan "$H" planning feat/e1
run review "$H" ready >/dev/null
set_status "$H" reviewed "$(printf '%040d' 0)"
[[ "$(state_of "$H")" == ready ]] || fail "a Status or Tip change voided the review: $(state_of "$H")"
printf 'Note: added later\n' >> "$H"
[[ "$(state_of "$H")" == stale ]] || fail 'a line added after approval was ignored'
pass 'the review hash ignores only the Status, Spec, and Tip values'

# ── the stack log: review rounds, approvals, and code-review rounds ──
L="$REPO/docs/plans/12_log"; mkdir -p "$L"
L1="$L/pr1.spec.md"; write_plan "$L1" planning feat/l1
row_of() { run next "$1" | awk -F'\t' 'NR == 1 { print $4 "|" $5 }'; }
out=$(run review "$L1" needs-changes)
[[ "$out" == *', review-feature round 1/3' ]] || fail "round 1: $out"
[[ "$(row_of "$L1")" == 'revise|review-feature needs-changes (1/3); revise it'* ]] || fail "revise reason: $(row_of "$L1")"
sed -i '/^## Goal/a Revision one.' "$L1"
[[ "$(row_of "$L1")" == 'review-feature|round 2/3' ]] || fail "next round: $(row_of "$L1")"
pass 'review logs its round and next shows it'
run review "$L1" needs-changes >/dev/null
sed -i '/^## Goal/a Revision two.' "$L1"
out=$(run review "$L1" needs-changes)
[[ "$out" == *'round 3/3'*'Stopped: review-feature round limit (3/3)'* ]] || fail "round limit: $out"
grep -qE '^pr1: review needs-changes \(3/3\) at [0-9a-f]{40}$' "$L/log" && grep -qE '^pr1: stop review-feature round limit \(3/3\) at [0-9a-f]{40}$' "$L/log" || fail "log lines: $(cat "$L/log")"
sed -i '/^## Goal/a Revision three.' "$L1"
[[ "$(row_of "$L1")" == 'stopped|review-feature round limit (3/3)' ]] || fail "a revision released the round limit: $(row_of "$L1")"
expect_fail 'review refuses a plan at its round limit' 'is stopped: review-feature round limit (3/3)' review "$L1" ready
pass 'needs-changes on the last round stops the plan, through revisions'
run resume "$L1" >/dev/null
[[ "$(row_of "$L1")" == 'review-feature|round 4/6' ]] || fail "resume budget: $(row_of "$L1")"
out=$(run review "$L1" ready)
[[ "$out" == *'round 4/6' ]] || fail "round 4: $out"
pass "the user's resume at the limit grants three more rounds"
spec=$(sed -n 's/^Spec: //p' "$L1")
run approve "$L1" >/dev/null
grep -qx "pr1: approve auto-approved at $spec" "$L/log" || fail "approve line: $(tail -1 "$L/log")"
pass 'approve logs the spec hash it approved'
expect_fail 'code-review needs an implemented plan' 'review-code verdicts record on an implemented plan' code-review "$L1" pass
set_status "$L1" implemented
expect_fail 'code-review needs a verdict' 'Usage' code-review "$L1" maybe
run code-review "$L1" needs-changes >/dev/null; run code-review "$L1" needs-changes >/dev/null
out=$(run code-review "$L1" needs-changes)
[[ "$out" == *'round 3/3'*'Stopped: review-code round limit (3/3)'* ]] || fail "code-review limit: $out"
[[ "$(row_of "$L1")" == 'stopped|review-code round limit (3/3)' ]] || fail "code-review stop: $(row_of "$L1")"
run resume "$L1" >/dev/null
[[ "$(run code-review "$L1" pass)" == *'round 4/6' ]] || fail 'code-review resume budget'
[[ "$(run code-review "$L1" needs-changes)" == *'round 1/3' ]] || fail 'a pass did not end the review-code phase'
pass 'code-review counts rounds per review phase and stops at its limit'


# ── reopen ──
Q="$REPO/docs/plans/12_reopen"; mkdir -p "$Q"
Q1="$Q/pr1.spec.md"; Q2="$Q/pr2.spec.md"; Q3="$Q/pr3.spec.md"
write_plan "$Q1" planning feat/q1; write_plan "$Q2" planning feat/q2 pr1; write_plan "$Q3" planning feat/q3 pr1
run review "$Q1" ready >/dev/null; run approve "$Q1" >/dev/null
run review "$Q2" ready >/dev/null; set_status "$Q2" approved
expect_fail 'reopen needs an approved plan' "reopen takes a plan approved or later" reopen "$Q3"
run stop "$Q1" 'Failed fixes: 3/3 — tests' >/dev/null
[[ "$(row_of "$Q1")" == stopped* ]] || fail "held stop: $(row_of "$Q1")"
sed -i 's/^Tip: .*/Tip: 1234567/' "$Q1" "$Q2"
out=$(run reopen "$Q1")
[[ "$out" == "Reopened to planning: $Q1 $Q2" ]] || fail "reopen: $out"
grep -qx 'Status: planning' "$Q1" && grep -qx 'Status: planning' "$Q2" && grep -qx 'Status: planning' "$Q3" || fail 'reopen statuses'
grep -qx 'Tip: -' "$Q1" && grep -qx 'Tip: -' "$Q2" || fail 'reopen kept a Tip'
[[ "$(row_of "$Q1")" == revise* ]] || fail "a reopened plan with its spec unchanged is not sent to revise: $(row_of "$Q1")"
sed -i '/^## Goal/a Reopened change.' "$Q1"
[[ "$(row_of "$Q1")" == review-feature* ]] || fail "a reopened plan is still frozen or stopped: $(row_of "$Q1")"
[[ "$(run review "$Q1" needs-changes)" == *'review-feature round 1/3' ]] || fail 'reopen kept the review round count'
pass 'reopen returns a plan and every approved plan above it to planning, lifts the freeze and its stops, and restarts the round count'

# ── auto-reopen ──
A="$REPO/docs/plans/12_auto"; mkdir -p "$A"
A1="$A/pr1.spec.md"; A2="$A/pr2.spec.md"; A3="$A/pr3.spec.md"
write_plan "$A1" planning feat/a1; write_plan "$A2" planning feat/a2 pr1; write_plan "$A3" planning feat/a3 pr2
run review "$A1" ready >/dev/null; run approve "$A1" >/dev/null
run review "$A2" ready >/dev/null; set_status "$A2" approved; run next "$A1" >/dev/null
expect_fail 'auto-reopen needs an approved plan' "auto-reopen takes a plan approved or later" auto-reopen "$A3"
expect_fail "auto-reopen never takes the user's approval" "carries the user's approval" auto-reopen "$A2"
expect_fail "auto-reopen never reopens a user-approved plan above" "$A2 carries the user's approval" auto-reopen "$A1"
grep -qx 'Status: auto-approved' "$A1" || fail 'a refused auto-reopen changed the plan'
write_plan "$A2" planning feat/a2 pr1; run review "$A2" ready >/dev/null; run approve "$A2" >/dev/null
run stop "$A2" 'Failed fixes: 3/3 — tests' >/dev/null
expect_fail 'auto-reopen never passes a held stop' 'Only the user clears it' auto-reopen "$A1"
run resume "$A2" >/dev/null
set_status "$A1" implemented; run stop "$A1" 'PC-1 failed' >/dev/null
out=$(run auto-reopen "$A1")
[[ "$out" == "Auto-reopened to planning: $A1 $A2" ]] || fail "auto-reopen: $out"
grep -qx 'Status: planning' "$A1" && grep -qx 'Status: planning' "$A2" && grep -qx 'Status: planning' "$A3" || fail 'auto-reopen statuses'
sed -i '/^## Goal/a Revised change.' "$A1"
[[ "$(row_of "$A1")" == review-feature* ]] || fail "an auto-reopened plan is still frozen or stopped: $(row_of "$A1")"
[[ "$(run review "$A1" ready)" == *'review-feature round 1/3' ]] || fail 'auto-reopen kept the review round count'
run approve "$A1" >/dev/null
expect_fail 'auto-reopen runs once per plan' 'was auto-reopened once' auto-reopen "$A1"
run reopen "$A1" >/dev/null
grep -qx 'Status: planning' "$A1" || fail "the user's reopen after an auto-reopen"
expect_fail 'an auto-reopened plan is never dropped' 'was auto-reopened' drop "$A1"
U="$REPO/docs/plans/12_auto-user"; mkdir -p "$U"; U1="$U/pr1.spec.md"
write_plan "$U1" planning feat/u1; run review "$U1" ready >/dev/null; run approve "$U1" >/dev/null
set_status "$U1" approved; run next "$U1" >/dev/null
expect_fail "auto-reopen never takes the user's approval over its own" "carries the user's approval" auto-reopen "$U1"
set_status "$U1" implemented
expect_fail "the user's approval over its own outlives execution" "carries the user's approval" auto-reopen "$U1"
pass "auto-reopen reopens only autopilot's own approvals, once per plan, never past a held stop"

# ── renumber and drop ──
K="$REPO/docs/plans/12_shape"; mkdir -p "$K"
write_plan "$K/pr1.spec.md" planning feat/k1; write_plan "$K/pr2.spec.md" planning feat/k2 pr1; write_plan "$K/pr3.spec.md" planning feat/k3 pr2
run review "$K/pr1.spec.md" ready >/dev/null; run approve "$K/pr1.spec.md" >/dev/null
run review "$K/pr2.spec.md" needs-changes >/dev/null
out=$(run renumber "$K/pr1.spec.md" 3=4 2=3)
[[ -f "$K/pr3.spec.md" && -f "$K/pr4.spec.md" && ! -e "$K/pr2.spec.md" ]] || fail "renumber files: $(ls "$K")"
grep -qx 'Stacks On: pr1' "$K/pr3.spec.md" && grep -qx 'Stacks On: pr3' "$K/pr4.spec.md" || fail 'renumber Stacks On'
grep -q '^pr3: review needs-changes (1/3)' "$K/log" && ! grep -q '^pr2:' "$K/log" || fail "renumber log: $(cat "$K/log")"
pass 'renumber renames plans and rewrites their Stacks On and log lines at once'
expect_fail 'renumber refuses an approved plan' 'only an unapproved plan' renumber "$K/pr1.spec.md" 1=2
expect_fail 'renumber refuses a taken number' 'pr4 exists and is not renumbered' renumber "$K/pr1.spec.md" 3=4
expect_fail 'renumber keeps parents below children' 'a parent'"'"'s number is below its children'"'"'s' renumber "$K/pr1.spec.md" 3=9
expect_fail 'renumber takes <old>=<new>' 'Usage' renumber "$K/pr1.spec.md" 3:5
git -C "$REPO" branch feat/k3
expect_fail 'renumber refuses an executed plan' 'Branch feat/k3 exists' renumber "$K/pr1.spec.md" 4=5
git -C "$REPO" branch -D -q feat/k3
run stop "$K/pr3.spec.md" 'Failed fixes: 3/3 — x' >/dev/null
expect_fail 'drop refuses a stopped plan' 'is stopped: Failed fixes: 3/3' drop "$K/pr3.spec.md"
expect_fail 'renumber refuses a stopped plan' 'is stopped' renumber "$K/pr1.spec.md" 3=5 4=6
run resume "$K/pr3.spec.md" >/dev/null
out=$(run drop "$K/pr3.spec.md")
[[ ! -e "$K/pr3.spec.md" ]] && grep -qx 'Stacks On: pr1' "$K/pr4.spec.md" || fail "drop: $out"
grep -q '^dropped pr3: review' "$K/log" && ! grep -q '^pr3:' "$K/log" || fail "drop log: $(cat "$K/log")"
pass 'drop deletes a plan, restacks its children on its parent, and retires its log lines'
expect_fail 'drop refuses an approved plan' 'only an unapproved plan' drop "$K/pr1.spec.md"
D="$REPO/docs/plans/12_droproot"; mkdir -p "$D"
write_plan "$D/pr1.spec.md" planning feat/d1; write_plan "$D/pr2.spec.md" planning feat/d2 pr1; write_plan "$D/pr3.spec.md" planning feat/d3 pr1
out=$(run drop "$D/pr1.spec.md")
[[ "$out" == *"; $D/pr2.spec.md is the root" ]] && ! grep -q '^Stacks On:' "$D/pr2.spec.md" && grep -qx 'Stacks On: pr2' "$D/pr3.spec.md" || fail "drop root: $out"
[[ "$(run stack "$D/pr2.spec.md" | wc -l)" -eq 2 ]] || fail 'the new root does not lead the stack'
pass "dropping the root makes its lowest-numbered child the root"

# ── header fields ──
lib() { (cd "$REPO" && REPO_ROOT="$REPO" && . "$SCRIPT_DIR/dev-plan-lib.sh" && "$@"); }
F="$E/pr3.spec.md"
printf '# Fields\nStatus: planning\nTipping: x\nSpec: old\nSpec: dup\n```\nTip: fenced\n```\n\n## Goal\nTip: body\n' > "$F"
[[ "$(lib field "$F" Tip)" == "" && "$(lib field "$F" Spec)" == old ]] || fail 'field read a prefix, fenced, body, or later duplicate line'
lib set_header "$F" Status ready Spec new Tip t1 || fail 'set_header'
want=$'# Fields\nStatus: ready\nTip: t1\nTipping: x\nSpec: new\nSpec: dup\n```\nTip: fenced\n```\n\n## Goal\nTip: body'
[[ "$(cat "$F")" == "$want" ]] || fail "set_header: $(cat "$F")"
printf '# Fields\nStatus: planning\nType: fix\n' > "$F"
lib set_header "$F" Spec abc || fail 'set_header without Status'
[[ "$(cat "$F")" == $'# Fields\nStatus: planning\nSpec: abc\nType: fix' ]] || fail "missing key without Status in the call: $(cat "$F")"
printf '# Fields\nType: fix\n' > "$F"
lib set_header "$F" Status x && fail 'set_header wrote a plan without Status'
[[ "$(cat "$F")" == $'# Fields\nType: fix' && -z "$(ls "$E" | grep -v -e '\.spec\.md$' -e '^log$')" ]] || fail 'a failed set_header left changes or a temporary file'
rm "$F"
pass 'set_header replaces the first header line of each key, adds missing keys after Status, and skips prefixes, fences, and the body'

printf 'All dev-stack.sh tests passed. Temporary fixtures: %s\n' "$TEST_ROOT"
