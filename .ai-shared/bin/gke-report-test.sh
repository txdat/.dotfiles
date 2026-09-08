#!/usr/bin/env bash
# Offline regression tests; the helper's PATH contains only its text-processing tools.
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
helper="$script_dir/gke-report.sh"
test_dir=$(mktemp -d -t gke-report-test.XXXXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
mkdir "$test_dir/bin"
ln -s "$(command -v awk)" "$test_dir/bin/awk"
ln -s "$(command -v grep)" "$test_dir/bin/grep"
bash_path=$(command -v bash)
report="$test_dir/report with spaces.txt"
printf '%s\n' \
  'preamble' \
  '===== Memory =====  {HYP: H1}' \
  'memory evidence' \
  '[VERDICT: H1] CLEAR' \
  '===== Deletes =====  {HYP: H14}' \
  'delete evidence' \
  '[VERDICT: H14] FIRES-WARNING' \
  '===== Shared =====  {HYP: H14 H1}' \
  'shared evidence' \
  '===== Untagged =====' \
  'unrelated evidence' > "$report"

run_helper() {
  PATH="$test_dir/bin" "$bash_path" "$helper" "$@"
}

expect_failure() {
  local expected_status=$1
  shift
  local status=0
  run_helper "$@" > "$test_dir/out" 2> "$test_dir/err" || status=$?
  if [[ "$status" != "$expected_status" || ! -s "$test_dir/err" ]]; then
    printf 'FAIL: expected status %s and diagnostic for %s (got %s)\n' \
      "$expected_status" "$*" "$status" >&2
    exit 1
  fi
}

actual=$(run_helper hypothesis "$report" H1)
expected=$'===== Memory =====  {HYP: H1}\nmemory evidence\n[VERDICT: H1] CLEAR\n===== Shared =====  {HYP: H14 H1}\nshared evidence'
[[ "$actual" == "$expected" ]] || { printf 'FAIL: H1 selection\n' >&2; exit 1; }

actual=$(run_helper hypothesis "$report" H14)
expected=$'===== Deletes =====  {HYP: H14}\ndelete evidence\n[VERDICT: H14] FIRES-WARNING\n===== Shared =====  {HYP: H14 H1}\nshared evidence'
[[ "$actual" == "$expected" ]] || { printf 'FAIL: H14 selection\n' >&2; exit 1; }

actual=$(run_helper verdicts "$report")
[[ "$actual" == $'[VERDICT: H1] CLEAR\n[VERDICT: H14] FIRES-WARNING' ]] || {
  printf 'FAIL: verdict selection\n' >&2; exit 1;
}
[[ -z "$(run_helper hypothesis "$report" H16)" ]]
for hypothesis in B1 G1; do
  [[ -z "$(run_helper hypothesis "$report" "$hypothesis")" ]]
done
printf 'no verdicts\n' > "$test_dir/empty.txt"
status=0
run_helper verdicts "$test_dir/empty.txt" > "$test_dir/out" || status=$?
[[ "$status" == 1 && ! -s "$test_dir/out" ]]
expect_failure 2 hypothesis "$test_dir/missing.txt" H1
expect_failure 2 verdicts "$test_dir"
expect_failure 2 hypothesis "$report" 'H1|H14'
expect_failure 2 hypothesis "$report" H17
expect_failure 2 hypothesis "$report"
expect_failure 2 verdicts "$report" extra
expect_failure 2 unknown "$report"
expect_failure 2
run_helper --help > "$test_dir/help"
[[ -s "$test_dir/help" ]]

# Relative option-like and awk-assignment-like filenames remain filenames.
cp "$report" "$test_dir/-report"
cp "$report" "$test_dir/input=report"
(
  cd "$test_dir"
  [[ "$(run_helper verdicts -report)" == "$(run_helper verdicts "$report")" ]]
  [[ "$(run_helper hypothesis input=report H1)" == "$(run_helper hypothesis "$report" H1)" ]]
)
printf 'PASS: GKE report filters, validation, paths, and offline execution\n'
