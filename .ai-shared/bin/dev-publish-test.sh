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

# A slice worktree with one commit on top of its parent; prints its path.
slice() {
  local branch="$1" parent="$2" file="$3" wt
  wt=$(cd "$REPO" && bash "$SCRIPT_DIR/dev-worktree.sh" create "${branch//\//-}" "$branch" "$parent" "$(dirname "$REPO")/wt" 2>/dev/null) || fail "worktree for $branch"
  printf '%s\n' "$file" > "$wt/$file"
  git -C "$wt" add . && git -C "$wt" commit -qm "feat: $file"
  printf '%s\n' "$wt"
}

PLAN=docs/plans/demo_2026-10-17_feature_publish.md
write_plan() {
  mkdir -p "$REPO/docs/plans"
  {
    printf '# Task: publish demo\n'
    printf 'Status: reviewed | Type: feature | Base: main | Snapshot: %s | Issue: #7 | Worktree: %s\n\n' "$(git -C "$REPO" rev-parse main)" "$2"
    printf '## PR Pattern\nType: chain\n| PR | Branch | Parent | Steps | Summary |\n|---|---|---|---|---|\n%s\n\n' "$1"
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

# ── a two-slice chain from preflight through cleanup ──
new_repo chain
wt1=$(slice feat/demo-1 main one.txt)
wt2=$(slice feat/demo-2 feat/demo-1 two.txt)
g1=$(git -C "$wt1" rev-parse HEAD); g2=$(git -C "$wt2" rev-parse HEAD)
rows='| PR-1 | feat/demo-1 | main | ST-1 | one |
| PR-2 | feat/demo-2 | feat/demo-1 | ST-2 | two |'
records="Green: PR-1 (feat/demo-1) at $g1
Green: PR-2 (feat/demo-2) at $g2

## Publication Inventory
Worktree: PR-1 (feat/demo-1) at $wt1
Worktree: PR-2 (feat/demo-2) at $wt2"
write_plan "$rows" "$wt2" "$records"

out=$(run preflight "$PLAN")
[[ "$out" == *$'PR-1\tfeat/demo-1\tbase=main'* && "$out" == *$'PR-2\tfeat/demo-2\tbase=feat/demo-1'* ]] || fail "preflight bases: $out"
pass 'preflight resolves a chain to Base and the previous slice'

write_plan "$rows" "$wt2" "${records/$g2/$g1}"
expect_fail 'a tip that differs from its Green record blocks' 'differs from Green' preflight "$PLAN"
write_plan "$rows" "$wt2" "$records"

out=$(run archive "$PLAN")
[[ "$out" == *'+Status: reviewed'*'| Worktree:'$'\n'* && "$out" == *STAGED* ]] || fail "archive prepare: $out"
pass 'archive stages a reviewed copy with an empty Worktree and shows its diff'
run archive --commit "$PLAN" >/dev/null
[[ "$(git -C "$wt2" log -1 --format=%s)" == "docs(plan): archive demo_2026-10-17_feature_publish" ]] || fail 'archive commit subject'
grep -q '| Worktree:$' <(git -C "$wt2" show "HEAD:$PLAN") || fail 'archive clears Worktree'
[[ "$(run archive "$PLAN")" == *'already committed'* ]] || fail 'archive rerun'
pass 'archive commits once and a rerun is a no-op'

run preflight "$PLAN" >/dev/null
pass 'preflight accepts an archive-only commit above the final Green'

body1="$TEST_ROOT/body1.md"; printf 'First slice. Refs #7\n' > "$body1"
expect_fail 'a PR whose base branch is not on origin is refused' 'not on origin' create "$PLAN" PR-2 'feat: two' "$body1"
out=$(run create "$PLAN" PR-1 'feat: one' "$body1")
[[ "$out" == 'CREATED PR-1 https://github.test/o/r/pull/1' ]] || fail "create PR-1: $out"
grep -q '^Status: reviewed' "$REPO/$PLAN" || fail 'create changed the live plan'
[[ "$(jq -r '.[0].isDraft' "$GH_STORE")" == true ]] || fail 'PRs default to draft'
pass 'the first PR is a draft and leaves the live plan unchanged'
out=$(run create "$PLAN" PR-1 'feat: one' "$body1")
[[ "$out" == 'EXISTS PR-1 https://github.test/o/r/pull/1' && "$(jq length "$GH_STORE")" -eq 1 ]] || fail "duplicate create: $out"
pass 'an open PR at the recorded Parent and slice tip is reported, never recreated'
run preflight "$PLAN" >/dev/null
pass 'preflight accepts the slice own open PR on resume'
jq '.[0].baseRefName = "other"' "$GH_STORE" > "$GH_STORE.tmp" && mv "$GH_STORE.tmp" "$GH_STORE"
expect_fail 'preflight blocks an open PR with another base' 'open PR not based on main' preflight "$PLAN"
expect_fail 'create refuses an open PR with another base' 'not main at' create "$PLAN" PR-1 'feat: one' "$body1"
jq '.[0].baseRefName = "main"' "$GH_STORE" > "$GH_STORE.tmp" && mv "$GH_STORE.tmp" "$GH_STORE"
head1=$(jq -r '.[0].headRefOid' "$GH_STORE")
jq '.[0].headRefOid = "0000000000000000000000000000000000000000"' "$GH_STORE" > "$GH_STORE.tmp" && mv "$GH_STORE.tmp" "$GH_STORE"
expect_fail 'preflight blocks an open PR at another head' 'open PR not based on main at' preflight "$PLAN"
expect_fail 'create refuses an open PR at another head' 'not main at' create "$PLAN" PR-1 'feat: one' "$body1"
jq --arg o "$head1" '.[0].headRefOid = $o' "$GH_STORE" > "$GH_STORE.tmp" && mv "$GH_STORE.tmp" "$GH_STORE"

archive_sha=$(git -C "$wt2" rev-parse HEAD)
body2="$TEST_ROOT/body2.md"
printf 'After https://github.test/o/r/pull/1. Plan: https://github.test/o/r/blob/%s/%s\n' "$archive_sha" "$PLAN" > "$body2"
run create "$PLAN" PR-2 'feat: two' "$body2" --ready >/dev/null
[[ "$(jq -r '.[1].baseRefName + " " + (.[1].isDraft|tostring)' "$GH_STORE")" == 'feat/demo-1 false' ]] || fail 'PR-2 base and ready'
pass 'a later slice targets the previous slice and honours --ready'

run verify "$PLAN" >/dev/null
pass 'verify accepts bases, tips, links, and the immutable archive link'
jq '.[1].body = "no links"' "$GH_STORE" > "$GH_STORE.tmp" && mv "$GH_STORE.tmp" "$GH_STORE"
expect_fail 'verify reports a missing earlier-PR link' 'does not link earlier PR-1' verify "$PLAN"
expect_fail 'verify reports a missing archive link' 'no immutable' verify "$PLAN"
expect_fail 'cleanup keeps everything while verification fails' 'not verified' cleanup "$PLAN"
[[ -d "$wt1" && -f "$REPO/$PLAN" ]] || fail 'cleanup touched state before verification'
jq --arg b "After #12. Plan: https://github.test/o/r/blob/$archive_sha/$PLAN" '.[1].body = $b' "$GH_STORE" > "$GH_STORE.tmp" && mv "$GH_STORE.tmp" "$GH_STORE"
expect_fail 'verify does not take #12 as a link to #1' 'does not link earlier PR-1' verify "$PLAN"
jq --arg b "After https://github.test/o/r/pull/12. Plan: https://github.test/o/r/blob/$archive_sha/$PLAN" '.[1].body = $b' "$GH_STORE" > "$GH_STORE.tmp" && mv "$GH_STORE.tmp" "$GH_STORE"
expect_fail 'verify does not take pull/12 as a link to pull/1' 'does not link earlier PR-1' verify "$PLAN"
jq --arg b "After #1. Plan: https://github.test/o/r/blob/$archive_sha/$PLAN" '.[1].body = $b' "$GH_STORE" > "$GH_STORE.tmp" && mv "$GH_STORE.tmp" "$GH_STORE"
run verify "$PLAN" >/dev/null
pass 'verify accepts #1 as a link to PR-1'
jq --arg b "$(cat "$body2")" '.[1].body = $b' "$GH_STORE" > "$GH_STORE.tmp" && mv "$GH_STORE.tmp" "$GH_STORE"

mkdir -p "$wt1/build" && printf 'x\n' > "$wt1/build/out"
code=0; out=$(run cleanup "$PLAN" 2>&1) || code=$?
[[ "$code" -eq 4 && "$out" == *'IGNORED PR-1'* && -d "$wt1" && -d "$wt2" ]] || fail "ignored content: $code $out"
pass 'cleanup shows ignored content before removing any worktree'
out=$(run cleanup "$PLAN" --ignored-checked)
[[ "$out" == *$'PR-1\tdeleted feat/demo-1'* && "$out" == *$'PR-2\tdeleted feat/demo-2'* && "$out" == *'PLAN deleted (untracked)'* ]] || fail "cleanup: $out"
[[ ! -e "$wt1" && ! -e "$wt2" && ! -e "$REPO/$PLAN" ]] || fail 'cleanup left state behind'
pass 'cleanup removes worktrees, local branches, and the untracked live plan'
[[ "$(run cleanup "$PLAN")" == *'already complete'* ]] || fail 'cleanup rerun'
pass 'a cleanup rerun after completion is a no-op'

# ── the live plan is untracked; a tracked plan is a published record ──
new_repo collide
wtc=$(slice feat/collide main c.txt)
write_plan '| PR-1 | feat/collide | main | ST-1 | c |' "$wtc" "Green: PR-1 (feat/collide) at $(git -C "$wtc" rev-parse HEAD)"
mkdir -p "$wtc/docs/plans" && printf 'Status: reviewed | Worktree:\n' > "$wtc/$PLAN"
git -C "$wtc" add -f "$PLAN" && git -C "$wtc" commit -qm 'docs(plan): archive older'
expect_fail 'archive refuses a published plan at the same path' 'path collision' archive "$PLAN"
git -C "$REPO" add -f "$PLAN" && git -C "$REPO" commit -qm 'docs(plan): archive demo'
expect_fail 'a tracked plan is not a live plan' 'published record' preflight "$PLAN"
git -C "$REPO" rm -q --cached "$PLAN"
expect_fail 'a plan in HEAD but not the index is not a live plan' 'published record' preflight "$PLAN"

# ── archive clears only the Worktree field ──
new_repo order
wto=$(slice feat/order main o.txt)
write_plan '| PR-1 | feat/order | main | ST-1 | o |' "$wto" "Green: PR-1 (feat/order) at $(git -C "$wto" rev-parse HEAD)"
sed -i "s#| Worktree: $wto\$#| Worktree: $wto | Owner: dev#" "$REPO/$PLAN"
run archive "$PLAN" >/dev/null
grep -q '^Status: reviewed | .* | Worktree: | Owner: dev$' "$wto/$PLAN" || fail "a field after Worktree: $(grep '^Status:' "$wto/$PLAN")"
pass 'archive clears Worktree and keeps a field after it'

# ── the final PR needs a committed copy with an empty Worktree ──
new_repo copy
wtp=$(slice feat/copy main p.txt)
write_plan '| PR-1 | feat/copy | main | ST-1 | p |' "$wtp" "Green: PR-1 (feat/copy) at $(git -C "$wtp" rev-parse HEAD)"
mkdir -p "$wtp/docs/plans" && cp "$REPO/$PLAN" "$wtp/$PLAN"
git -C "$wtp" add -f "$PLAN" && git -C "$wtp" commit -qm 'docs(plan): archive demo_2026-10-17_feature_publish'
expect_fail 'a committed copy that keeps its Worktree is not the plan copy' 'no committed plan copy' create "$PLAN" PR-1 'feat: p' "$body1"

printf 'All dev-publish tests passed. Temporary fixtures: %s\n' "$TEST_ROOT"
