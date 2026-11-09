#!/bin/bash
set -euo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
TEST_ROOT=$(mktemp -d /tmp/handoff-path-test.XXXXXX)
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
reject() { if "$@" >/dev/null 2>&1; then fail "expected refusal: $*"; fi; }
# The user's global excludes must not decide whether docs/handoff is ignored.
export GIT_CONFIG_GLOBAL=/dev/null XDG_CONFIG_HOME="$TEST_ROOT/xdg"

repo="$TEST_ROOT/repo"
git init -q -b main "$repo"
git -C "$repo" config user.email handoff-path@example.test
git -C "$repo" config user.name handoff-path-test
git -C "$repo" commit --allow-empty -qm seed
repo=$(realpath "$repo")
cd "$repo"
reject env CLAUDE_CODE_SESSION_ID=env-session bash "$SCRIPT_DIR/handoff-path.sh"
printf '/docs/handoff/\n' >> .git/info/exclude
[[ "$(CLAUDE_CODE_SESSION_ID=env-session bash "$SCRIPT_DIR/handoff-path.sh")" == "$repo/docs/handoff/env-session.md" ]] || fail 'session id from environment'
[[ "$(CLAUDE_CODE_SESSION_ID=env-session bash "$SCRIPT_DIR/handoff-path.sh" arg-session)" == "$repo/docs/handoff/arg-session.md" ]] || fail 'explicit session id overrides environment'
# A linked worktree resolves to the main root, which create-pr's cleanup keeps.
git worktree add -q "$TEST_ROOT/wt" -b side
[[ "$(cd "$TEST_ROOT/wt/" && CLAUDE_CODE_SESSION_ID= bash "$SCRIPT_DIR/handoff-path.sh" 0a1b-2c3d)" == "$repo/docs/handoff/0a1b-2c3d.md" ]] || fail 'from a linked worktree'
reject env -C "$TEST_ROOT" CLAUDE_CODE_SESSION_ID=x bash "$SCRIPT_DIR/handoff-path.sh"
reject env CLAUDE_CODE_SESSION_ID= bash "$SCRIPT_DIR/handoff-path.sh"
reject env CLAUDE_CODE_SESSION_ID= bash "$SCRIPT_DIR/handoff-path.sh" ../escape
reject env CLAUDE_CODE_SESSION_ID=../escape bash "$SCRIPT_DIR/handoff-path.sh"
reject bash "$SCRIPT_DIR/handoff-path.sh" one two
printf 'PASS: handoff path location, ignore check, and invalid inputs\n'
printf 'All handoff-path tests passed. Temporary fixtures: %s\n' "$TEST_ROOT"
