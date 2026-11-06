#!/bin/bash
set -euo pipefail

pass() { printf 'PASS %s\n' "$*"; }
block() { printf 'BLOCK %s\n' "$*" >&2; exit 1; }
usage() { block "usage: dev-check.sh proof <commit> [--test path] [--stub path] | artifacts <base> [head] | pcs <plan> [--cwd dir] [PC-<n> ...]"; }

case "${1:-}" in
  proof)
    [[ $# -ge 2 ]] || usage
    commit="$2"; shift 2
    git rev-parse --verify "$commit^{commit}" >/dev/null 2>&1 || block "unknown proof commit: $commit"
    test_paths=(); stub_paths=()
    while [[ $# -gt 0 ]]; do
      kind="$1"; shift
      [[ $# -gt 0 ]] || usage
      case "$kind" in
        --test) test_paths+=("$1") ;;
        --stub) stub_paths+=("$1") ;;
        *) usage ;;
      esac
      shift
    done
    found=0
    while IFS= read -r path; do
      [[ -n "$path" ]] || continue
      found=1
      test_path=${path,,}
      case "$test_path" in
        test/*|tests/*|spec/*|specs/*|__tests__/*|fixtures/*|testdata/*|*/test/*|*/tests/*|*/spec/*|*/specs/*|*/__tests__/*|*/fixtures/*|*/testdata/*|*_test.*|*_spec.*|*.test.*|*.spec.*) continue ;;
      esac
      case "$path" in *Test.*|*Spec.*) continue ;; esac
      allowed_test=false
      for test_file in "${test_paths[@]}"; do [[ "$path" == "$test_file" ]] && allowed_test=true; done
      if $allowed_test; then
        # --test exempts a path that does not look like a test, so it is the
        # one way past the non-test-path block below. Require the claim to be
        # backed by test code the commit actually adds: an in-source test file
        # that introduces no test declares itself a test and isn't one.
        additions=$(git show --format= --unified=0 "$commit" -- "$path" | sed -n 's/^+\([^+]\)/\1/p')
        if ! printf '%s\n' "$additions" | rg -q '#\[(test|cfg\(test\))|\bmod tests\b|\bdef test|\bclass Test|\bfunc (Test|Benchmark|Fuzz)|@(Test|ParameterizedTest|Nested)\b|\[(Test|Fact|Theory)\]|\b(it|test|describe)(\.(each|only|skip))?[[:space:]]*\(|\bTEST(_F|_P|_CASE)?[[:space:]]*\(|\bfunction test'; then
          block "--test path adds no test code: $path (declare a real stub with --stub, or commit the test)"
        fi
        continue
      fi
      allowed_stub=false
      for stub in "${stub_paths[@]}"; do [[ "$path" == "$stub" ]] && allowed_stub=true; done
      $allowed_stub || block "proof touches non-test path: $path"
      additions=$(git show --format= --unified=0 "$commit" -- "$path" | sed -n 's/^+\([^+]\)/\1/p')
      # Throwing expression bodies are the permitted stub form (../skills/dev/plan.md#verification):
      # C# `=> throw ...`, Rust `=> panic!/todo!/unimplemented!/unreachable!`.
      if printf '%s\n' "$additions" \
        | rg -v '(=>|return)[[:space:]]*(throw\b|panic!|todo!|unimplemented!|unreachable!|raise\b)' \
        | rg -n 'return[[:space:]]+[^;[:space:]]|=>[[:space:]]*[^;{[:space:]]' >/dev/null; then
        block "stub contains value implementation: $path"
      fi
      # A body-less stub returns no value, so the check above never sees it —
      # but `def f(): pass`, a bare `...`, or an empty `{}` still returns
      # None/null/zero implicitly, and that is the expected value often enough
      # to turn a RED test green. plan.md#verification permits only a throwing stub.
      if printf '%s\n' "$additions" \
        | rg -n '^[[:space:]]*(pass|\.\.\.)[[:space:]]*$|:[[:space:]]*(pass|\.\.\.)[[:space:]]*$|\)[^{]*\{[[:space:]]*\}[[:space:]]*$|^[[:space:]]*return[[:space:]]*;?[[:space:]]*$|:[[:space:]]*return[[:space:]]*$' >/dev/null; then
        block "stub has a body-less implementation (pass / ... / empty block / bare return): $path — a stub must throw (skills/dev/plan.md#verification)"
      fi
    done < <(git diff-tree --no-commit-id --name-only -r "$commit")
    [[ "$found" -eq 1 ]] || block "proof commit is empty: $commit"
    pass "proof commit $commit"
    ;;
  artifacts)
    [[ $# -ge 2 && $# -le 3 ]] || usage
    [[ -n "$2" ]] || block "invalid ref: empty base"
    git rev-parse --verify --quiet "${2}^{commit}" >/dev/null 2>&1 || block "invalid ref: $2"
    end="${3:-HEAD}"
    git rev-parse --verify --quiet "${end}^{commit}" >/dev/null 2>&1 || block "invalid ref: $end"
    range="$2..$end"
    added=$(git diff "$range" | sed -n '/^+++ /d; /^+/p')
    # Conflict markers are never legitimate; debug-like output may be (a CLI's
    # print), so review-code judges those lines instead of the scan blocking.
    markers=$(rg -n '^\+(<{7}|>{7})( |$)|^\+={7}$' <<<"$added" || true)
    [[ -z "$markers" ]] || block "conflict markers in $range"$'\n'"$markers"
    pass "artifact scan $range"
    findings=$(rg -n 'System\.out|console\.log|// DEBUG|\bprint\(' <<<"$added" || true)
    [[ -z "$findings" ]] || printf 'REVIEW debug-like lines; remove leftovers, keep intended output:\n%s\n' "$findings"
    ;;
  pcs)
    # Runs each PC's Check in a plan (../skills/dev/design-feature.md#6-finish)
    # in one batch, in --cwd (default here), or only the PCs named.
    [[ $# -ge 2 ]] || usage
    plan="$2"; shift 2
    cwd=.; only=" "
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --cwd) [[ $# -ge 2 ]] || usage; cwd="$2"; shift 2 ;;
        PC-[1-9]*) only+="$1 "; shift ;;
        *) usage ;;
      esac
    done
    [[ -f "$plan" && -r "$plan" ]] || block "plan not found: $plan"
    [[ -d "$cwd" ]] || block "no directory: $cwd"
    # "<id> TAB <command>" per PC declared under ## Implementation Steps,
    # outside fences; the command is the text after "Check:", unwrapped from
    # one pair of backticks.
    pcs=$(LC_ALL=C awk '
      /^[[:space:]]*(```|~~~)/ { fenced = !fenced; next }
      fenced { next }
      /^## / { sec = substr($0, 4); sub(/[[:space:]]+$/, "", sec); next }
      sec != "Implementation Steps" { next }
      {
        lead = $0; sub(/^[[:space:]]*([-*][[:space:]]*)?/, "", lead)
        if (!match(lead, /^PC-[1-9][0-9]*/) || substr(lead, RLENGTH + 1, 1) ~ /[A-Za-z0-9_]/) next
        id = substr(lead, 1, RLENGTH)
        at = index(lead, "Check:"); cmd = at ? substr(lead, at + 6) : ""
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", cmd)
        if (cmd ~ /^`[^`]*`/) { cmd = substr(cmd, 2); cmd = substr(cmd, 1, index(cmd, "`") - 1) }
        printf "%s\t%s\n", id, cmd
      }' "$plan")
    if [[ -z "$pcs" && "$only" == " " ]]; then printf 'PASS no PCs\n'; exit 0; fi
    failed=0; ran=0
    while IFS=$'\t' read -r id cmd; do
      [[ "$only" == " " || "$only" == *" $id "* ]] || continue
      ran=1
      if [[ -z "$cmd" ]]; then printf 'FAIL %s: no Check command\n' "$id"; failed=1; continue; fi
      code=0
      out=$(cd "$cwd" && timeout 120 bash -c "$cmd" </dev/null 2>&1) || code=$?
      if (( code == 0 )); then printf 'PASS %s: %s\n' "$id" "$cmd"
      else
        failed=1
        printf 'FAIL %s (exit %s): %s\n' "$id" "$code" "$cmd"
        [[ -z "$out" ]] || tail -n 5 <<<"$out" | sed 's/^/  /'
      fi
    done <<<"$pcs"
    (( ran )) || block "none of the named PCs is in $plan"
    for id in $only; do
      grep -q "^$id"$'\t' <<<"$pcs" || { printf 'FAIL %s: not in %s\n' "$id" "$plan"; failed=1; }
    done
    (( ! failed )) || exit 1
    ;;
  *) usage ;;
esac
