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

# A main tree with a bare origin and its own plans root; Base main ignores
# build/.
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
  export AI_PLANS_ROOT="$dir/plans" AI_WORKTREES_ROOT="$dir/wt"
  REPO="$dir/main"
  D="$AI_PLANS_ROOT/main/7_demo"
  mkdir -p "$D"
}

# A commit of $2 on the worktree's current branch.
commit_file() { printf '%s\n' "$2" > "$1/$2"; git -C "$1" add . && git -C "$1" commit -qm "feat: $2"; }

# A plan's own worktree <name> on branch $2 from $3; prints its path.
plan_worktree() {
  local wt
  wt=$(cd "$REPO" && bash "$SCRIPT_DIR/dev-worktree.sh" create "$1" "$2" "$3" 2>/dev/null) || fail "worktree for $2"
  printf '%s\n' "$wt"
}

# write_plan <file> <branch> <reviewed sha> [stacks on pr<K>]
write_plan() {
  {
    printf '# Publish demo\n'
    printf 'Status: reviewed %s | Type: feature | Base: main | Branch: %s | Issue: #7\n' "$3" "$2"
    [[ -z "${4-}" ]] || printf 'Stacks On: %s\n' "$4"
    printf '\n## Goal\nPublish.\n'
  } > "$1"
}
# reviewed <plan> <sha>: what review-code records.
reviewed() { sed -i "s/^Status: [^|]*/Status: reviewed $2 /" "$1"; }

run() { (cd "$REPO" && bash "$PUBLISH" "$@"); }
expect_fail() {
  local label="$1" want="$2"; shift 2
  local out code=0
  out=$(run "$@" 2>&1) || code=$?
  [[ "$code" -ne 0 ]] || fail "$label: expected failure"
  [[ "$out" == *"$want"* ]] || fail "$label: missing '$want' in: $out"
  pass "$label"
}
# What the agent does per plan in create-pr step 2.
open_pr() { # <branch> <base> <body-file> [--draft]
  git -C "$REPO" push -q -u origin "$1"
  (cd "$REPO" && gh pr create --base "$2" --head "$1" --title "feat: $1" --body-file "$3" ${4-}) >/dev/null
}
set_body() { jq --argjson i "$1" --arg b "$2" '.[$i].body = $b' "$GH_STORE" > "$GH_STORE.tmp" && mv "$GH_STORE.tmp" "$GH_STORE"; }
status_of() { sed -n 's/^Status: \([a-z]*\).*/\1/p' "$1"; }

# ── a parent and its only child sharing one worktree, from check through cleanup ──
new_repo chain
P1="$D/pr1.spec.md"; P2="$D/pr2.spec.md"
wt=$(plan_worktree 7_demo-pr1 feat/demo-1 main)
commit_file "$wt" one.txt
git -C "$wt" switch -q -c feat/demo-2 feat/demo-1
commit_file "$wt" two.txt
g1=$(git -C "$REPO" rev-parse feat/demo-1); g2=$(git -C "$REPO" rev-parse feat/demo-2)
[[ "$wt" == "$AI_WORKTREES_ROOT/main-7_demo-pr1" ]] || fail "worktree path: $wt"
write_plan "$P1" feat/demo-1 "$g1"
write_plan "$P2" feat/demo-2 "$g2" pr1

out=$(run check "$P1")
[[ "$out" == *$'feat/demo-1\tbase=main'* && "$out" == *'PASS check'* ]] || fail "check root: $out"
out=$(run check "$P2")
[[ "$out" == *$'feat/demo-2\tbase=feat/demo-1\tparent='"$g1"* ]] || fail "check child: $out"
pass "check resolves each plan against its PR target: Base, or its parent plan's branch"
printf 'other\n' > "$REPO/other.txt" && git -C "$REPO" add other.txt && git -C "$REPO" commit -qm 'feat: unrelated' && git -C "$REPO" push -q origin main
run check "$P1" >/dev/null
pass 'an unrelated Base advance does not block check'
reviewed "$P2" "$g1"
expect_fail 'a tip that differs from its reviewed SHA blocks' "differs from the reviewed $g1" check "$P2"
reviewed "$P2" ''
expect_fail 'a reviewed status without its SHA blocks' "no 'Status: reviewed <sha>'" check "$P2"
reviewed "$P2" "${g2:0:7}"
run check "$P2" >/dev/null
pass 'an abbreviated reviewed SHA resolves'
reviewed "$P2" "$g2"

body1="$TEST_ROOT/body1.md"; printf 'First plan. Refs #7\n' > "$body1"
open_pr feat/demo-1 main "$body1" --draft
run check "$P1" >/dev/null
pass "check accepts the plan's own open PR on resume"
jq '.[0].baseRefName = "other"' "$GH_STORE" > "$GH_STORE.tmp" && mv "$GH_STORE.tmp" "$GH_STORE"
expect_fail 'check blocks an open PR with another base' 'open PR not based on main' check "$P1"
jq '.[0].baseRefName = "main"' "$GH_STORE" > "$GH_STORE.tmp" && mv "$GH_STORE.tmp" "$GH_STORE"
# A repair to the parent after its PR opens: re-reviewed, then merged forward.
git -C "$wt" switch -q feat/demo-1 && printf 'fixed\n' >> "$wt/one.txt" && git -C "$wt" commit -qam 'fix: one'
g1=$(git -C "$REPO" rev-parse feat/demo-1)
reviewed "$P1" "$g1"
expect_fail 'a child lacking its parent repair blocks' "does not contain its parent plan's branch feat/demo-1" check "$P2"
git -C "$wt" switch -q feat/demo-2 && git -C "$wt" merge -q --no-edit feat/demo-1
g2=$(git -C "$REPO" rev-parse feat/demo-2)
reviewed "$P2" "$g2"
run check "$P1" >/dev/null && run check "$P2" >/dev/null
pass "check accepts a repair merged forward, and the plan's own open PR behind a repaired tip"
git -C "$REPO" push -q origin feat/demo-1
jq --arg o "$g1" '.[0].headRefOid = $o' "$GH_STORE" > "$GH_STORE.tmp" && mv "$GH_STORE.tmp" "$GH_STORE"  # GitHub follows the push

body2="$TEST_ROOT/body2.md"
printf 'After https://github.test/o/r/pull/1.\n' > "$body2"
open_pr feat/demo-2 feat/demo-1 "$body2"
run verify "$P1" >/dev/null && run verify "$P2" >/dev/null
pass 'verify accepts bases, tips, reviewed SHAs, and links to the PRs below'
set_body 1 'no links'
expect_fail 'verify reports a missing link to a PR below' 'body does not link the PR of 7_demo/pr1.spec.md' verify "$P2"
expect_fail 'cleanup keeps a parent while a plan stacked on it is unpublished' "Unpublished plans stack on $P1" cleanup "$P1"
expect_fail 'cleanup keeps everything while verification fails' 'not verified' cleanup "$P2"
[[ -d "$wt" && "$(status_of "$P2")" == reviewed ]] || fail 'cleanup touched state before verification'
set_body 1 'After #12.'
expect_fail 'verify does not take #12 as a link to #1' 'does not link the PR of' verify "$P2"
set_body 1 'After https://github.test/o/r/pull/12.'
expect_fail 'verify does not take pull/12 as a link to pull/1' 'does not link the PR of' verify "$P2"
set_body 1 'After #1.'
run verify "$P2" >/dev/null
pass 'verify accepts #1 as a link to the PR below'
reviewed "$P1" "$(git -C "$REPO" rev-parse main)"
expect_fail 'verify checks origin against the reviewed SHA' 'origin/feat/demo-1 differs from the reviewed' verify "$P1"
reviewed "$P1" "$g1"

out=$(run cleanup "$P2")
[[ "$out" == *"WORKTREE $wt returned to feat/demo-1"* && "$out" == *'deleted feat/demo-2'* && "$out" == *'Status: published'* ]] || fail "shared cleanup: $out"
[[ -d "$wt" && "$(git -C "$wt" symbolic-ref --short HEAD)" == feat/demo-1 ]] || fail 'the shared worktree was not handed back'
grep -qx 'Status: published | Type: feature | Base: main | Branch: feat/demo-2 | Issue: #7' "$P2" || fail "published header: $(grep '^Status:' "$P2")"
pass 'cleanup of a child sharing the worktree hands it back, deletes its branch, and keeps the plan as published'
[[ "$(run cleanup "$P2")" == *'already complete'* ]] || fail 'cleanup rerun'
pass 'a cleanup rerun after completion is a no-op'
expect_fail 'a published plan takes no check' 'is published' check "$P2"
mkdir -p "$wt/build" && printf 'x\n' > "$wt/build/out"
code=0; out=$(run cleanup "$P1" 2>&1) || code=$?
[[ "$code" -eq 4 && "$out" == *'IGNORED in'* && -d "$wt" ]] || fail "ignored content: $code $out"
pass 'cleanup shows ignored content before removing the worktree'
out=$(run cleanup "$P1" --ignored-checked)
[[ "$out" == *"WORKTREE removed $wt; deleted feat/demo-1"* && "$out" == *'Status: published'* ]] || fail "cleanup: $out"
[[ ! -e "$wt" && "$(status_of "$P1")" == published ]] || fail 'cleanup left state behind'
git -C "$REPO" rev-parse --verify -q refs/heads/feat/demo-1 >/dev/null && fail 'cleanup kept a pushed branch'
pass 'the plan that created the worktree removes it with its branch'
expect_fail 'cleanup of a plan that never existed fails' 'Plan not found' cleanup "$D/pr9.spec.md"

# ── an unpushed local commit; a cleanup resumed after the worktree is gone ──
new_repo unpushed
P1="$D/pr1.spec.md"
wt=$(plan_worktree 7_demo-pr1 feat/u-1 main)
commit_file "$wt" u1.txt
write_plan "$P1" feat/u-1 "$(git -C "$REPO" rev-parse feat/u-1)"
open_pr feat/u-1 main "$body1"
git -C "$wt" commit -q --allow-empty -m 'wip: local only'
expect_fail 'verify reports a local tip ahead of origin' 'local tip of feat/u-1 differ' verify "$P1"
git -C "$wt" reset -q --hard origin/feat/u-1
rm -rf "$wt"  # by hand: Git still registers it
out=$(run cleanup "$P1")
[[ "$out" == *'WORKTREE none'* && "$out" == *'deleted feat/u-1'* && "$(status_of "$P1")" == published ]] || fail "cleanup resume: $out"
pass 'a cleanup rerun after the worktree is gone deletes the branch and publishes the plan'

# ── plan paths ──
expect_fail 'a file outside the plans layout is refused' 'Plan must be' check "$REPO/README.md"
expect_fail 'a name outside pr<N>.spec.md is refused' 'Plan must be' check "$D/demo.md"
expect_fail "another repository's plans are refused" 'Plan must be' check "$AI_PLANS_ROOT/other/7_demo/pr1.spec.md"

# ── a stack tree publishing at once: root -> child -> grandchild, root -> sibling ──
# The root has two children, so each creates its own worktree; the grandchild
# is its parent's only child and shares the child's. create-pr runs each step
# on every plan, parents first, before the next step.
new_repo tree
wtr=$(plan_worktree 7_demo-pr1 feat/root main); commit_file "$wtr" root.txt
wtc=$(plan_worktree 7_demo-pr2 feat/child feat/root); commit_file "$wtc" child.txt
wts=$(plan_worktree 7_demo-pr3 feat/sib feat/root); commit_file "$wts" sib.txt
git -C "$wtc" switch -q -c feat/grand feat/child; commit_file "$wtc" grand.txt
stack=(1:feat/root:main: 2:feat/child:feat/root:pr1 3:feat/sib:feat/root:pr1 4:feat/grand:feat/child:pr2)
for entry in "${stack[@]}"; do
  IFS=: read -r n branch parent on <<<"$entry"
  write_plan "$D/pr$n.spec.md" "$branch" "$(git -C "$REPO" rev-parse "$branch")" "$on"
done
printf '\n```\nStacks On: pr3\n```\n' >> "$D/pr2.spec.md"
for entry in "${stack[@]}"; do
  IFS=: read -r n _ <<<"$entry"
  out=$(run check "$D/pr$n.spec.md" 2>&1) || fail "check pr$n: $out"
done
pass 'every plan in the tree checks'
printf 'Root.\n' > "$TEST_ROOT/tree-1.md"
printf 'After #1.\n' > "$TEST_ROOT/tree-2.md"
printf 'After #1.\n' > "$TEST_ROOT/tree-3.md"
printf 'After #1, #2.\n' > "$TEST_ROOT/tree-4.md"
for entry in "${stack[@]}"; do
  IFS=: read -r n branch parent _ <<<"$entry"
  open_pr "$branch" "$parent" "$TEST_ROOT/tree-$n.md" --draft
done
for entry in "${stack[@]}"; do
  IFS=: read -r n _ <<<"$entry"
  out=$(run verify "$D/pr$n.spec.md" 2>&1) || fail "verify pr$n: $out"
done
pass 'every plan in the tree verifies, each body linking the PRs below it'
expect_fail 'cleanup keeps a parent while plans stacked on it are unpublished' "Stacks On line: $D/pr2.spec.md $D/pr3.spec.md." cleanup "$D/pr1.spec.md"
printf '# Stray\nStatus: planning\n## Goal\nStacks On: pr4\n' > "$D/pr9.spec.md"
expect_fail 'cleanup keeps a plan while an unreadable Stacks On line may name it' "Stacks On line: !$D/pr9.spec.md" cleanup "$D/pr4.spec.md"
rm "$D/pr9.spec.md"
[[ -d "$wtr" ]] || fail 'the parent guard touched the worktree'
# From inside a worktree: the main repository's plans still resolve.
for (( k = ${#stack[@]} - 1; k >= 0; k-- )); do
  IFS=: read -r n _ <<<"${stack[$k]}"
  out=$(cd "$wtr" && bash "$PUBLISH" cleanup "$D/pr$n.spec.md" 2>&1) || fail "cleanup pr$n: $out"
  case "$n" in
    4) [[ "$out" == *"returned to feat/child"* ]] || fail "grandchild cleanup: $out" ;;
    3|2|1) [[ "$out" == *'WORKTREE removed'* ]] || fail "pr$n cleanup: $out" ;;
  esac
done
[[ "$(jq -r '[.[].baseRefName] | join(",")' "$GH_STORE")" == 'main,feat/root,feat/root,feat/child' ]] || fail "tree PR bases: $(jq -c . "$GH_STORE")"
for n in 1 2 3 4; do [[ "$(status_of "$D/pr$n.spec.md")" == published ]] || fail "pr$n not published"; done
[[ -z "$(git -C "$REPO" branch --list 'feat/*')" ]] || fail "branches left: $(git -C "$REPO" branch --list 'feat/*')"
[[ ! -e "$wtr" && ! -e "$wtc" && ! -e "$wts" ]] || fail 'worktrees left'
pass 'the tree verifies with every PR on its parent branch, then cleans up children first, removing each worktree once'

printf 'All dev-publish tests passed. Temporary fixtures: %s\n' "$TEST_ROOT"
