#!/usr/bin/env bash
# Read an existing collector report; never invoke cloud or cluster clients.
set -euo pipefail

usage() {
  printf '%s\n' \
    'Usage: bash gke-report.sh hypothesis REPORT HYPOTHESIS' \
    '       bash gke-report.sh verdicts REPORT' \
    '       bash gke-report.sh --help' \
    '' \
    'hypothesis: print matching section headers and bodies (B1, G1, H1..H16).' \
    'verdicts: print every line containing the literal marker [VERDICT:.' \
    'REPORT must be an existing readable regular file.' \
    'Exit status: 0 success; 1 no verdict lines; 2 invalid input.' \
    'A hypothesis with no matching sections returns success with empty output.'
}

fail() {
  printf 'gke-report.sh: %s\n' "$1" >&2
  exit 2
}

[[ $# -gt 0 ]] || fail 'missing mode; use --help for usage'
mode=$1
shift
case "$mode" in
  --help)
    [[ $# == 0 ]] || fail '--help takes no arguments'
    usage
    exit 0
    ;;
  hypothesis)
    [[ $# == 2 ]] || fail 'hypothesis requires REPORT and HYPOTHESIS'
    [[ $2 =~ ^(B1|G1|H[1-9]|H1[0-6])$ ]] || fail 'HYPOTHESIS must be B1, G1, or H1..H16'
    ;;
  verdicts)
    [[ $# == 1 ]] || fail 'verdicts requires REPORT'
    ;;
  *) fail "unknown mode: $mode" ;;
esac

report=$1
[[ -f "$report" && -r "$report" ]] || fail "report is not a readable regular file: $report"

case "$mode" in
  hypothesis)
    awk -v h="$2" '/^===== /{f=($0 ~ ("[{ ]" h "[ }]"))} f' < "$report"
    ;;
  verdicts)
    grep -F '[VERDICT:' < "$report"
    ;;
esac
