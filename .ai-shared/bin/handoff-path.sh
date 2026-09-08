#!/usr/bin/env bash
# Resolve a snapshot destination without writing or deleting a handoff.
set -euo pipefail
if [[ "${1-}" == --help || "${1-}" == -h ]]; then
  printf '%s\n' 'Usage: handoff-path.sh [plan-slug]' 'Prints /tmp/ai-handoff/<repo>[-<slug>].md; writes nothing.'
  exit 0
fi
[[ $# -le 1 ]] || { printf 'Expected at most one plan slug.\n' >&2; exit 2; }
slug="${1-}"
[[ -z "$slug" || "$slug" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]] || { printf 'Invalid plan slug.\n' >&2; exit 2; }
repo_root=$(git rev-parse --show-toplevel)
git_dir=$(git rev-parse --absolute-git-dir)
common_dir=$(git rev-parse --git-common-dir)
repo_name=$(basename -- "$repo_root")
# A linked worktree already carries its task identity in its directory name.
if [[ "$(realpath -- "$git_dir")" == "$(realpath -- "$common_dir")" && -n "$slug" ]]; then
  repo_name="$repo_name-$slug"
fi
printf '/tmp/ai-handoff/%s.md\n' "$repo_name"
