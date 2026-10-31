#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
UTILS="$SCRIPT_DIR/dev-utils.sh"
WORKTREES="$SCRIPT_DIR/dev-worktree.sh"
TEST_ROOT=$(mktemp -d /tmp/dev-utils-test.XXXXXX)
export AI_WORKTREES_ROOT="$TEST_ROOT/worktrees"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
equal() { [[ "$1" == "$2" ]] || fail "$3: expected '$2', got '$1'"; }
reject() { if "$@" > /dev/null 2>&1; then fail "expected refusal: $*"; fi; }

repo="$TEST_ROOT/main repo"
mkdir -p "$repo"
git -C "$repo" init -q -b main
git -C "$repo" config user.email dev-utils@example.test
git -C "$repo" config user.name dev-utils-test
printf 'seed\n' > "$repo/README.md"
git -C "$repo" add README.md
git -C "$repo" commit -qm seed
cd "$repo"

equal "$(bash "$UTILS" main-root)" "$repo" 'main root'
mkdir -p nested
equal "$(cd nested && bash "$UTILS" main-root)" "$repo" 'root from subdirectory'
reject bash "$UTILS" main-root extra
reject bash "$UTILS" unknown
(cd "$TEST_ROOT" && reject bash "$UTILS" main-root)
git init --bare -q "$TEST_ROOT/bare.git"
(cd "$TEST_ROOT/bare.git" && reject bash "$UTILS" main-root)
printf 'PASS: root resolution and invalid contexts\n'

equal "$(bash "$UTILS" diagnostic-base)" refs/heads/main 'local main fallback'
git update-ref refs/remotes/origin/release/stable HEAD
git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/release/stable
equal "$(bash "$UTILS" diagnostic-base)" refs/remotes/origin/release/stable 'remote slash-containing default'
git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/missing
equal "$(bash "$UTILS" diagnostic-base)" refs/heads/main 'stale remote default fallback'
git branch -m main topic
git update-ref refs/remotes/origin/main HEAD
equal "$(bash "$UTILS" diagnostic-base)" refs/remotes/origin/main 'remote-only main fallback'
git update-ref -d refs/remotes/origin/main
reject bash "$UTILS" diagnostic-base
git branch -m topic main
printf 'PASS: diagnostic base precedence and missing-base refusal\n'

mkdir -p src src/tests tests __tests__ contest
for path in src/live.ts contest/live.ts src/unit.test.ts src/unit_spec.py tests/live.ts src/tests/live.ts __tests__/live.ts; do
  printf 'needle.with.dot\n' > "$path"
done
printf 'needleXwithXdot\n' > src/other.ts
output=$(bash "$UTILS" search-production needle.with.dot .)
[[ "$output" == *'src/live.ts:'* && "$output" == *'contest/live.ts:'* ]] || fail 'production callers missing'
[[ "$output" != *'unit.'* && "$output" != *'unit_spec'* && "$output" != *'tests/'* && "$output" != *'other.ts'* ]] || fail 'test paths or regex false positives included'
if bash "$UTILS" search-production absent . >/dev/null; then
  fail 'no-match search must return 1'
else
  equal "$?" 1 'no-match status'
fi
printf 'PASS: literal production search and path-based test exclusions\n'

git branch explicit-parent HEAD
git commit --allow-empty -qm 'main diverged'
main_tip=$(git rev-parse HEAD)
parent_tip=$(git rev-parse explicit-parent)
worktree=$(bash "$WORKTREES" create task feature/task explicit-parent)
equal "$worktree" "$TEST_ROOT/worktrees/main repo-task" 'worktree destination'
equal "$(git -C "$worktree" rev-parse HEAD)" "$parent_tip" 'explicit parent used instead of main HEAD'
equal "$(git rev-parse HEAD)" "$main_tip" 'main branch untouched'
equal "$(cd "$worktree" && bash "$UTILS" main-root)" "$repo" 'root from linked worktree'
reject bash "$WORKTREES" create task feature/other explicit-parent
reject bash "$WORKTREES" create ../escape feature/escape explicit-parent
reject bash "$WORKTREES" create missing feature/missing no-such-parent
[[ ! -e "$TEST_ROOT/worktrees/main repo-missing" ]] || fail 'invalid parent created a worktree'
git branch feature/kept explicit-parent && git -C "$worktree" commit --allow-empty -qm unused
kept=$(bash "$WORKTREES" create kept feature/kept main)
equal "$(git -C "$kept" symbolic-ref --short HEAD) $(git -C "$kept" rev-parse HEAD)" "feature/kept $parent_tip" 'an existing branch is attached as it is'
rm -rf "$kept"
equal "$(bash "$WORKTREES" create kept feature/kept main)" "$kept" 'a worktree deleted by hand is recreated'
git worktree remove "$kept"
printf 'PASS: worktree creation, root-only plan, explicit parent, and refusal cases\n'

full=$(bash "$WORKTREES" create sparse-base sparse-base main)
mkdir -p "$full/keep/deep" "$full/other" "$full/skip"
for path in top.txt keep/shallow.txt keep/deep/f.txt other/f.txt skip/f.txt; do printf '%s\n' "$path" > "$full/$path"; done
git -C "$full" add . && git -C "$full" commit -qm dirs
git worktree remove "$full"
# A full worktree add runs post-checkout with skip/ written; the sparse path must
# not. The environment pins hooksPath so a user's core.hooksPath cannot skip it.
hook="$(git rev-parse --git-common-dir)/hooks/post-checkout"
printf '%s\n' '#!/usr/bin/env bash' "[[ ! -e skip ]] || echo full >> '$TEST_ROOT/checkouts.log'" > "$hook" && chmod +x "$hook"
sparse=$(GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath GIT_CONFIG_VALUE_0="$(dirname "$hook")" bash "$WORKTREES" create sparse feature/sparse sparse-base keep/deep other)
rm "$hook"
[[ "$(cat "$TEST_ROOT/checkouts.log" 2>/dev/null)" != *full* ]] || fail 'the sparse worktree was fully checked out before its cone was set'
equal "$(cd "$sparse" && git ls-files -t | LC_ALL=C sort | tr '\n' ' ')" 'H README.md H keep/deep/f.txt H keep/shallow.txt H other/f.txt H top.txt S skip/f.txt ' 'cone checks out root files and the given directories'
[[ ! -e "$sparse/skip" ]] || fail 'directory outside the cone checked out'
equal "$(git -C "$sparse" status --porcelain --untracked-files=all)" '' 'sparse worktree clean'
equal "$(git config core.sparseCheckout || true)" '' 'main root stays a full checkout'
equal "$(bash "$WORKTREES" remove "$sparse" 2>/dev/null)" 'kept feature/sparse' 'sparse worktree removed'
again=$(bash "$WORKTREES" create sparse feature/sparse main other)
equal "$(git -C "$again" sparse-checkout list) $(git -C "$again" rev-parse HEAD)" "other $(git rev-parse sparse-base)" 'an existing branch is reattached sparse'
git worktree remove "$again"
for dir in ../escape /abs 'a//b' -x . a/../b $'src\nlib' ''; do reject bash "$WORKTREES" create bad feature/bad main "$dir"; done
[[ ! -e "$TEST_ROOT/worktrees/main repo-bad" ]] && ! git rev-parse -q --verify refs/heads/feature/bad >/dev/null || fail 'an invalid directory created a worktree or branch'
# A stand-in git whose sparse-checkout fails: create removes the empty worktree.
mkdir -p "$TEST_ROOT/failing-git"
printf '%s\n' '#!/usr/bin/env bash' 'for a; do [[ $a == sparse-checkout ]] && exit 1; done' "exec $(command -v git) \"\$@\"" > "$TEST_ROOT/failing-git/git"
chmod +x "$TEST_ROOT/failing-git/git"
out=$(PATH="$TEST_ROOT/failing-git:$PATH" bash "$WORKTREES" create failed feature/failed main other 2>&1) && fail 'a failed sparse checkout succeeded'
[[ "$out" == *'Sparse checkout failed'* ]] || fail "sparse failure message: $out"
[[ ! -e "$TEST_ROOT/worktrees/main repo-failed" && "$(git worktree list)" != *repo-failed* ]] || fail 'a failed sparse checkout left a worktree'
! git rev-parse -q --verify refs/heads/feature/failed >/dev/null || fail 'a failed sparse checkout left the branch it created'
PATH="$TEST_ROOT/failing-git:$PATH" bash "$WORKTREES" create failed feature/sparse main other >/dev/null 2>&1 && fail 'a failed reattach succeeded'
git rev-parse -q --verify refs/heads/feature/sparse >/dev/null || fail 'a failed reattach deleted an existing branch'
printf 'PASS: sparse worktree creation, rollback, and directory refusals\n'

mkdir -p node_modules vendor "$worktree/vendor"
printf 'shared sentinel\n' > node_modules/keep.txt
printf 'local sentinel\n' > "$worktree/vendor/keep.txt"
bash "$WORKTREES" link-deps "$worktree"
[[ -L "$worktree/node_modules" ]] || fail 'dependency not linked'
[[ ! -L "$worktree/vendor" ]] || fail 'existing local dependency overwritten'
equal "$(readlink "$worktree/node_modules")" "$repo/node_modules" 'dependency link target'
bash "$WORKTREES" isolate-dep "$worktree" node_modules
[[ -d "$worktree/node_modules" && ! -L "$worktree/node_modules" ]] || fail 'dependency not isolated'
equal "$(<node_modules/keep.txt)" 'shared sentinel' 'shared dependency preserved'
bash "$WORKTREES" isolate-dep "$worktree" node_modules
reject bash "$WORKTREES" link-deps "$repo"
reject bash "$WORKTREES" link-deps "$TEST_ROOT"
reject bash "$WORKTREES" isolate-dep "$worktree" ../node_modules
printf 'file sentinel\n' > "$worktree/not-a-directory"
reject bash "$WORKTREES" isolate-dep "$worktree" not-a-directory
equal "$(<"$worktree/not-a-directory")" 'file sentinel' 'non-directory preserved'
printf 'PASS: dependency isolation preserves shared and existing local content\n'

# remove: a clean worktree goes; its branch goes only when origin has the same tip.
git init --bare -q "$TEST_ROOT/origin.git"
git -C "$repo" remote add origin "$TEST_ROOT/origin.git"
has_branch() { git -C "$repo" rev-parse --verify -q "refs/heads/$1" >/dev/null; }

pushed=$(bash "$WORKTREES" create pushed feature/pushed main)
git -C "$pushed" commit -q --allow-empty -m pushed
git -C "$pushed" push -q origin feature/pushed
equal "$(bash "$WORKTREES" remove "$pushed" 2>/dev/null)" 'deleted feature/pushed' 'pushed branch reported deleted'
[[ ! -e "$pushed" ]] || fail 'pushed worktree not removed'
! has_branch feature/pushed || fail 'pushed local branch not deleted'

ahead=$(bash "$WORKTREES" create ahead feature/ahead main)
git -C "$ahead" push -q origin feature/ahead
git -C "$ahead" commit -q --allow-empty -m unpushed
equal "$(bash "$WORKTREES" remove "$ahead" 2>/dev/null)" 'kept feature/ahead' 'branch ahead of origin reported kept'
[[ ! -e "$ahead" ]] || fail 'worktree ahead of origin not removed'
has_branch feature/ahead || fail 'branch with unpushed work was deleted'

never=$(bash "$WORKTREES" create never feature/never main)
equal "$(bash "$WORKTREES" remove "$never" 2>/dev/null)" 'kept feature/never' 'never-pushed branch reported kept'
has_branch feature/never || fail 'never-pushed branch was deleted'

# A stale tracking ref must not stand in for origin after the remote branch is gone.
gone=$(bash "$WORKTREES" create gone feature/gone main)
git -C "$gone" push -q origin feature/gone
git -C "$repo" fetch -q origin feature/gone:refs/remotes/origin/feature/gone
git --git-dir="$TEST_ROOT/origin.git" branch -q -D feature/gone
equal "$(bash "$WORKTREES" remove "$gone" 2>/dev/null)" 'kept feature/gone' 'branch deleted on origin reported kept'
has_branch feature/gone || fail 'branch trusted a stale tracking ref'

dirty=$(bash "$WORKTREES" create dirty feature/dirty main)
git -C "$dirty" push -q origin feature/dirty
printf 'untracked\n' > "$dirty/scratch.txt"
reject bash "$WORKTREES" remove "$dirty"
[[ -f "$dirty/scratch.txt" ]] || fail 'refused removal deleted untracked content'
has_branch feature/dirty || fail 'refused removal deleted the branch'

# Each case below would otherwise succeed, so the refusal comes from its own check.
extra=$(bash "$WORKTREES" create extra feature/extra main)
git -C "$extra" push -q origin feature/extra
reject bash "$WORKTREES" remove "$extra" --keep-branch
[[ -d "$extra" ]] || fail 'an extra argument still removed the worktree'

detached=$(bash "$WORKTREES" create detached feature/detached main)
git -C "$detached" push -q origin feature/detached
git -C "$detached" checkout -q --detach
reject bash "$WORKTREES" remove "$detached"
[[ -d "$detached" ]] || fail 'a detached worktree was removed'

# Linked dependencies go as symlinks, ignored or not; the shared main-root content stays.
unignored=$(bash "$WORKTREES" create unignored feature/unignored main)
bash "$WORKTREES" link-deps "$unignored" node_modules
git -C "$unignored" push -q origin feature/unignored
equal "$(bash "$WORKTREES" remove "$unignored" 2>/dev/null)" 'deleted feature/unignored' 'worktree with an unignored dependency link removed'
printf 'node_modules\n' >> "$(git -C "$repo" rev-parse --git-common-dir)/info/exclude"
linked=$(bash "$WORKTREES" create linked feature/linked main)
bash "$WORKTREES" link-deps "$linked" node_modules
git -C "$linked" push -q origin feature/linked
equal "$(bash "$WORKTREES" remove "$linked" 2>/dev/null)" 'deleted feature/linked' 'worktree with an ignored dependency link removed'
equal "$(<"$repo/node_modules/keep.txt")" 'shared sentinel' 'remove preserved the linked dependency target'

reject bash "$WORKTREES" remove "$repo"
reject bash "$WORKTREES" remove "$TEST_ROOT"
printf 'PASS: remove deletes clean worktrees and only branches origin already holds\n'

# A local stand-in prints argument boundaries; no GitHub requests are made.
mkdir -p "$TEST_ROOT/bin"
printf '%s\n' '#!/usr/bin/env bash' 'printf "<%s>\n" "$@"' > "$TEST_ROOT/bin/gh"
chmod +x "$TEST_ROOT/bin/gh"
body="$TEST_ROOT/body with spaces.md"
printf 'body\n' > "$body"
equal "$(PATH="$TEST_ROOT/bin:$PATH" bash "$UTILS" issue-create 'Title with spaces' "$body" --label bug --milestone 'Next release')" \
  "<issue>"$'\n'"<create>"$'\n'"<--title>"$'\n'"<Title with spaces>"$'\n'"<--body-file>"$'\n'"<$body>"$'\n'"<--label>"$'\n'"<bug>"$'\n'"<--milestone>"$'\n'"<Next release>" 'issue argument boundaries'
reject env PATH="$TEST_ROOT/bin:$PATH" bash "$UTILS" issue-create title "$TEST_ROOT/missing"
reject env PATH="$TEST_ROOT/bin:$PATH" bash "$UTILS" issue-create '' "$body"
printf 'PASS: issue-create arguments and refusals (stubbed)\n'

cd "$repo"
# scratch: a detached throwaway under the scratch root, made at a ref behind HEAD
# so a scratch made at HEAD fails, that never reaches a plan's worktree, the
# main root, or shared dependencies.
base=$(git rev-parse HEAD)
git tag scratch-ref "$base"
git commit -q --allow-empty -m ahead
scratch=$(bash "$WORKTREES" scratch r1 scratch-ref 2>/dev/null)
equal "$scratch" "$AI_WORKTREES_ROOT/scratch/main repo-r1" 'scratch path'
equal "$(git -C "$scratch" rev-parse HEAD)" "$base" 'scratch at the ref'
git -C "$scratch" symbolic-ref -q HEAD >/dev/null && fail 'scratch HEAD is not detached'
[[ -L "$scratch/node_modules" && -L "$scratch/vendor" ]] || fail 'scratch dependencies not linked'
reject bash "$WORKTREES" scratch r1 scratch-ref
reject bash "$WORKTREES" scratch ../escape scratch-ref
reject bash "$WORKTREES" scratch r2 no-such-ref
reject bash "$WORKTREES" scratch r2 scratch-ref "$TEST_ROOT/missing.patch"
printf 'plan sentinel\n' > "$worktree/plan-sentinel.txt"
# Each guard alone: a worktree under the scratch root without a recorded base,
# and a plan's worktree with one.
nobase="$AI_WORKTREES_ROOT/scratch/main repo-nobase"
git worktree add -q --detach "$nobase" scratch-ref
plan_base="$(git -C "$worktree" rev-parse --absolute-git-dir)/scratch-base"
printf '%s\n' "$base" > "$plan_base"
for target in "$worktree" "$repo" "$TEST_ROOT" "$nobase"; do
  reject bash "$WORKTREES" scratch-diff "$target"
  reject bash "$WORKTREES" scratch-remove "$target"
done
rm -- "$plan_base" && git worktree remove --force "$nobase"
equal "$(<"$worktree/plan-sentinel.txt")" 'plan sentinel' 'scratch commands left a plan worktree alone'
[[ -d "$worktree" && -d "$repo/node_modules" ]] || fail 'scratch refusal removed something'
printf 'PASS: scratch creation and refusals\n'

printf 'broken\n' > "$scratch/README.md"
mkdir -p "$scratch/tests" && printf 'repro\n' > "$scratch/tests/repro.txt" && printf 'other\n' > "$scratch/tests/other.txt"
git -C "$scratch" add README.md
staged=$(git -C "$scratch" diff --cached --name-only)
patch="$TEST_ROOT/r1.patch"
bash "$WORKTREES" scratch-diff "$scratch" > "$patch"
grep -q '^+broken' "$patch" || fail 'diff misses a tracked change'
grep -q 'tests/repro.txt' "$patch" || fail 'diff misses a new file'
grep -q 'vendor' "$patch" && fail 'diff includes an unignored dependency link'
equal "$(git -C "$scratch" diff --cached --name-only)" "$staged" 'diff changed the scratch index'
only=$(bash "$WORKTREES" scratch-diff "$scratch" -- tests/repro.txt)
[[ "$only" == *tests/repro.txt* && "$only" != *README.md* && "$only" != *other.txt* ]] || fail 'diff paths did not limit the patch'
reject bash "$WORKTREES" scratch-diff "$scratch" tests/repro.txt
committed=$(bash "$WORKTREES" scratch r5 scratch-ref 2>/dev/null)
printf 'committed\n' > "$committed/README.md" && git -C "$committed" commit -qam committed
bash "$WORKTREES" scratch-diff "$committed" | grep -q '^+committed' || fail 'diff misses a change committed in the scratch'
printf 'x\n' > "$committed/x.txt"
[[ "$(bash "$WORKTREES" scratch-diff "$committed" -- x.txt)" != *committed* ]] || fail 'diff paths let a commit outside them through'
bash "$WORKTREES" scratch-remove "$committed" 2>/dev/null
rerun=$(bash "$WORKTREES" scratch r2 scratch-ref "$patch" 2>/dev/null)
equal "$(<"$rerun/README.md")" 'broken' 'scratch applies the patch'
equal "$(<"$rerun/tests/repro.txt")" 'repro' 'scratch applies new files'
bash "$WORKTREES" scratch-remove "$rerun" 2>/dev/null
# A ref that adopted the repro's file still takes the patch; one that changed it
# does not, and leaves no scratch behind.
tree_with() { (git ls-tree "$base"; printf '040000 tree %s\ttests\n' "$(printf '100644 blob %s\trepro.txt\n' "$(printf '%s\n' "$1" | git hash-object -w --stdin)" | git mktree)") | git mktree; }
adopted=$(git commit-tree "$(tree_with repro)" -p "$base" -m adopted)
diverged=$(git commit-tree "$(tree_with changed)" -p "$base" -m diverged)
later=$(bash "$WORKTREES" scratch r3 "$adopted" "$patch" 2>/dev/null) || fail 'a patch did not apply at a ref that adopted its test'
equal "$(<"$later/README.md")" 'broken' 'a patch applies at a ref that adopted its test'
bash "$WORKTREES" scratch-remove "$later" 2>/dev/null
reject bash "$WORKTREES" scratch r4 "$diverged" "$patch"
[[ ! -e "$AI_WORKTREES_ROOT/scratch/main repo-r4" ]] || fail 'a failed patch left its scratch'
git worktree list --porcelain | grep -qF 'main repo-r4' && fail 'a failed patch left its scratch registered'
# Deletions, paths with spaces, and several patches round-trip; an isolated
# dependency stays out of the diff, and a patch touching a dependency name never
# writes through a link into the main root.
rm -- "$scratch/README.md" && printf 'spaced\n' > "$scratch/with space.txt"
bash "$WORKTREES" isolate-dep "$scratch" vendor && printf 'local\n' > "$scratch/vendor/local.txt"
bash "$WORKTREES" scratch-diff "$scratch" -- README.md "with space.txt" > "$TEST_ROOT/r1b.patch"
grep -q 'vendor' <(bash "$WORKTREES" scratch-diff "$scratch") && fail 'diff includes an isolated dependency'
printf 'shared\n' > "$repo/vendor/shared.txt"
printf 'diff --git a/vendor/shared.txt b/vendor/shared.txt\nnew file mode 100644\n--- /dev/null\n+++ b/vendor/shared.txt\n@@ -0,0 +1 @@\n+junk\n' > "$TEST_ROOT/dep.patch"
both=$(bash "$WORKTREES" scratch r6 scratch-ref "$TEST_ROOT/r1b.patch" "$TEST_ROOT/dep.patch" 2>/dev/null) || fail 'several patches did not apply'
[[ ! -e "$both/README.md" ]] || fail 'a deletion did not round-trip'
equal "$(<"$both/with space.txt")" 'spaced' 'a path with a space round-trips'
equal "$(<"$repo/vendor/shared.txt")" 'shared' 'a patch wrote through a dependency link'
bash "$WORKTREES" scratch-remove "$both" 2>/dev/null
git -C "$worktree" commit -q --allow-empty -m 'worktree only'
here=$(cd "$worktree" && bash "$WORKTREES" scratch r7 HEAD 2>/dev/null)
equal "$(git -C "$here" rev-parse HEAD)" "$(git -C "$worktree" rev-parse HEAD)" 'HEAD resolves in the calling worktree'
bash "$WORKTREES" scratch-remove "$here" 2>/dev/null
rm -- "$repo/vendor/shared.txt"
printf 'PASS: scratch-diff and scratch with patches\n'

bash "$WORKTREES" scratch-remove "$scratch" 2>/dev/null
[[ ! -e "$scratch" ]] || fail 'scratch not removed'
git worktree list --porcelain | grep -qF "worktree $scratch" && fail 'scratch still registered'
equal "$(<"$repo/node_modules/keep.txt")" 'shared sentinel' 'scratch-remove preserved the shared dependency'
lost=$(bash "$WORKTREES" scratch lost scratch-ref 2>/dev/null)
unlink -- "$lost/node_modules" && unlink -- "$lost/vendor" && rm -rf -- "$lost"
equal "$(bash "$WORKTREES" scratch lost scratch-ref 2>/dev/null)" "$lost" 'a scratch lost with its directory is recreated'
bash "$WORKTREES" scratch-remove "$lost" 2>/dev/null
printf 'PASS: scratch removal and recreation after loss\n'

printf 'All dev utility tests passed. Temporary fixtures: %s\n' "$TEST_ROOT"
