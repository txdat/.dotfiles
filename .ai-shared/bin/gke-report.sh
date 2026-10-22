#!/usr/bin/env bash
# Read an existing collector report; never invoke cloud or cluster clients.
set -euo pipefail

usage() {
  printf '%s\n' \
    'Usage: bash gke-report.sh overview REPORT' \
    '       bash gke-report.sh verdicts REPORT' \
    '       bash gke-report.sh hypothesis REPORT HYPOTHESIS [HYPOTHESIS...]' \
    '       bash gke-report.sh --help' \
    '' \
    'overview: print Pre-Flight, Phase 0/0b, Auto-discovery sections and all [VERDICT: lines.' \
    'verdicts: print every line containing the literal marker [VERDICT:.' \
    'hypothesis: print matching section headers and bodies (B1, G1, H1..H16) without duplicates.' \
    'REPORT must be an existing readable regular file.' \
    'Exit status: 0 success; 1 no verdict lines (verdicts mode); 2 invalid input.' \
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
    [[ $# -ge 2 ]] || fail 'hypothesis requires REPORT and at least one HYPOTHESIS'
    for h in "${@:2}"; do
      [[ $h =~ ^(B1|G1|H[1-9]|H1[0-6])$ ]] || fail 'HYPOTHESIS must be B1, G1, or H1..H16'
    done
    ;;
  overview|verdicts)
    [[ $# == 1 ]] || fail "$mode requires REPORT"
    ;;
  *) fail "unknown mode: $mode" ;;
esac

report=$1
[[ -f "$report" && -r "$report" ]] || fail "report is not a readable regular file: $report"

case "$mode" in
  overview)
    awk '
      /^===== / {
        f = ($0 ~ /^===== (Pre-Flight|Phase 0|Auto-discovery)/)
      }
      f { print; next }
      index($0, "[VERDICT:") { verdicts[++n] = $0 }
      END {
        if (n > 0) {
          print "\n===== Detector Verdicts ====="
          for (i = 1; i <= n; i++) print verdicts[i]
        }
      }
    ' < "$report"
    ;;
  hypothesis)
    shift
    hyps="$*"
    awk -v hs="$hyps" '
      BEGIN { n = split(hs, a, " ") }
      /^===== / {
        f = 0
        for (i = 1; i <= n; i++) {
          if ($0 ~ ("[{ ]" a[i] "[ }]")) { f = 1; break }
        }
      }
      f
    ' < "$report"
    ;;
  verdicts)
    grep -F '[VERDICT:' < "$report"
    ;;
esac
