#!/bin/bash
# test-serial-check.sh: deny and pass cases (../CODING.md#tests).
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CHECK="$ROOT/bin/test-serial-check.sh"

fails=0
expect() {
  local want="$1" cmd="$2" out got=pass
  out=$(jq -cn --arg c "$cmd" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c},cwd:"/tmp"}' | "$CHECK")
  # A deny must carry the fields Claude Code reads: event name, decision, and a
  # reason naming the flag, and no top-level decision, which Claude Code
  # accepts only as approve or block.
  [[ -z "$out" ]] || got=$(jq -r 'if .decision != null or .reason != null then "malformed" else .hookSpecificOutput
    | if .hookEventName == "PreToolUse" and (.permissionDecisionReason // "" | test("names jest without --runInBand"))
      then .permissionDecision else "malformed" end end' <<<"$out")
  if [[ "$got" == "$want" ]]; then printf 'ok   %-5s %s\n' "$want" "$cmd"
  else printf 'FAIL want %s got %s: %s\n%s\n' "$want" "$got" "$cmd" "$out"; fails=$((fails + 1)); fi
}

expect_agy() {
  local want="$1" cmd="$2" out got=pass
  out=$(jq -cn --arg c "$cmd" '{hookEventName:"PreToolUse",toolCall:{name:"run_command",args:{CommandLine:$c}},cwd:"/tmp"}' | "$CHECK")
  # A deny must carry top-level decision and reason for Antigravity, and no unknown proto fields.
  if [[ -n "$out" ]]; then
    got=$(jq -r 'if .decision == "deny" and (.reason // "" | test("names jest without --runInBand")) and (.hookSpecificOutput == null) and (.continue == null) and (.stopReason == null)
      then .decision else "malformed" end' <<<"$out")
  fi
  if [[ "$got" == "$want" ]]; then printf 'ok   agy %-5s %s\n' "$want" "$cmd"
  else printf 'FAIL agy want %s got %s: %s\n%s\n' "$want" "$got" "$cmd" "$out"; fails=$((fails + 1)); fi
}

# Names jest without --runInBand.
expect deny 'jest'
expect deny 'npx jest src/a.test.ts'
expect deny './node_modules/.bin/jest'
expect deny 'node node_modules/jest/bin/jest.js'
expect deny 'npm ci && npx jest 2>&1 | tail'
expect deny $'npx jest \\\n  src/a.test.ts'
expect deny 'jest --maxWorkers=1'
expect deny 'jest -i'
expect deny 'jest --runInBandX'
expect deny 'npx jest@29 src'
expect deny 'cat jest.config.js'
expect deny 'grep -r jest src'

# Names jest with --runInBand.
expect pass 'jest --runInBand'
expect pass 'npx jest --runInBand src/a.test.ts'
expect pass $'npx jest \\\n  --runInBand src/a.test.ts'
expect pass 'jest --runInBand;'
expect pass 'npx jest --runInBand&&echo ok'
expect pass 'jest --runInBand|tail'
expect pass '(cd p && npx jest --runInBand)'
expect pass 'bash -c "jest --runInBand"'
expect pass "npx jest '--runInBand'"

# Does not name jest as a word.
expect pass 'npm test'
expect pass 'ls'
expect pass 'npm i -D ts-jest'
expect pass 'cat jestconfig.json'
expect pass 'echo majesty'

# Antigravity hook inputs (run_command).
expect_agy deny 'jest'
expect_agy deny 'npx jest src/a.test.ts'
expect_agy pass 'npx jest --runInBand src/a.test.ts'
expect_agy pass 'npm test'

# Antigravity arguments sent as a JSON string, or with JSON-encoded values.
for args in '{"CommandLine":"\"npx jest src\""}' '"{\"CommandLine\":\"npx jest src\"}"'; do
  out=$(printf '{"hookEventName":"PreToolUse","toolCall":{"name":"run_command","args":%s}}' "$args" | "$CHECK")
  [[ "$(jq -r '.decision // ""' <<<"$out")" == deny ]] && echo "ok   agy deny  encoded $args" || { echo "FAIL agy encoded $args: $out"; fails=$((fails + 1)); }
done

# Other tools and unreadable input.
for input in \
  '{"tool_name":"Edit","tool_input":{"file_path":"jest"}}' \
  '{"toolCall":{"name":"write_file","args":{"Path":"jest"}}}' \
  'not json'; do
  out=$(printf '%s' "$input" | "$CHECK")
  [[ -z "$out" ]] && echo "ok   pass  $input" || { echo "FAIL $input: $out"; fails=$((fails + 1)); }
done

((fails == 0)) || { echo "$fails failed"; exit 1; }
echo 'all passed'
