#!/bin/bash
# Resolve a snapshot destination without writing or deleting a handoff
# (../skills/handoff.md).
set -euo pipefail
if [[ "${1-}" == --help || "${1-}" == -h ]]; then
  printf '%s\n' 'Usage: handoff-path.sh [session-id]' \
    'Prints <main root>/docs/handoff/<session-id>.md; writes nothing.' \
    'Defaults to $CLAUDE_CODE_SESSION_ID; an argument overrides it. Fails without an id,' \
    'outside a Git repository, or when Git does not ignore docs/handoff there.'
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

# The main root, never a linked worktree: create-pr's cleanup removes those.
root=$(bash "$(dirname -- "$(realpath -- "${BASH_SOURCE[0]}")")/dev-utils.sh" main-root 2>/dev/null) ||
  { printf 'Not in a Git repository: a handoff lives in its docs/handoff.\n' >&2; exit 1; }
git -C "$root" check-ignore -q --no-index -- "docs/handoff/$id.md" 2>/dev/null ||
  { printf 'Git does not ignore docs/handoff in %s, so a handoff could be committed. Add /docs/handoff/ to the global excludes file (git config core.excludesFile) or to .git/info/exclude.\n' "$root" >&2; exit 1; }

printf '%s/docs/handoff/%s.md\n' "$root" "$id"
