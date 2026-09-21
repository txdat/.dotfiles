#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
TEST_ROOT=$(mktemp -d /tmp/dev-actions-test.XXXXXX)
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
reject() { if "$@" >/dev/null 2>&1; then fail "expected refusal: $*"; fi; }

# A local stand-in prints argument boundaries; no GitHub requests are made.
mkdir -p "$TEST_ROOT/bin"
printf '%s\n' '#!/usr/bin/env bash' 'printf "<%s>\n" "$@"' > "$TEST_ROOT/bin/gh"
chmod +x "$TEST_ROOT/bin/gh"
export PATH="$TEST_ROOT/bin:$PATH"
body="$TEST_ROOT/body with spaces.md"
printf 'body\n' > "$body"
output=$(bash "$SCRIPT_DIR/dev-github.sh" issue-create 'Title with spaces' "$body" --label bug --milestone 'Next release')
[[ "$output" == "<issue>"$'\n'"<create>"$'\n'"<--title>"$'\n'"<Title with spaces>"$'\n'"<--body-file>"$'\n'"<$body>"$'\n'"<--label>"$'\n'"<bug>"$'\n'"<--milestone>"$'\n'"<Next release>" ]] || fail 'issue argument boundaries'
output=$(bash "$SCRIPT_DIR/dev-github.sh" pr-create 'fix(scope): summary' "$body" feature/parent)
[[ "$output" == *$'<--base>\n<feature/parent>\n<--draft>' ]] || fail 'draft PR defaults and explicit parent'
output=$(bash "$SCRIPT_DIR/dev-github.sh" pr-create 'fix(scope): summary' "$body" feature/parent --ready)
[[ "$output" == *$'<--base>\n<feature/parent>' && "$output" != *'<--draft>'* ]] || fail 'ready PR option'
reject bash "$SCRIPT_DIR/dev-github.sh" pr-create title "$body" ''
reject bash "$SCRIPT_DIR/dev-github.sh" pr-create title "$body" main --unknown
reject bash "$SCRIPT_DIR/dev-github.sh" issue-create title "$TEST_ROOT/missing"
printf 'PASS: GitHub command arguments, defaults, and refusals (stubbed)\n'

repo="$TEST_ROOT/repo"
git init -q -b main "$repo"
git -C "$repo" config user.email dev-actions@example.test
git -C "$repo" config user.name dev-actions-test
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
printf 'All dev action tests passed. Temporary fixtures: %s\n' "$TEST_ROOT"
