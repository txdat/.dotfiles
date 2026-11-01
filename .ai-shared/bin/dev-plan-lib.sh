# Plan reading shared by gate-check.sh, dev-stack.sh, and dev-publish.sh: plan
# paths, header fields, and the Stacks On tree (../skills/dev/plan.md).
# Source it with REPO_ROOT set to the main working-tree root. Plans live
# outside the repository, under $PLANS_ROOT/<repo>/<issue>_<slug>/pr<N>.spec.md;
# functions take and print canonical absolute plan paths. Functions only print
# and return status; callers decide how to fail.

# Byte-wise text handling: plan IDs and paths are ASCII, and a multibyte
# locale has crashed awk on invalid bytes.
export LC_ALL=C

# canonical_plan needs realpath -m; macOS ships a realpath without it.
realpath -m -- / >/dev/null 2>&1 || { printf 'dev-plan-lib.sh requires realpath with -m support (GNU coreutils).\n' >&2; return 1; }

# AI_PLANS_ROOT and AI_WORKTREES_ROOT override the roots, so tests never
# touch real plans or worktrees.
PLANS_ROOT=$(realpath -m -- "${AI_PLANS_ROOT:-$HOME/work/plans}")
WORKTREES_ROOT=$(realpath -m -- "${AI_WORKTREES_ROOT:-$HOME/work/wt}")
REPO_PLANS="$PLANS_ROOT/$(basename -- "$REPO_ROOT")"
# A plan path relative to REPO_PLANS.
PLAN_REL_RE='^[0-9]+_[a-z0-9-]+/pr[1-9][0-9]*\.spec\.md$'
PLAN_FORMAT="$REPO_PLANS/<issue>_<slug>/pr<N>.spec.md"
# child_plans keeps published plans only where a caller sets this for one call.
INCLUDE_PUBLISHED=0
[[ "$REPO_PLANS" != "$HOME"/* ]] || PLAN_FORMAT="~/${PLAN_FORMAT#"$HOME"/}"

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

# ── headers ───────────────────────────────────────────────────────────

# Per plan file, one record: "<path> US <header> US <raw Stacks On value> US
# <spec> RS". The header is the "Key: value" lines above the first "## "
# heading and outside fences, the first of each key, one per line. The spec
# is the file without its records: the header's Status, Spec, and Tip lines.
# The Stacks On
# value is "!" when the line is unreadable: anything that reads as a Stacks
# On line but is not exactly one unindented, plain `Stacks On:` line in the
# header — indented, bulleted, emphasized, repeated, empty, below the header,
# or with an unclosed fence — since a missed line would read the plan as a
# root. An empty file prints nothing.
PLAN_AWK='
  function flush() {
    if (file == "") return
    printf "%s\037%s\037%s\037%s\036", file, head,
      (fenced || n > 1 || bad || (n && line == "")) ? "!" : line, text
  }
  FNR == 1 { flush(); file = FILENAME; head = line = text = ""; fenced = body = n = bad = 0; split("", seen) }
  {
    record = 0
    if (!fenced && !body && match($0, /^[A-Z][A-Za-z ]*:/)) {
      key = substr($0, 1, RLENGTH - 1)
      if (!(key in seen)) { seen[key] = 1; head = head $0 "\n"; record = key == "Status" || key == "Spec" || key == "Tip" }
    }
    if (!record) text = text $0 "\n"
  }
  /^[[:space:]]*(```|~~~)/ { fenced = !fenced; next }
  fenced { next }
  /^## / { body = 1 }
  { l = $0; sub(/^[[:space:]>*_-]+/, "", l) }
  tolower(l) ~ /^stacks[[:space:]]+on/ {
    n++; if (body || $0 !~ /^Stacks On:/) bad = 1
    l = $0; sub(/^Stacks On:[[:space:]]*/, "", l); sub(/[[:space:]]+$/, "", l); line = l
  }
  END { flush() }'

# What PLAN_AWK read, by plan path, and each indexed directory's plan files in
# number order. A header starts with a newline, so every key follows one. A process caches every plan it reads, so it reads a plan
# before changing it, never after.
declare -gA PLAN_HEAD=() PLAN_STACKS=() PLAN_SPEC=() PLAN_FILES=()

# Reads plans $@, each a readable file, into the cache.
load_plans() {
  local f path head stacks spec
  for f in "$@"; do PLAN_HEAD[$f]="" PLAN_STACKS[$f]="" PLAN_SPEC[$f]=""; done
  while IFS=$'\037' read -r -d $'\036' path head stacks spec; do
    PLAN_HEAD[$path]=$'\n'$head PLAN_STACKS[$path]=$stacks PLAN_SPEC[$path]=$spec
  done < <(awk "$PLAN_AWK" "$@" 2>/dev/null)
}

# Reads every plan in plan $1's directory, the registered worktrees, and the
# local branches once, for a process that reads them often and changes none
# of them. Without it, plans load one at a time and Git is asked each time.
index_stack() {
  local dir="${1%/*}" files=() f
  PLAN_FILES[$dir]=$(printf '%s\n' "$dir"/pr*.spec.md | sort -V)
  while IFS= read -r f; do [[ ! -f "$f" || ! -r "$f" ]] || files+=("$f"); done <<<"${PLAN_FILES[$dir]}"
  (( ${#files[@]} == 0 )) || load_plans "${files[@]}"
  WORKTREE_LIST=$(git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null) || WORKTREE_LIST=""
  LOCAL_BRANCHES=$(git -C "$REPO_ROOT" for-each-ref --format='%(refname)' refs/heads 2>/dev/null) || LOCAL_BRANCHES=""
  GIT_INDEXED=1
}

# Loads plan $1 unless cached; fails when the file cannot be read.
plan_loaded() {
  [[ ! -v PLAN_HEAD[$1] ]] || return 0
  [[ -f "$1" && -r "$1" ]] || return 1
  load_plans "$1"
}

# The *_get readers set REPLY instead of printing, so loops over a stack
# call them without a subshell; the printing forms wrap them.

# Sets REPLY to header field $2 of plan $1 (its "$2: value" line), trimmed;
# empty without it. Fails when the file cannot be read.
field_get() {
  local value
  REPLY=""
  plan_loaded "$1" || return 1
  [[ "${PLAN_HEAD[$1]}" == *$'\n'"$2:"* ]] || return 0
  value=${PLAN_HEAD[$1]#*$'\n'"$2:"}; value=${value%%$'\n'*}
  value=${value#"${value%%[![:space:]]*}"}; REPLY=${value%"${value##*[![:space:]]}"}
}

# Sets header fields of plan $1 in place from "<key> <value>" pairs: each
# replaces its key's header line, and a missing key goes after Status, which
# must exist. Writes through a temporary file, so a failure leaves the plan.
set_header() {
  local plan="$1" tmp pairs=""
  shift
  while (( $# >= 2 )); do pairs+="$1"$'\037'"$2"$'\036'; shift 2; done
  field_get "$plan" Status && [[ -n "$REPLY" ]] || return 1
  tmp=$(mktemp "$plan.XXXXXX") || return 1
  chmod --reference="$plan" -- "$tmp"
  # Two passes over the plan: the first finds the header keys present, the
  # second rewrites the first line of each given key.
  PAIRS="$pairs" awk '
    BEGIN {
      n = split(ENVIRON["PAIRS"], kv, "\036") - 1
      for (i = 1; i <= n; i++) { split(kv[i], p, "\037"); keys[i] = p[1]; val[p[1]] = p[2] }
    }
    FNR == 1 { pass++; fenced = body = 0; split("", seen) }
    /^[[:space:]]*(```|~~~)/ { fenced = !fenced }
    /^## / && !fenced { body = 1 }
    !fenced && !body && match($0, /^[A-Z][A-Za-z ]*:/) && !((key = substr($0, 1, RLENGTH - 1)) in seen) {
      seen[key] = 1
      if (pass == 1) { present[key] = 1; next }
      if (key in val) print key ": " val[key]; else print
      if (key == "Status") for (i = 1; i <= n; i++) if (!(keys[i] in present)) print keys[i] ": " val[keys[i]]
      next
    }
    pass == 2 { print }' "$plan" "$plan" > "$tmp" || { rm -f -- "$tmp"; return 1; }
  mv -- "$tmp" "$plan"
}
field() { field_get "$@" || return 1; [[ -z "$REPLY" ]] || printf '%s\n' "$REPLY"; }

# Sets REPLY to the plan's parent from its `Stacks On: pr<K>` line, as a
# canonical path in the same directory with K below the plan's own number, so
# the tree never cycles; empty without one. Fails on an unreadable line
# (PLAN_AWK).
parent_get() {
  local k n=${1##*/pr}
  REPLY=""
  plan_loaded "$1" || return 1
  [[ -n "${PLAN_STACKS[$1]}" ]] || return 0
  [[ "${PLAN_STACKS[$1]}" =~ ^pr([1-9][0-9]*)$ ]] || return 1
  k=${BASH_REMATCH[1]}
  (( k < ${n%.spec.md} )) || return 1
  REPLY="${1%/*}/pr$k.spec.md"
}
stacks_on() { parent_get "$1" || return 1; [[ -z "$REPLY" ]] || printf '%s\n' "$REPLY"; }

# Sets REPLY to plan $1's Status value. A `reviewed` plan without a Tip SHA
# reads as an unknown status.
status_get() {
  field_get "$1" Status || true
  [[ "$REPLY" == reviewed ]] || return 0
  field_get "$1" Tip || true
  if [[ "$REPLY" =~ ^[0-9a-f]{7,40}$ ]]; then REPLY=reviewed; else REPLY='reviewed without its SHA'; fi
}
status_of() { status_get "$1"; printf '%s\n' "$REPLY"; }

# The Tip SHA review-code recorded on a `reviewed` plan; empty otherwise.
green_of() {
  status_get "$1"
  [[ "$REPLY" == reviewed ]] || return 0
  field_get "$1" Tip
  printf '%s\n' "$REPLY"
}

# A published plan: create-pr's cleanup finished; no phase resumes it.
is_published() { status_get "$1"; [[ "$REPLY" == published ]]; }

# The path dev-worktree.sh create gives worktree <name>.
worktree_path() { printf '%s/%s-%s\n' "$WORKTREES_ROOT" "${REPO_ROOT##*/}" "$1"; }

# The name plan $1's own worktree is created under: <issue>_<slug>-pr<N>.
worktree_name() { local dir=${1%/*} n=${1##*/pr}; printf '%s-pr%s\n' "${dir##*/}" "${n%.spec.md}"; }

is_worktree() {
  local list=${WORKTREE_LIST-}
  [[ -d "$1" && "$1" != "$REPO_ROOT" ]] || return 1
  [[ -n "${GIT_INDEXED-}" ]] || list=$(git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null)
  [[ $'\n'"$list"$'\n' == *$'\n'"worktree $1"$'\n'* ]]
}

branch_exists() {
  if [[ -n "${GIT_INDEXED-}" ]]; then [[ $'\n'"$LOCAL_BRANCHES"$'\n' == *$'\n'"refs/heads/$1"$'\n'* ]]
  else git -C "$REPO_ROOT" show-ref --verify -q "refs/heads/$1"; fi
}

# Plan $1's worktree, which nothing records: its own when registered; else,
# once its Branch exists, the one it shares with its parent; else empty, as
# for a plan not yet executed.
worktree_of() {
  local plan="$1" dir n own
  while :; do
    # worktree_path of worktree_name, inline: this runs once per level.
    dir=${plan%/*}; n=${plan##*/pr}
    own="$WORKTREES_ROOT/${REPO_ROOT##*/}-${dir##*/}-pr${n%.spec.md}"
    if is_worktree "$own"; then printf '%s\n' "$own"; return 0; fi
    field_get "$plan" Branch && [[ -n "$REPLY" ]] && branch_exists "$REPLY" || return 0
    parent_get "$plan" 2>/dev/null && [[ -n "$REPLY" ]] || return 0
    plan=$REPLY
  done
}

# Unpublished plans stacked on plan $1, by number; "!<plan>" for one whose
# Stacks On is malformed or names no plan, or that is a symlink, since it may
# mean $1. INCLUDE_PUBLISHED=1 keeps published plans (dev-stack.sh, for a
# published stack).
child_plans() {
  local f
  while IFS= read -r f; do
    [[ -f "$f" && "$f" != "$1" ]] && { [[ "${INCLUDE_PUBLISHED:-0}" == 1 ]] || ! is_published "$f"; } || continue
    if [[ -L "$f" ]] || ! parent_get "$f"; then printf '!%s\n' "$f"
    elif [[ "$REPLY" == "$1" ]]; then printf '%s\n' "$f"
    elif [[ -n "$REPLY" && ! -f "$REPLY" ]]; then printf '!%s\n' "$f"; fi
  done < <(if [[ -v PLAN_FILES[${1%/*}] ]]; then printf '%s\n' "${PLAN_FILES[${1%/*}]}"; else printf '%s\n' "${1%/*}"/pr*.spec.md | sort -V; fi)
}

# Every plan child_plans lists stacked above plan $1, breadth first, each once.
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

# The rank of a status in the sequence; empty for an unknown status. A review
# verdict is still planning.
status_rank() {
  case "$1" in planning|needs-changes|ready) echo 0 ;; approved) echo 1 ;; implemented) echo 2 ;; reviewed) echo 3 ;; published) echo 4 ;; esac
}

# The branch plan $1's PR targets: its parent plan's Branch, or its Base for
# a root. Fails on an unreadable Stacks On line.
pr_target() {
  local parent
  parent=$(stacks_on "$1") || return 1
  if [[ -n "$parent" ]]; then field "$parent" Branch; else field "$1" Base; fi
}

# Whether plan $1 was reviewed on top of its parent $2's current reviewed tip:
# its reviewed SHA contains the parent's.
contains_parent_green() {
  local parent_green plan_green
  parent_green=$(green_of "$2"); plan_green=$(green_of "$1")
  [[ -n "$parent_green" && -n "$plan_green" ]] &&
    git -C "$REPO_ROOT" merge-base --is-ancestor "$parent_green" "$plan_green" 2>/dev/null
}

# Sets REPLY to plan $1's spec, without trailing newlines; empty for a file it
# cannot read.
spec_get() {
  REPLY=""
  plan_loaded "$1" || return 0
  REPLY=${PLAN_SPEC[$1]}
  REPLY=${REPLY%"${REPLY##*[!$'\n']}"}
}

# A hash of plan $1's spec and the specs below it, so a change to any of them
# voids a verdict recorded against it. Fails on a missing plan below it or an
# unreadable Stacks On line.
plan_hash() {
  local plan="$1" text=""
  while [[ -n "$plan" ]]; do
    [[ -f "$plan" ]] || return 1
    spec_get "$plan"
    text+="$REPLY"$'\n'
    parent_get "$plan" || return 1
    plan=$REPLY
  done
  printf '%s' "$text" | git hash-object --stdin
}

# The Spec value verdict $2 records for spec hash $1: the hash itself for
# ready, and for needs-changes a hash bound to the verdict, so a Status set
# to approved by hand cannot pass a needs-changes verdict off as ready.
verdict_hash() {
  if [[ "$2" == ready ]]; then printf '%s\n' "$1"; else printf '%s %s\n' "$1" "$2" | git hash-object --stdin; fi
}

# The verdict plan $1's Spec value records for its current spec: ready or
# needs-changes; stale when it matches neither or is malformed; empty
# without one. Fails when the hash does.
review_state() {
  local rec hash
  field_get "$1" Spec || true
  rec=$REPLY
  [[ -n "$rec" && "$rec" != - ]] || return 0
  hash=$(plan_hash "$1") || return 1
  if [[ "$rec" == "$hash" ]]; then printf 'ready\n'
  elif [[ "$rec" == "$(verdict_hash "$hash" needs-changes)" ]]; then printf 'needs-changes\n'
  else printf 'stale\n'; fi
}
