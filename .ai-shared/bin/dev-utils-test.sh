#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
UTILS="$SCRIPT_DIR/dev-utils.sh"
WORKTREES="$SCRIPT_DIR/dev-worktree.sh"
TEST_ROOT=$(mktemp -d /tmp/dev-utils-test.XXXXXX)

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
mkdir -p docs/plans && printf 'Status: approved\n' > docs/plans/0_feature_live.spec.md
worktree=$(bash "$WORKTREES" create task feature/task explicit-parent "$TEST_ROOT/worktrees")
equal "$worktree" "$TEST_ROOT/worktrees/main repo-task" 'worktree destination'
equal "$(git -C "$worktree" rev-parse HEAD)" "$parent_tip" 'explicit parent used instead of main HEAD'
equal "$(git rev-parse HEAD)" "$main_tip" 'main branch untouched'
equal "$(cd "$worktree" && bash "$UTILS" main-root)" "$repo" 'root from linked worktree'
[[ ! -e "$worktree/docs/plans/0_feature_live.spec.md" ]] || fail 'plan copied to worktree'
reject bash "$WORKTREES" create task feature/other explicit-parent "$TEST_ROOT/worktrees"
reject bash "$WORKTREES" create ../escape feature/escape explicit-parent "$TEST_ROOT/worktrees"
reject bash "$WORKTREES" create missing feature/missing no-such-parent "$TEST_ROOT/worktrees"
[[ ! -e "$TEST_ROOT/worktrees/main repo-missing" ]] || fail 'invalid parent created a worktree'
printf 'PASS: worktree creation, root-only plan, explicit parent, and refusal cases\n'

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

pushed=$(bash "$WORKTREES" create pushed feature/pushed main "$TEST_ROOT/worktrees")
git -C "$pushed" commit -q --allow-empty -m pushed
git -C "$pushed" push -q origin feature/pushed
equal "$(bash "$WORKTREES" remove "$pushed" 2>/dev/null)" 'deleted feature/pushed' 'pushed branch reported deleted'
[[ ! -e "$pushed" ]] || fail 'pushed worktree not removed'
! has_branch feature/pushed || fail 'pushed local branch not deleted'

ahead=$(bash "$WORKTREES" create ahead feature/ahead main "$TEST_ROOT/worktrees")
git -C "$ahead" push -q origin feature/ahead
git -C "$ahead" commit -q --allow-empty -m unpushed
equal "$(bash "$WORKTREES" remove "$ahead" 2>/dev/null)" 'kept feature/ahead' 'branch ahead of origin reported kept'
[[ ! -e "$ahead" ]] || fail 'worktree ahead of origin not removed'
has_branch feature/ahead || fail 'branch with unpushed work was deleted'

never=$(bash "$WORKTREES" create never feature/never main "$TEST_ROOT/worktrees")
equal "$(bash "$WORKTREES" remove "$never" 2>/dev/null)" 'kept feature/never' 'never-pushed branch reported kept'
has_branch feature/never || fail 'never-pushed branch was deleted'

# A stale tracking ref must not stand in for origin after the remote branch is gone.
gone=$(bash "$WORKTREES" create gone feature/gone main "$TEST_ROOT/worktrees")
git -C "$gone" push -q origin feature/gone
git -C "$repo" fetch -q origin feature/gone:refs/remotes/origin/feature/gone
git --git-dir="$TEST_ROOT/origin.git" branch -q -D feature/gone
equal "$(bash "$WORKTREES" remove "$gone" 2>/dev/null)" 'kept feature/gone' 'branch deleted on origin reported kept'
has_branch feature/gone || fail 'branch trusted a stale tracking ref'

dirty=$(bash "$WORKTREES" create dirty feature/dirty main "$TEST_ROOT/worktrees")
git -C "$dirty" push -q origin feature/dirty
printf 'untracked\n' > "$dirty/scratch.txt"
reject bash "$WORKTREES" remove "$dirty"
[[ -f "$dirty/scratch.txt" ]] || fail 'refused removal deleted untracked content'
has_branch feature/dirty || fail 'refused removal deleted the branch'

# Each case below would otherwise succeed, so the refusal comes from its own check.
extra=$(bash "$WORKTREES" create extra feature/extra main "$TEST_ROOT/worktrees")
git -C "$extra" push -q origin feature/extra
reject bash "$WORKTREES" remove "$extra" --keep-branch
[[ -d "$extra" ]] || fail 'an extra argument still removed the worktree'

detached=$(bash "$WORKTREES" create detached feature/detached main "$TEST_ROOT/worktrees")
git -C "$detached" push -q origin feature/detached
git -C "$detached" checkout -q --detach
reject bash "$WORKTREES" remove "$detached"
[[ -d "$detached" ]] || fail 'a detached worktree was removed'

# Linked dependencies go as symlinks, ignored or not; the shared main-root content stays.
unignored=$(bash "$WORKTREES" create unignored feature/unignored main "$TEST_ROOT/worktrees")
bash "$WORKTREES" link-deps "$unignored" node_modules
git -C "$unignored" push -q origin feature/unignored
equal "$(bash "$WORKTREES" remove "$unignored" 2>/dev/null)" 'deleted feature/unignored' 'worktree with an unignored dependency link removed'
printf 'node_modules\n' >> "$(git -C "$repo" rev-parse --git-common-dir)/info/exclude"
linked=$(bash "$WORKTREES" create linked feature/linked main "$TEST_ROOT/worktrees")
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

printf 'All dev utility tests passed. Temporary fixtures: %s\n' "$TEST_ROOT"
