#!/usr/bin/env bash
# dev-publish.sh against a local bare origin and a jq-backed gh stand-in that
# keeps PRs in a JSON file. No GitHub requests are made.
set -euo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PUBLISH="$SCRIPT_DIR/dev-publish.sh"
TEST_ROOT=$(mktemp -d /tmp/dev-publish-test.XXXXXX)
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$*"; }

mkdir -p "$TEST_ROOT/bin"
cat > "$TEST_ROOT/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
store="$GH_STORE"
[[ -f "$store" ]] || printf '[]\n' > "$store"
[[ "$1 $2" == "pr list" || "$1 $2" == "pr create" ]] || { echo "unsupported: $*" >&2; exit 2; }
action="$2"; shift 2
head= base= title= body= state=open draft=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --head) head="$2"; shift 2 ;;
    --base) base="$2"; shift 2 ;;
    --title) title="$2"; shift 2 ;;
    --body-file) body=$(cat "$2"); shift 2 ;;
    --state) state="$2"; shift 2 ;;
    --json) shift 2 ;;
    --draft) draft=true; shift ;;
    *) echo "unsupported option: $1" >&2; exit 2 ;;
  esac
done
if [[ "$action" == list ]]; then
  jq --arg h "$head" --arg s "${state^^}" '[.[] | select(.headRefName == $h and ($s == "ALL" or .state == $s))]' "$store"
else
  n=$(( $(jq length "$store") + 1 ))
  oid=$(git rev-parse "refs/remotes/origin/$head")
  url="https://github.test/o/r/pull/$n"
  jq --argjson n "$n" --arg u "$url" --arg h "$head" --arg b "$base" --arg t "$title" --arg body "$body" --arg o "$oid" --argjson d "$draft" \
    '. + [{number:$n, url:$u, state:"OPEN", headRefName:$h, baseRefName:$b, title:$t, body:$body, headRefOid:$o, isDraft:$d}]' \
    "$store" > "$store.tmp" && mv "$store.tmp" "$store"
  printf '%s\n' "$url"
fi
EOF
chmod +x "$TEST_ROOT/bin/gh"
export PATH="$TEST_ROOT/bin:$PATH"

# A main tree with a bare origin; Base main ignores build/.
new_repo() {
  local dir="$TEST_ROOT/$1"
  git init -q --bare "$dir/origin.git"
  git init -q -b main "$dir/main"
  git -C "$dir/main" config user.email dev-publish@example.test
  git -C "$dir/main" config user.name dev-publish-test
  git -C "$dir/main" remote add origin "$dir/origin.git"
  printf 'build/\n' > "$dir/main/.gitignore"
  printf 'seed\n' > "$dir/main/README.md"
  git -C "$dir/main" add . && git -C "$dir/main" commit -qm seed
  git -C "$dir/main" push -q origin main
  export GH_STORE="$dir/prs.json"
  printf '[]\n' > "$GH_STORE"
  REPO="$dir/main"
}

# A commit of $2 on the worktree's current branch.
commit_file() { printf '%s\n' "$2" > "$1/$2"; git -C "$1" add . && git -C "$1" commit -qm "feat: $2"; }

# The plan's worktree on slice $1 from $2; prints its path.
plan_worktree() {
  local wt
  wt=$(cd "$REPO" && bash "$SCRIPT_DIR/dev-worktree.sh" create "${1//\//-}" "$1" "$2" "$(dirname "$REPO")/wt" 2>/dev/null) || fail "worktree for $1"
  printf '%s\n' "$wt"
}

PLAN=docs/plans/7_feature_publish.spec.md
write_plan() {
  mkdir -p "$REPO/docs/plans"
  {
    printf '# Publish demo\n'
    printf 'Status: reviewed | Type: feature | Base: main | Issue: #7 | Worktree: %s\n\n' "$2"
    printf '## PR Pattern\n| PR | Branch | Parent | Steps | Summary |\n|---|---|---|---|---|\n%s\n\n' "$1"
    printf '%s\n' "$3"
  } > "$REPO/$PLAN"
}

run() { (cd "$REPO" && bash "$PUBLISH" "$@"); }
expect_fail() {
  local label="$1" want="$2"; shift 2
  local out code=0
  out=$(run "$@" 2>&1) || code=$?
  [[ "$code" -ne 0 ]] || fail "$label: expected failure"
  [[ "$out" == *"$want"* ]] || fail "$label: missing '$want' in: $out"
  pass "$label"
}
# What the agent does per slice in create-pr step 3.
open_pr() { # <branch> <base> <body-file> [--draft]
  git -C "$REPO" push -q -u origin "$1"
  (cd "$REPO" && gh pr create --base "$2" --head "$1" --title "feat: $1" --body-file "$3" ${4-}) >/dev/null
}
set_body() { jq --argjson i "$1" --arg b "$2" '.[$i].body = $b' "$GH_STORE" > "$GH_STORE.tmp" && mv "$GH_STORE.tmp" "$GH_STORE"; }

# ── two stacked slices in one worktree, from check through cleanup ──
new_repo chain
wt=$(plan_worktree feat/demo-1 main)
commit_file "$wt" one.txt
git -C "$wt" switch -q -c feat/demo-2 feat/demo-1
commit_file "$wt" two.txt
g1=$(git -C "$REPO" rev-parse feat/demo-1); g2=$(git -C "$REPO" rev-parse feat/demo-2)
rows='| PR-1 | feat/demo-1 | main | ST-1 | one |
| PR-2 | feat/demo-2 | feat/demo-1 | ST-2 | two |'
records="Green: PR-1 (feat/demo-1) at $g1
Green: PR-2 (feat/demo-2) at $g2"
write_plan "$rows" "$wt" "$records"

out=$(run check "$PLAN")
[[ "$out" == *$'PR-1\tfeat/demo-1\tbase=main'* && "$out" == *$'PR-2\tfeat/demo-2\tbase=feat/demo-1'* && "$out" == *'PASS check'* ]] || fail "check: $out"
pass 'check resolves each slice against its Parent'
printf 'other\n' > "$REPO/other.txt" && git -C "$REPO" add other.txt && git -C "$REPO" commit -qm 'feat: unrelated' && git -C "$REPO" push -q origin main
run check "$PLAN" >/dev/null
pass 'an unrelated Base advance does not block check'
write_plan "$rows" "$wt" "${records/$g2/$g1}"
expect_fail 'a tip that differs from its Green record blocks' 'differs from Green' check "$PLAN"
write_plan "$rows" "$wt" "$records"

git -C "$wt" switch -q feat/demo-1
expect_fail 'archive needs the worktree on the final slice' 'not on the final slice feat/demo-2' archive "$PLAN"
git -C "$wt" switch -q feat/demo-2
printf 'x\n' > "$wt/stray.txt"
expect_fail 'archive needs a clean worktree' 'is not clean' archive "$PLAN"
rm "$wt/stray.txt"
[[ "$(run archive "$PLAN")" == 'PASS archive committed at '* ]] || fail 'archive'
[[ "$(git -C "$wt" log -1 --format=%s)" == 'docs(plan): archive 7_feature_publish' ]] || fail 'archive subject'
[[ "$(git -C "$wt" show --format= --name-only HEAD)" == "$PLAN" ]] || fail 'archive commits only the plan'
grep -q '| Worktree:$' <(git -C "$wt" show "HEAD:$PLAN") || fail 'archive clears Worktree'
[[ "$(run archive "$PLAN")" == *'already committed'* ]] || fail 'archive rerun'
pass 'archive commits the plan copy once, with an empty Worktree'
run check "$PLAN" >/dev/null
pass 'check accepts the archive commit above the final Green'

body1="$TEST_ROOT/body1.md"; printf 'First slice. Refs #7\n' > "$body1"
open_pr feat/demo-1 main "$body1" --draft
run check "$PLAN" >/dev/null
pass 'check accepts the slice own open PR on resume'
jq '.[0].baseRefName = "other"' "$GH_STORE" > "$GH_STORE.tmp" && mv "$GH_STORE.tmp" "$GH_STORE"
expect_fail 'check blocks an open PR with another base' 'open PR not based on main' check "$PLAN"
jq '.[0].baseRefName = "main"' "$GH_STORE" > "$GH_STORE.tmp" && mv "$GH_STORE.tmp" "$GH_STORE"
first_archive=$(git -C "$wt" rev-parse HEAD)
# A repair after the PRs open: new commits on both slices, re-reviewed, then
# check and archive rerun before the push.
git -C "$wt" switch -q feat/demo-1 && printf 'fixed\n' >> "$wt/one.txt" && git -C "$wt" commit -qam 'fix: one'
git -C "$wt" switch -q feat/demo-2 && git -C "$wt" merge -q --no-edit feat/demo-1
g1=$(git -C "$REPO" rev-parse feat/demo-1); g2=$(git -C "$REPO" rev-parse feat/demo-2)
records="$records
Green: PR-1 (feat/demo-1) at $g1
Green: PR-2 (feat/demo-2) at $g2"
write_plan "$rows" "$wt" "$records"
run check "$PLAN" >/dev/null
pass 'check accepts the slice own open PR behind a repaired tip'
[[ "$(run archive "$PLAN")" == 'PASS archive committed at '* ]] || fail 'archive after repair'
[[ "$(git -C "$wt" show HEAD:"$PLAN" | grep -c "at $g2")" -eq 1 ]] || fail 'archive refreshes the copy'
run check "$PLAN" >/dev/null
git -C "$REPO" push -q origin feat/demo-1
jq --arg o "$g1" '.[0].headRefOid = $o' "$GH_STORE" > "$GH_STORE.tmp" && mv "$GH_STORE.tmp" "$GH_STORE"  # GitHub follows the push
pass 'archive refreshes its own earlier copy after a repair'

archive_sha=$(git -C "$wt" rev-parse HEAD)
body2="$TEST_ROOT/body2.md"
printf 'After https://github.test/o/r/pull/1. Plan: https://github.test/o/r/blob/%s/%s\n' "$archive_sha" "$PLAN" > "$body2"
open_pr feat/demo-2 feat/demo-1 "$body2"
run verify "$PLAN" >/dev/null
pass 'verify accepts bases, tips, Green, links, and the immutable archive link'
set_body 1 "After #1. Plan: https://github.test/o/r/blob/$first_archive/$PLAN"
expect_fail 'verify blocks a link to the copy archived before a repair' 'not the latest plan copy' verify "$PLAN"
set_body 1 'no links'
expect_fail 'verify reports a missing earlier-PR link' 'does not link earlier PR-1' verify "$PLAN"
expect_fail 'verify reports a missing archive link' 'no immutable' verify "$PLAN"
expect_fail 'cleanup keeps everything while verification fails' 'not verified' cleanup "$PLAN"
[[ -d "$wt" && -f "$REPO/$PLAN" ]] || fail 'cleanup touched state before verification'
set_body 1 "After #12. Plan: https://github.test/o/r/blob/$archive_sha/$PLAN"
expect_fail 'verify does not take #12 as a link to #1' 'does not link earlier PR-1' verify "$PLAN"
set_body 1 "After https://github.test/o/r/pull/12. Plan: https://github.test/o/r/blob/$archive_sha/$PLAN"
expect_fail 'verify does not take pull/12 as a link to pull/1' 'does not link earlier PR-1' verify "$PLAN"
set_body 1 "After #1. Plan: https://github.test/o/r/blob/$archive_sha/$PLAN"
run verify "$PLAN" >/dev/null
pass 'verify accepts #1 as a link to PR-1'
write_plan "$rows" "$wt" "${records/$g1/$(git -C "$REPO" rev-parse main)}"
expect_fail 'verify checks a non-final slice against its Green' 'origin/feat/demo-1 differs from Green' verify "$PLAN"
write_plan "$rows" "$wt" "$records"

mkdir -p "$wt/build" && printf 'x\n' > "$wt/build/out"
code=0; out=$(run cleanup "$PLAN" 2>&1) || code=$?
[[ "$code" -eq 4 && "$out" == *'IGNORED in'* && -d "$wt" ]] || fail "ignored content: $code $out"
pass 'cleanup shows ignored content before removing the worktree'
out=$(run cleanup "$PLAN" --ignored-checked)
[[ "$out" == *'deleted feat/demo-2'* && "$out" == *$'PR-1\tdeleted feat/demo-1'* && "$out" == *'live plan deleted'* ]] || fail "cleanup: $out"
[[ ! -e "$wt" && ! -e "$REPO/$PLAN" ]] || fail 'cleanup left state behind'
git -C "$REPO" rev-parse --verify -q refs/heads/feat/demo-1 >/dev/null && fail 'cleanup kept a pushed slice branch'
pass 'cleanup removes the worktree, every pushed slice branch, and the live plan'
[[ "$(run cleanup "$PLAN")" == *'already complete'* ]] || fail 'cleanup rerun'
pass 'a cleanup rerun after completion is a no-op'
expect_fail 'cleanup of a plan that never existed fails' 'Live plan not found' cleanup docs/plans/7_feature_typo.spec.md

# ── an unpushed local commit keeps its branch and the live plan ──
new_repo unpushed
wt=$(plan_worktree feat/u-1 main)
commit_file "$wt" u1.txt
git -C "$wt" switch -q -c feat/u-2 feat/u-1
commit_file "$wt" u2.txt
rows='| PR-1 | feat/u-1 | main | ST-1 | one |
| PR-2 | feat/u-2 | feat/u-1 | ST-2 | two |'
write_plan "$rows" "$wt" "Green: PR-1 (feat/u-1) at $(git -C "$REPO" rev-parse feat/u-1)
Green: PR-2 (feat/u-2) at $(git -C "$REPO" rev-parse feat/u-2)"
run archive "$PLAN" >/dev/null
open_pr feat/u-1 main "$body1"
printf 'After #1. Plan: https://github.test/o/r/blob/%s/%s\n' "$(git -C "$wt" rev-parse HEAD)" "$PLAN" > "$TEST_ROOT/body-u.md"
open_pr feat/u-2 feat/u-1 "$TEST_ROOT/body-u.md"
git -C "$REPO" worktree add -q "$TEST_ROOT/unpushed/side" feat/u-1 2>/dev/null
git -C "$TEST_ROOT/unpushed/side" commit -q --allow-empty -m 'wip: local only'
git -C "$REPO" worktree remove "$TEST_ROOT/unpushed/side"
expect_fail 'verify reports a local tip ahead of origin' 'local tip of feat/u-1 differ' verify "$PLAN"
git -C "$REPO" branch -q -f feat/u-1 origin/feat/u-1
# A cleanup that stopped after removing the worktree resumes from the branches.
git -C "$REPO" worktree remove "$wt"
out=$(run cleanup "$PLAN")
[[ "$out" == *$'PR-1\tdeleted feat/u-1'* && "$out" == *$'PR-2\tdeleted feat/u-2'* && ! -e "$REPO/$PLAN" ]] || fail "cleanup resume: $out"
pass 'a cleanup rerun after the worktree is gone deletes the branches and the plan'

# ── the live plan is untracked; a tracked plan is a published record ──
new_repo collide
wt=$(plan_worktree feat/collide main)
commit_file "$wt" c.txt
write_plan '| PR-1 | feat/collide | main | ST-1 | c |' "$wt" "Green: PR-1 (feat/collide) at $(git -C "$wt" rev-parse HEAD)"
mkdir -p "$wt/docs/plans" && printf 'Status: reviewed | Worktree:\n' > "$wt/$PLAN"
git -C "$wt" add -f "$PLAN" && git -C "$wt" commit -qm 'docs(plan): archive older'
expect_fail 'archive refuses a published plan at the same path' 'path collision' archive "$PLAN"
git -C "$REPO" add -f "$PLAN" && git -C "$REPO" commit -qm 'docs(plan): archive demo'
expect_fail 'a tracked plan is not a live plan' 'published record' check "$PLAN"
git -C "$REPO" rm -q --cached "$PLAN"
expect_fail 'a plan in HEAD but not the index is not a live plan' 'published record' check "$PLAN"
expect_fail 'a plan name outside the format is refused' 'Plan must be docs/plans/<issue>_<type>_<slug>.spec.md' check docs/plans/demo.md

# ── archive clears only the Worktree field ──
new_repo order
wt=$(plan_worktree feat/order main)
commit_file "$wt" o.txt
write_plan '| PR-1 | feat/order | main | ST-1 | o |' "$wt" "Green: PR-1 (feat/order) at $(git -C "$wt" rev-parse HEAD)"
sed -i "s#| Worktree: $wt\$#| Worktree: $wt | Owner: dev#" "$REPO/$PLAN"
run archive "$PLAN" >/dev/null
grep -q '^Status: reviewed | .* | Worktree: | Owner: dev$' "$wt/$PLAN" || fail "a field after Worktree: $(grep '^Status:' "$wt/$PLAN")"
pass 'archive clears Worktree and keeps a field after it'

# ── a repair merged forward into a later slice (plan.md#worktree) ──
new_repo forward
wt=$(plan_worktree feat/fwd-1 main)
commit_file "$wt" f1.txt
git -C "$wt" switch -q -c feat/fwd-2 feat/fwd-1
commit_file "$wt" f2.txt
git -C "$wt" switch -q feat/fwd-1
printf 'fixed\n' >> "$wt/f1.txt" && git -C "$wt" commit -qam 'fix: f1 repair'
git -C "$wt" switch -q feat/fwd-2
git -C "$wt" merge -q --no-edit feat/fwd-1
rows='| PR-1 | feat/fwd-1 | main | ST-1 | one |
| PR-2 | feat/fwd-2 | feat/fwd-1 | ST-2 | two |'
write_plan "$rows" "$wt" "Green: PR-1 (feat/fwd-1) at $(git -C "$REPO" rev-parse feat/fwd-1)
Green: PR-2 (feat/fwd-2) at $(git -C "$REPO" rev-parse feat/fwd-2)"
out=$(run check "$PLAN") || fail "check after merge-forward: $out"
[[ "$out" == *$'PR-2\tfeat/fwd-2\tbase=feat/fwd-1\tparent='"$(git -C "$REPO" rev-parse feat/fwd-1)"* ]] || fail "merge-forward parent: $out"
pass 'check accepts a repair merged forward and diffs from the repaired parent'

# ── a stacked plan parented on its published parent plan's last branch ──
new_repo befe
wta=$(plan_worktree feat/be main)
commit_file "$wta" be.txt
PLAN=docs/plans/7_feature_orders-api.spec.md
write_plan '| PR-1 | feat/be | main | ST-1 | be |' "$wta" "Green: PR-1 (feat/be) at $(git -C "$wta" rev-parse HEAD)"
wtb=$(plan_worktree feat/fe feat/be)
commit_file "$wtb" fe.txt
run archive "$PLAN" >/dev/null
printf 'Parent. Plan: https://github.test/o/r/blob/%s/%s\n' "$(git -C "$wta" rev-parse HEAD)" "$PLAN" > "$TEST_ROOT/body-be.md"
open_pr feat/be main "$TEST_ROOT/body-be.md"
run verify "$PLAN" >/dev/null && run cleanup "$PLAN" >/dev/null
PLAN=docs/plans/7_feature_orders-web.spec.md
write_plan '| PR-1 | feat/fe | feat/be | ST-1 | fe |' "$wtb" "Green: PR-1 (feat/fe) at $(git -C "$wtb" rev-parse HEAD)"
out=$(run check "$PLAN") || fail "check after the parent plan published: $out"
[[ "$out" == *$'PR-1\tfeat/fe\tbase=feat/be\tparent='"$(git -C "$wtb" rev-parse HEAD~1)"* ]] || fail "stacked parent: $out"
pass 'a stacked plan lacking only its parent archive commit passes check'
late="$TEST_ROOT/befe/late"
git -C "$REPO" worktree add -q "$late" origin/feat/be 2>/dev/null
printf 'late\n' > "$late/late.txt" && git -C "$late" add late.txt && git -C "$late" commit -qm 'feat: late be'
git -C "$late" push -q origin HEAD:feat/be
expect_fail 'a code commit on the Parent that the stacked plan lacks blocks' 'does not contain its Parent feat/be' check "$PLAN"
git -C "$late" reset -q --hard HEAD~1
mkdir -p "$late/docs" && printf 'notes\n' > "$late/docs/notes.md"
git -C "$late" add docs/notes.md && git -C "$late" commit -qm 'docs: notes'
git -C "$late" push -q -f origin HEAD:feat/be
expect_fail 'a non-plan docs change on the Parent blocks' 'does not contain its Parent feat/be' check "$PLAN"
git -C "$late" reset -q --hard HEAD~1
git -C "$late" mv be.txt docs/plans/moved.md && git -C "$late" commit -qm 'chore: move be'
git -C "$late" push -q -f origin HEAD:feat/be
expect_fail 'code renamed into docs/plans/ on the Parent blocks' 'does not contain its Parent feat/be' check "$PLAN"

# ── a stack tree publishing at once: root -> child -> grandchild, root -> sibling ──
# create-pr runs each step on every plan, parents first, before the next step.
new_repo tree
wtr=$(plan_worktree feat/root main); commit_file "$wtr" root.txt
wtc=$(plan_worktree feat/child feat/root); commit_file "$wtc" child.txt
wtg=$(plan_worktree feat/grand feat/child); commit_file "$wtg" grand.txt
wts=$(plan_worktree feat/sib feat/root); commit_file "$wts" sib.txt
stack=(root:feat/root:main:"$wtr" child:feat/child:feat/root:"$wtc" grand:feat/grand:feat/child:"$wtg" sib:feat/sib:feat/root:"$wts")
for entry in "${stack[@]}"; do
  IFS=: read -r name branch parent wt <<<"$entry"
  PLAN="docs/plans/7_feature_$name.spec.md"
  write_plan "| PR-1 | $branch | $parent | ST-1 | $name |" "$wt" "Green: PR-1 ($branch) at $(git -C "$wt" rev-parse HEAD)"
  [[ "$parent" == main ]] || sed -i "2a Stacks On: docs/plans/7_feature_${parent#feat/}.spec.md" "$REPO/$PLAN"
  [[ "$PLAN" != *child* ]] || sed -i '2a ```\nStacks On: docs/plans/7_feature_sib.spec.md\n```' "$REPO/$PLAN"
done
out=$(run stack docs/plans/7_feature_root.spec.md)
[[ "$out" == docs/plans/7_feature_root.spec.md$'\n'docs/plans/7_feature_child.spec.md$'\n'docs/plans/7_feature_sib.spec.md$'\n'docs/plans/7_feature_grand.spec.md ]] || fail "stack: $out"
pass 'stack lists the root, then every stacked plan, parents first'
expect_fail 'stack needs the root' 'pass the stack' stack docs/plans/7_feature_child.spec.md
for step in check archive; do
  for entry in "${stack[@]}"; do
    IFS=: read -r name _ _ _ <<<"$entry"
    out=$(run "$step" "docs/plans/7_feature_$name.spec.md" 2>&1) || fail "$step $name: $out"
  done
done
pass 'every plan in the tree checks, then archives'
for entry in "${stack[@]}"; do
  IFS=: read -r name branch parent wt <<<"$entry"
  printf 'Plan: https://github.test/o/r/blob/%s/docs/plans/7_feature_%s.spec.md\n' "$(git -C "$wt" rev-parse HEAD)" "$name" > "$TEST_ROOT/tree-$name.md"
  open_pr "$branch" "$parent" "$TEST_ROOT/tree-$name.md" --draft
done
for entry in "${stack[@]}"; do
  IFS=: read -r name _ _ _ <<<"$entry"
  out=$(run verify "docs/plans/7_feature_$name.spec.md" 2>&1) || fail "verify $name: $out"
done
expect_fail 'cleanup keeps a parent while a plan stacked on it is live' 'Live plans stack on docs/plans/7_feature_root.spec.md: docs/plans/7_feature_child.spec.md docs/plans/7_feature_sib.spec.md' cleanup docs/plans/7_feature_root.spec.md
[[ -d "$wtr" ]] || fail 'the parent guard touched the worktree'
for (( k = ${#stack[@]} - 1; k >= 0; k-- )); do
  IFS=: read -r name _ _ _ <<<"${stack[$k]}"
  out=$(run cleanup "docs/plans/7_feature_$name.spec.md" 2>&1) || fail "cleanup $name: $out"
done
[[ "$(jq -r '[.[].baseRefName] | join(",")' "$GH_STORE")" == 'main,feat/root,feat/child,feat/root' ]] || fail "tree PR bases: $(jq -c . "$GH_STORE")"
[[ -z "$(ls "$REPO/docs/plans")" ]] || fail "live plans left: $(ls "$REPO/docs/plans")"
pass 'the tree verifies with every PR on its parent branch, then cleans up'

printf 'All dev-publish tests passed. Temporary fixtures: %s\n' "$TEST_ROOT"
