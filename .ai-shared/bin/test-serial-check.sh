#!/bin/bash
# PreToolUse guard for shell commands: denies a command that names a test runner
# listed in SERIAL_FLAG without that runner's serial flag, as ../CODING.md#tests
# requires. Reads hook JSON on stdin (Claude Code Bash tool_input, Antigravity
# run_command args, or Pi) and prints a deny decision, or nothing to pass.
#
# It matches text, not runs: any command with a runner's name as a word needs
# its flag as a word, including one that only mentions the runner. It passes
# when jq is missing or the input is unreadable.

set -euo pipefail
export LC_ALL=C

command -v jq >/dev/null 2>&1 || exit 0
HOOK_INPUT=$(cat)

IS_ANTIGRAVITY=0
if [[ "$HOOK_INPUT" == *'"toolCall"'* || "$HOOK_INPUT" == *'"hookEventName"'* ]]; then
  IS_ANTIGRAVITY=1
fi

# Antigravity arguments may arrive as a JSON string or with each value
# JSON-encoded; both are decoded, as in gate-check.sh.
CMD=$(jq -r '
  def dec: if type == "string" and test("^\"(.|\n)*\"$") then (fromjson? // .) else . end;
  if .tool_name? == "Bash" then .tool_input.command?
  elif .toolCall?.name? == "run_command" then
    (.toolCall.args | if type == "string" then (fromjson? // {}) else . end) as $a
    | ($a.CommandLine? // $a.command_line? // $a.command?) | dec
  else empty end // ""
' <<<"$HOOK_INPUT" 2>/dev/null) || exit 0

# A word: not preceded or followed by a letter, digit, _, or -.
has_word() {
  [[ "$CMD" =~ (^|[^[:alnum:]_-])$1([^[:alnum:]_-]|$) ]]
}

# A command that names a runner must name its serial flag.
declare -A SERIAL_FLAG=(
  [jest]=--runInBand
  [vitest]=--no-file-parallelism
)

reason=""
for runner in "${!SERIAL_FLAG[@]}"; do
  flag=${SERIAL_FLAG[$runner]}
  if has_word "$runner" && ! has_word "$flag"; then
    reason="This command names $runner without $flag. Run tests serially (CODING.md#tests): add $flag, after -- for npm (npm test -- $flag)."
    break
  fi
done

if [[ -n "$reason" ]]; then
  if (( IS_ANTIGRAVITY )); then
    jq -cn --arg r "$reason" '{decision:"deny",reason:$r}'
  else
    # Claude Code accepts only approve or block as a top-level decision and
    # drops output it cannot validate, so the deny goes in hookSpecificOutput only.
    jq -cn --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  fi
fi
exit 0
