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

mkdir -p docs/plans
printf 'Status: reviewed | Type: feature | Base: main | Issue: #12 | Worktree:\n' > docs/plans/live.md
printf 'Status: abandoned | Type: feature | Base: main | Issue: #12 | Worktree:\n' > docs/plans/dropped.md
printf 'Status: planning | Type: feature | Base: main | Issue: #123 | Worktree:\nIssue: #12 appears only in body\n' > docs/plans/other.md
equal "$(bash "$UTILS" issue-claimants 12)" "$repo/docs/plans/live.md" 'exact issue header and terminal filter'
reject bash "$UTILS" issue-claimants 0
reject bash "$UTILS" issue-claimants 12x
printf 'PASS: issue claimant filtering\n'

git branch explicit-parent HEAD
git commit --allow-empty -qm 'main diverged'
main_tip=$(git rev-parse HEAD)
parent_tip=$(git rev-parse explicit-parent)
worktree=$(bash "$WORKTREES" create task feature/task explicit-parent "$TEST_ROOT/worktrees")
equal "$worktree" "$TEST_ROOT/worktrees/main repo-task" 'worktree destination'
equal "$(git -C "$worktree" rev-parse HEAD)" "$parent_tip" 'explicit parent used instead of main HEAD'
equal "$(git rev-parse HEAD)" "$main_tip" 'main branch untouched'
equal "$(cd "$worktree" && bash "$UTILS" main-root)" "$repo" 'root from linked worktree'
[[ ! -e "$worktree/docs/plans/live.md" ]] || fail 'plan copied to worktree'
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

printf 'All dev utility tests passed. Temporary fixtures: %s\n' "$TEST_ROOT"
