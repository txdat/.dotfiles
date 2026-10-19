#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
TEST_ROOT=$(mktemp -d /tmp/handoff-path-test.XXXXXX)
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
reject() { if "$@" >/dev/null 2>&1; then fail "expected refusal: $*"; fi; }

repo="$TEST_ROOT/repo"
git init -q -b main "$repo"
git -C "$repo" config user.email handoff-path@example.test
git -C "$repo" config user.name handoff-path-test
git -C "$repo" commit --allow-empty -qm seed
cd "$repo"
[[ "$(CLAUDE_CODE_SESSION_ID=env-session bash "$SCRIPT_DIR/handoff-path.sh")" == "$HOME/work/ai-handoff/env-session.md" ]] || fail 'session id from environment'
[[ "$(CLAUDE_CODE_SESSION_ID=env-session bash "$SCRIPT_DIR/handoff-path.sh" arg-session)" == "$HOME/work/ai-handoff/arg-session.md" ]] || fail 'explicit session id overrides environment'
# The path depends on the session only, not on the repository or worktree.
[[ "$(cd "$TEST_ROOT" && CLAUDE_CODE_SESSION_ID= bash "$SCRIPT_DIR/handoff-path.sh" 0a1b-2c3d)" == "$HOME/work/ai-handoff/0a1b-2c3d.md" ]] || fail 'outside a repository'
reject env CLAUDE_CODE_SESSION_ID= bash "$SCRIPT_DIR/handoff-path.sh"
reject env CLAUDE_CODE_SESSION_ID= bash "$SCRIPT_DIR/handoff-path.sh" ../escape
reject env CLAUDE_CODE_SESSION_ID=../escape bash "$SCRIPT_DIR/handoff-path.sh"
reject bash "$SCRIPT_DIR/handoff-path.sh" one two
printf 'PASS: handoff path identity and invalid inputs\n'
printf 'All handoff-path tests passed. Temporary fixtures: %s\n' "$TEST_ROOT"
