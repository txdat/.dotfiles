#!/usr/bin/env bash
# dev-stack.sh against scratch repositories: the stack listing, plan review
# records, and next, whose runnable actions must pass their gates.
set -euo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
STACK="$SCRIPT_DIR/dev-stack.sh"
GATE="$SCRIPT_DIR/gate-check.sh"
TEST_ROOT=$(mktemp -d /tmp/dev-stack-test.XXXXXX)
export AI_PLANS_ROOT="$TEST_ROOT/plans"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$*"; }

REPO="$TEST_ROOT/repo"
git init -q -b main "$REPO"
git -C "$REPO" config user.email dev-stack@example.test
git -C "$REPO" config user.name dev-stack-test.sh
printf 'seed\n' > "$REPO/README.md"
git -C "$REPO" add README.md && git -C "$REPO" commit -qm seed
DIR="$AI_PLANS_ROOT/repo/12_stack"
mkdir -p "$DIR"

R="$DIR/pr1.spec.md"
C="$DIR/pr2.spec.md"
S="$DIR/pr3.spec.md"
G="$DIR/pr4.spec.md"
name_of() { case "$1" in "$R") echo root ;; "$C") echo child ;; "$S") echo sib ;; "$G") echo grand ;; *) basename "$1" ;; esac; }

# write_plan <plan> <status> <branch> [parent pr<K>]
write_plan() {
  {
    printf '# Stack test\nStatus: %s | Type: feature | Base: main | Branch: %s | Issue: #12 | Worktree:\n' "$2" "$3"
    [[ -z "${4-}" ]] || printf 'Stacks On: %s\n' "$4"
    printf '\n## Goal\nA %s.\n\n' "$(basename "$1")"
    printf '## Acceptance Criteria\nAC-1 — outcome\n  Source: request\n  Success: yes\n  Failure: no\n\n'
    printf '## Test Cases\nTC-1 — scenario\n  Proves: AC-1\n  Fixture: f\n  Action: a\n  Expected: e\n  Test: t::n — filled by execute-feature\n\n'
    printf '## Implementation Steps\nST-1 — change — satisfies TC-1\n'
  } > "$1"
}
set_status() { sed -i "s/^Status: [a-z]*/Status: $2/" "$1"; }
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
out=$(HOME="$TEST_ROOT" run stack '~/plans/repo/12_stack/pr1.spec.md')
[[ "$out" == "$R"$'\n'* ]] || fail "stack with ~: $out"
pass 'a plan path may start with ~'
out=$(cd "$REPO" && git worktree add -q "$TEST_ROOT/wt" -b feat/root main && cd "$TEST_ROOT/wt" && bash "$STACK" stack "$R")
[[ "$(wc -l <<<"$out")" -eq 4 ]] || fail "stack from a worktree: $out"
pass 'stack reads the main root from inside a worktree'
expect_fail 'stack needs the root' "stacks on $R; pass the stack's root" stack "$C"
expect_fail 'a plan outside the layout is refused' 'Plan must be' stack "$REPO/README.md"
expect_fail "another repository's plan is refused" 'Plan must be' stack "$AI_PLANS_ROOT/other/12_stack/pr1.spec.md"
sed -i 's#^Stacks On: .*#- Stacks On: pr2#' "$G"
expect_fail 'stack fails on an unreadable Stacks On line' "Unreadable 'Stacks On:' lines in: $G" stack "$R"
write_plan "$G" planning feat/grand pr4
expect_fail 'a plan stacks only on a lower number' "Unreadable 'Stacks On:' lines in: $G" stack "$R"
write_plan "$G" planning feat/grand
expect_fail 'a directory holds one root' 'more than one plan without a' stack "$R"
write_plan "$G" planning feat/grand pr2

# ── next and plan review records ──
expect_next 'root review-feature child wait-parent sib wait-parent grand wait-parent' 'only the root is reviewable at first'
expect_fail 'review needs a verdict' 'Usage' review "$R" maybe
out=$(run review "$R" ready)
[[ "$out" == "Plan review: READY recorded in $R" ]] || fail "review: $out"
grep -qE '^Plan review: READY at [0-9a-f]{40}$' "$R" || fail 'review record'
expect_next 'root wait-user child wait-parent sib wait-parent grand wait-parent' 'a READY record waits for the user to approve'
printf -- '- Green: %s\n' "$(git -C "$REPO" rev-parse HEAD)" >> "$R"
expect_next 'root wait-user child wait-parent sib wait-parent grand wait-parent' 'records do not void a review'
sed -i 's/^A pr1/An edited pr1/' "$R"
expect_next 'root review-feature child wait-parent sib wait-parent grand wait-parent' 'a spec edit voids the review'
run review "$R" needs-changes >/dev/null
expect_next 'root revise child wait-parent sib wait-parent grand wait-parent' 'NEEDS CHANGES asks for a revision'
run review "$R" ready >/dev/null
set_status "$R" approved
expect_fail 'review records only for a planning plan' "a plan review records only for a planning plan" review "$R" ready
expect_next 'root execute-feature child review-feature sib review-feature grand wait-parent' 'an approved root opens its children to review'
run review "$C" ready >/dev/null
sed -i '/^## Goal/a Revised contract.' "$R"
expect_next 'root blocked child review-feature sib review-feature grand wait-parent' 'a spec change voids the reviews of the plan and the plans above it'
set_status "$R" planning; run review "$R" ready >/dev/null; set_status "$R" approved
run review "$C" ready >/dev/null
set_status "$C" approved
expect_next 'root execute-feature child wait-parent sib review-feature grand review-feature' 'an approved child waits for its parent to be reviewed'

out=$(run next "$R" --md)
[[ "$(sed -n 1,2p <<<"$out")" == $'| plan | status | parent | action | reason |\n|---|---|---|---|---|' ]] || fail "md header: $out"
[[ "$(sed -n 3p <<<"$out")" == '| pr1.spec.md | approved | - | execute-feature | - |' ]] || fail "md row: $out"
[[ "$(sed -n 4p <<<"$out")" == '| pr2.spec.md | approved | pr1.spec.md | wait-parent | pr1.spec.md must be reviewed first |' ]] || fail "md child row: $out"
[[ "$(wc -l <<<"$out")" -eq 6 ]] || fail "md rows: $out"
expect_fail 'next takes only --md as an option' 'Usage' next "$R" --json
pass 'next --md prints a Markdown table'

# ── runnable actions are the gate's ──
set_status "$R" implemented
out=$(run next "$R" | awk -F'\t' 'NR==1 { print $4 "|" $5 }')
[[ "$out" == 'blocked|review-code: Plan records no Worktree.'* ]] || fail "gate reason: $out"
[[ "$(run next "$R" --md | sed -n 3p)" == *'| blocked | review-code: Plan records no Worktree.'* ]] || fail 'md gate reason'

pass "next reports the gate's reason when it blocks a phase"
seed=$(git -C "$REPO" rev-parse HEAD)
for p in "$R" "$C" "$S" "$G"; do printf 'Green: %s\n' "$seed" >> "$p"; done
set_status "$R" reviewed; set_status "$C" reviewed; set_status "$S" reviewed
expect_next 'root done child done sib done grand review-feature' 'the root waits until every plan is reviewed'
set_status "$R" implemented
expect_next 'root blocked child blocked sib blocked grand review-feature' 'a reviewed child of a parent back in implementation is blocked'
set_status "$R" reviewed
git -C "$REPO" commit -q --allow-empty -m 'fix: root repair'
printf 'Green: %s\n' "$(git -C "$REPO" rev-parse HEAD)" >> "$R"
[[ "$(run next "$R" | awk -F'\t' -v p="$C" '$1 == p { print $4 "|" $5 }')" == "blocked|its Green does not contain $R's Green"* ]] || fail 'stale child Green'
pass "a child reviewed before its parent's repair is blocked"
for p in "$C" "$S"; do printf 'Green: %s\n' "$(git -C "$REPO" rev-parse HEAD)" >> "$p"; done
set_status "$G" reviewed
[[ "$(run next "$R" | awk -F'\t' 'NR==1 { print $4 "|" $5 }')" == 'blocked|create-pr: '* ]] || fail 'create-pr gate'
pass 'a fully reviewed stack offers create-pr on the root, through its gate'
set_status "$G" bogus
[[ "$(run next "$R" | awk -F'\t' -v p="$G" '$1 == p { print $4 "|" $5 }')" == "blocked|unknown status 'bogus'" ]] || fail 'unknown status'
pass 'an unknown status blocks'
set_status "$G" published
[[ "$(run next "$R" | grep -c .)" -eq 3 ]] || fail 'a published plan is listed'
expect_fail 'a published plan takes no command' 'is published' review "$G" ready
pass 'a published plan leaves the stack and takes no command'
write_plan "$G" planning feat/grand pr2

# ── run stops ──
write_plan "$S" planning feat/sib pr1
reason_of() { run next "$R" | awk -F'\t' -v p="$1" '$1 == p { print $4 "|" $5 }'; }
expect_fail 'a stop reason is one line' 'one nonempty line' stop "$S" $'a\tb'
run stop "$S" 'review round limit; Failed fixes: 2/3 — x' >/dev/null
[[ "$(reason_of "$S")" == 'stopped|review round limit; Failed fixes: 2/3 — x' ]] || fail "stop: $(reason_of "$S")"
pass 'next shows a stopped plan with its reason'
run review "$S" ready >/dev/null
[[ "$(reason_of "$S")" == stopped* ]] || fail 'a review record cleared the stop'
pass 'records do not clear a stop'
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
git -C "$TEST_ROOT/wt" switch -q -c feat/sib
run stop "$S" 'three failed fixes' >/dev/null
[[ "$(reason_of "$S")" == stopped* ]] || fail 'branch stop'
git -C "$TEST_ROOT/wt" switch -q feat/root
git -C "$TEST_ROOT/wt" commit -q --allow-empty -m 'fix: the parent'
[[ "$(reason_of "$S")" == stopped* ]] || fail 'switching the worktree or committing to another branch cleared the stop'
pass "a shared worktree's switches and other branches' commits keep a stop"
git -C "$TEST_ROOT/wt" switch -q feat/sib
git -C "$TEST_ROOT/wt" commit -q --allow-empty -m 'fix: by hand'
[[ "$(reason_of "$S")" != stopped* ]] || fail "a new commit on the plan's branch kept the stop"
pass "a new commit on the plan's branch clears a stop"
run stop "$S" 'Failed fixes: 3/3 — TC-1 fails' >/dev/null
git -C "$TEST_ROOT/wt" commit -q --allow-empty -m 'fix: another try'
sed -i '/^## Goal/a Narrowed scope.' "$S"
[[ "$(reason_of "$S")" == 'stopped|Failed fixes: 3/3 — TC-1 fails' ]] || fail "three failed fixes: $(reason_of "$S")"
run resume "$S" >/dev/null
[[ "$(reason_of "$S")" != stopped* ]] || fail 'resume kept three failed fixes'
pass 'three failed fixes hold through changes until resume'
run stop "$S" 'Failed fixes: 1/3 — a; Failed fixes: 3/3 — b' >/dev/null
run stop "$S" 'needs repair' >/dev/null
git -C "$TEST_ROOT/wt" commit -q --allow-empty -m 'fix: one more'
[[ "$(reason_of "$S")" == 'stopped|Failed fixes: 1/3 — a; Failed fixes: 3/3 — b' ]] || fail "a later stop released three failed fixes: $(reason_of "$S")"
run resume "$S" >/dev/null
run stop "$S" 'Failed fixes: 3/30 — not a count' >/dev/null
git -C "$TEST_ROOT/wt" commit -q --allow-empty -m 'fix: and another'
[[ "$(reason_of "$S")" != stopped* ]] || fail 'a 3/30 reason held'
pass 'three failed fixes hold through later stops, read from every count'
[[ "$(run next "$R" --md | grep -c '^| ')" -ge 5 ]] || fail 'md after stops'

# ── records and failures ──
write_plan "$S" planning feat/sib pr1
run review "$S" ready >/dev/null
printf 'Plan review: READY at nothex\n' >> "$S"
[[ "$(run next "$R" | awk -F'\t' -v p="$S" '$1 == p { print $4 }')" == review-feature ]] || fail 'malformed last record'
pass 'a malformed last record does not count as a verdict'
X="$DIR/pr7.spec.md"
write_plan "$X" planning feat/x pr6
expect_fail 'stop needs a hash' 'Cannot hash' stop "$X" x
grep -q '^Run stop:' "$X" && fail 'a failed stop wrote a record'
pass 'a failed stop writes no record'
expect_fail 'review fails when a plan below is missing' 'Cannot hash' review "$X" ready
grep -q '^Plan review:' "$X" && fail 'review wrote a record after a hash failure'
pass 'review writes nothing when the hash fails'
expect_fail 'next fails on a stack it cannot read' 'Unreadable' next "$R"
printf 'All dev-stack.sh tests passed. Temporary fixtures: %s\n' "$TEST_ROOT"
