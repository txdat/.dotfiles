#!/bin/bash
# PreToolUse guard for shell commands: denies a command that names jest without
# --runInBand, as ../CODING.md#tests requires. Reads hook JSON on stdin (Claude
# Code Bash tool_input, Antigravity run_command args, or Pi) and prints a deny
# decision, or nothing to pass.
#
# It matches text, not runs: any command with the word jest needs the word
# --runInBand, including one that only mentions jest. It passes when jq is
# missing or the input is unreadable.

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

if [[ "$CMD" =~ (^|[^[:alnum:]_-])jest([^[:alnum:]_-]|$) && ! "$CMD" =~ (^|[^[:alnum:]_-])--runInBand([^[:alnum:]_-]|$) ]]; then
  reason="This command names jest without --runInBand. Run tests serially in Jest's own process (CODING.md#tests): add --runInBand, after -- for npm (npm test -- --runInBand)."
  if (( IS_ANTIGRAVITY )); then
    jq -cn --arg r "$reason" '{decision:"deny",reason:$r}'
  else
    # Claude Code accepts only approve or block as a top-level decision and
    # drops output it cannot validate, so the deny goes in hookSpecificOutput only.
    jq -cn --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  fi
fi
exit 0
