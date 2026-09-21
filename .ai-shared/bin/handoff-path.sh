#!/usr/bin/env bash
# Resolve a snapshot destination without writing or deleting a handoff.
set -euo pipefail
if [[ "${1-}" == --help || "${1-}" == -h ]]; then
  printf '%s\n' 'Usage: handoff-path.sh [session-id]' \
    'Prints $HOME/work/ai-handoff/<session-id>.md; writes nothing.' \
    'Defaults to $CLAUDE_CODE_SESSION_ID; an argument overrides it. Fails without an id.'
  exit 0
fi
[[ $# -le 1 ]] || { printf 'Expected at most one session id.\n' >&2; exit 2; }

valid_id() {
  [[ -n "$1" && "$1" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]]
}

if [[ $# -eq 1 ]]; then
  id="$1"
  valid_id "$id" || { printf 'Invalid session id: %s\n' "$id" >&2; exit 2; }
elif [[ -n "${CLAUDE_CODE_SESSION_ID:-}" ]]; then
  id="$CLAUDE_CODE_SESSION_ID"
  valid_id "$id" || { printf 'Invalid CLAUDE_CODE_SESSION_ID: %s\n' "$id" >&2; exit 2; }
else
  printf 'No session id: supply one as an argument or set CLAUDE_CODE_SESSION_ID.\n' >&2
  exit 2
fi

printf '%s/work/ai-handoff/%s.md\n' "$HOME" "$id"
