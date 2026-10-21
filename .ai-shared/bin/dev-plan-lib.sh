# Plan reading shared by gate-check.sh, dev-stack.sh, and dev-publish.sh: plan
# paths, Status-line fields, and the Stacks On tree (../skills/dev/plan.md).
# Source it with REPO_ROOT set to the main working-tree root. Plans live
# outside the repository, under $PLANS_ROOT/<repo>/<issue>_<slug>/pr<N>.spec.md;
# functions take and print canonical absolute plan paths. Functions only print
# and return status; callers decide how to fail.

# Byte-wise text handling: plan IDs and paths are ASCII, and a multibyte
# locale has crashed awk on invalid bytes.
export LC_ALL=C

# canonical_plan needs realpath -m; macOS ships a realpath without it.
realpath -m -- / >/dev/null 2>&1 || { printf 'dev-plan-lib.sh requires realpath with -m support (GNU coreutils).\n' >&2; return 1; }

# AI_PLANS_ROOT overrides the root, so tests never touch real plans.
PLANS_ROOT=$(realpath -m -- "${AI_PLANS_ROOT:-$HOME/work/ai-docs/plans}")
REPO_PLANS="$PLANS_ROOT/$(basename -- "$REPO_ROOT")"
# A plan path relative to REPO_PLANS.
PLAN_REL_RE='^[0-9]+_[a-z0-9-]+/pr[1-9][0-9]*\.spec\.md$'
PLAN_FORMAT="${REPO_PLANS/#"$HOME"/\~}/<issue>_<slug>/pr<N>.spec.md"

# ── paths ─────────────────────────────────────────────────────────────

# Every pr<N>.spec.md mention in $1, in order. A path stops at whitespace and
# the punctuation messages put around it (@, quotes, backticks, brackets,
# emphasis, table borders). / . and ~ never stop it, so a foreign prefix
# ("/other/plans/x/pr1.spec.md", "../pr1.spec.md") stays attached and fails
# canonical_plan.
plan_mentions() {
  local stop="][[:space:]@\`\"'()<>{}|│*,;:!?"
  grep -oE "[^${stop}]*pr[0-9]+\\.spec\\.md" <<<"$1" || true
}

# The absolute path of a plan of this repository, ~ expanded, whether or not
# it exists; fails for another repository's plans, traversal, a bare name, or
# a path outside <issue>_<slug>/pr<N>.spec.md. The file name is not resolved,
# so a symlinked plan keeps its own name for callers to refuse.
canonical_plan() {
  local path="$1" real
  [[ "$path" != '~/'* ]] || path="$HOME/${path#'~/'}"
  [[ "$path" == /* && "$path" != */ ]] || return 1
  real=$(realpath -m -- "$(dirname -- "$path")" 2>/dev/null) || return 1
  real="$real/$(basename -- "$path")"
  [[ "$real" == "$REPO_PLANS/"* && "${real#"$REPO_PLANS"/}" =~ $PLAN_REL_RE ]] || return 1
  printf '%s\n' "$real"
}

# A plan path as shown to people: relative to this repository's plans.
plan_label() { printf '%s\n' "${1#"$REPO_PLANS"/}"; }

# The N of pr<N>.spec.md.
plan_number() { local n="${1##*/pr}"; printf '%s\n' "${n%.spec.md}"; }

# One field of the Status line ("Status: x | Base: y | ..."), trimmed.
field() {
  awk -v key="$2" '
    /^Status:/ {
      n = split($0, f, /\|/)
      for (i = 1; i <= n; i++) {
        x = f[i]; gsub(/^[[:space:]]+|[[:space:]]+$/, "", x)
        if (index(x, key ":") == 1) { sub("^" key ":[[:space:]]*", "", x); print x; exit }
      }
      exit
    }' "$1" 2>/dev/null
}

# The plan's parent from its `Stacks On: pr<K>` line, as a canonical path in
# the same directory with K below the plan's own number, so the tree never
# cycles; empty without one. Fails closed on any line that reads as a Stacks
# On line but is not exactly one unindented, plain `Stacks On: pr<K>` in the
# header — indented, bulleted, emphasized, repeated, empty, or below the
# header — since a missed line would read the plan as a root.
stacks_on() {
  local raw k
  raw=$(awk '/^[[:space:]]*(```|~~~)/ { fenced = !fenced; next }
    fenced { next }
    /^## / { body = 1 }
    { l = $0; sub(/^[[:space:]>*_-]+/, "", l) }
    tolower(l) ~ /^stacks[[:space:]]+on/ {
      n++; if (body || $0 !~ /^Stacks On:/) bad = 1
      sub(/^Stacks On:[[:space:]]*/, ""); sub(/[[:space:]]+$/, ""); line = $0
    }
    END { if (fenced || n > 1 || bad || (n && line == "")) exit 1; if (n) print line }' "$1" 2>/dev/null) || return 1
  [[ -n "$raw" ]] || return 0
  [[ "$raw" =~ ^pr([1-9][0-9]*)$ ]] || return 1
  k=${BASH_REMATCH[1]}
  (( k < $(plan_number "$1") )) || return 1
  printf '%s/pr%s.spec.md\n' "$(dirname -- "$1")" "$k"
}

# A published plan: create-pr's cleanup finished; no phase resumes it.
is_published() { [[ "$(field "$1" Status)" == published ]]; }

# Unpublished plans stacked on plan $1; "!<plan>" for one whose Stacks On is
# malformed or names no plan, or that is a symlink, since it may mean $1.
child_plans() {
  local f spec
  for f in "$(dirname -- "$1")"/pr*.spec.md; do
    [[ -f "$f" && "$f" != "$1" ]] && ! is_published "$f" || continue
    if [[ -L "$f" ]] || ! spec=$(stacks_on "$f" 2>/dev/null); then printf '!%s\n' "$f"
    elif [[ "$spec" == "$1" ]]; then printf '%s\n' "$f"
    elif [[ -n "$spec" && ! -f "$spec" ]]; then printf '!%s\n' "$f"; fi
  done
}

# Every unpublished plan stacked above plan $1, breadth first, each once.
descendant_plans() {
  local queue=("$1") seen=$'\n'"$1"$'\n' cur child
  while (( ${#queue[@]} > 0 )); do
    cur="${queue[0]}"; queue=("${queue[@]:1}")
    while IFS= read -r child; do
      [[ "$child" == '!'* || "$seen" != *$'\n'"$child"$'\n'* ]] || continue
      printf '%s\n' "$child"
      [[ "$child" != '!'* ]] || continue
      seen+="$child"$'\n'
      queue+=("$child")
    done < <(child_plans "$cur")
  done
}

# The plans in plan $1's directory with no Stacks On line. A directory holds
# one stack, so exactly one is the root.
root_plans() {
  local f spec
  for f in "$(dirname -- "$1")"/pr*.spec.md; do
    [[ -f "$f" && ! -L "$f" ]] || continue
    spec=$(stacks_on "$f" 2>/dev/null) || continue
    [[ -n "$spec" ]] || printf '%s\n' "$f"
  done
}

# The rank of a status in the sequence; empty for an unknown status.
status_rank() {
  case "$1" in planning) echo 0 ;; approved) echo 1 ;; implemented) echo 2 ;; reviewed) echo 3 ;; published) echo 4 ;; esac
}

# The branch plan $1's PR targets: its parent plan's Branch, or its Base for
# a root. Fails on an unreadable Stacks On line.
pr_target() {
  local parent
  parent=$(stacks_on "$1") || return 1
  if [[ -n "$parent" ]]; then field "$parent" Branch; else field "$1" Base; fi
}

# The SHA of plan $1's last `Green: <sha>` line; empty without one.
green_of() {
  sed -nE 's/^[[:space:]]*([-*][[:space:]]*)?Green: ([0-9a-f]{7,40})([^0-9a-f].*)?$/\2/p' "$1" 2>/dev/null | tail -1
}

# Whether plan $1 was reviewed on top of its parent $2's current reviewed tip:
# its Green contains the parent's Green.
contains_parent_green() {
  local parent_green plan_green
  parent_green=$(green_of "$2"); plan_green=$(green_of "$1")
  [[ -n "$parent_green" && -n "$plan_green" ]] &&
    git -C "$REPO_ROOT" merge-base --is-ancestor "$parent_green" "$plan_green" 2>/dev/null
}

# The spec without its records: Plan review and Run stop lines, Green lines
# as green_of reads them, Test lines of the Test Cases section, and the Status
# and Worktree values. Base, Branch, Type, Issue, and Stacks On stay, as does
# a Test or Green line written as spec text elsewhere.
spec_text() {
  awk '
    /^## / { tc = ($0 ~ /^## Test Cases[[:space:]]*$/) }
    /^Plan review:/ || /^Run stop:/ { next }
    /^[[:space:]]*([-*][[:space:]]*)?Green: [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]+([^0-9a-f].*)?$/ { next }
    tc && /^[[:space:]]*Test:/ { next }
    !done && /^Status:/ { gsub(/Status:[^|]*/, "Status: "); gsub(/Worktree:[^|]*/, "Worktree: "); done = 1 }
    { print }' "$1"
}

# A hash of plan $1's spec and the specs below it, so a change to any of them
# voids a verdict recorded against it. Fails on a missing plan below it or an
# unreadable Stacks On line.
plan_hash() {
  local plan="$1" text=""
  while [[ -n "$plan" ]]; do
    [[ -f "$plan" ]] || return 1
    text+="$(spec_text "$plan")"$'\n'
    plan=$(stacks_on "$plan") || return 1
  done
  printf '%s' "$text" | git hash-object --stdin
}

# Plan $1's last Plan review record against its current spec: READY or
# NEEDS CHANGES when it matches, stale when it does not or is malformed, and
# empty without one. Fails when the hash does.
review_state() {
  local rec hash
  rec=$(grep '^Plan review:' "$1" | tail -1 || true)
  [[ -n "$rec" ]] || return 0
  hash=$(plan_hash "$1") || return 1
  if [[ "$rec" =~ ^Plan\ review:\ (READY|NEEDS\ CHANGES)\ at\ ([0-9a-f]{40,64})$ && "${BASH_REMATCH[2]}" == "$hash" ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  else
    printf 'stale\n'
  fi
}
