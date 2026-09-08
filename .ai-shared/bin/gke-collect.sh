#!/usr/bin/env bash
# gke-collect.sh — single-pass, read-only evidence collector for the gke-inspect-incident skill.
#
# Collects incident evidence under tagged section headers. Interpretation lives in
# skills/gke/diagnostics.md; inspect-incident.md owns the investigation workflow.
# Nothing here mutates cluster or project state.
#
# Usage:
#   export GCP_PROJECT_ID=... GKE_CLUSTER=... GKE_REGION=... GKE_NAMESPACE=... GKE_SERVICES=...
#   bash gke-collect.sh                    # full read-only sweep, does NOT touch kubeconfig
#   bash gke-collect.sh --get-credentials   # also runs `gcloud container clusters get-credentials`
#                                           # (mutates local kubeconfig — confirm with the user first)
#
# All evidence is written to a report file (default /tmp/gke-incident-<cluster>-<ts>.txt,
# override with $REPORT); the terminal only shows the path. The agent then reads that file.
#
# Optional overrides: PROJECT/CLUSTER/REGION/NAMESPACE/SERVICES, T_USER/T_DURATION/T_TZ,
# NODE_DELETE_BURST/NOTREADY_MAX/AGE_RESET_FRAC/PENDING_GRACE_MIN/T_CRITICAL_LOOKBACK, POD_NAME,
# LB_NAME/LB_BACKEND_NAME, LB_LOG_LIMIT, REPORT.
set -uo pipefail  # NOT -e: one failed/empty query must not abort the sweep

# section "<title>" ["<extra hyp ids>"]
# Header carries machine-greppable {HYP: ...} tags for fast per-hypothesis retrieval.
# Tags are auto-derived from ids in the title (B1, H1..H15); pass a second arg to add
# ids for sweep sections whose data feeds a hypothesis not named in their title.
section() {
  local title="$1" extra="${2:-}" hyps
  hyps=$(printf '%s %s\n' "$title" "$extra" \
         | grep -oiE '\b(B1|G1|H1[0-6]|H[1-9])\b' | tr 'a-z' 'A-Z' | sort -uV | paste -sd' ' -)
  if [ -n "$hyps" ]; then
    printf '\n===== %s =====  {HYP: %s}\n' "$title" "$hyps"
  else
    printf '\n===== %s =====\n' "$title"
  fi
}
note()    { printf '[NOTE] %s\n' "$1"; }
manual()  { printf '[MANUAL: Cloud Console Metrics Explorer — MQL]\n%s\n' "$1"; }

# mon_ts <metric.type> <resource.type> <label-prefix>
# Reads Cloud Monitoring time series over the symptom window and emits TSV:
#   <alignment endTime>  <backend_target_name>  <forwarding_rule_name>  <response_code>  <count>
#
# Deliberately UNSCOPED: the filter names only the metric and resource type, and the namespace
# scoping happens in awk downstream. Three reasons. (1) A real project can have 40+ backend services
# matching a namespace, and an inline one_of(...) of those names is a multi-kilobyte GET URL.
# (2) It keeps every label-name guess out of the *filter*, where a mistake returns 400 and reads as
# "no data" — a false all-clear. (3) It lets the caller compare in-scope backends against their
# siblings, which is the "one service dead vs the whole cluster" discriminator; a server-side filter
# throws that comparison away.
# On API failure it emits a single "ERROR<TAB><message>" line and returns 1, so the caller can tell
# "unreadable" (UNKNOWN) apart from "readable and empty" — the same distinction Phase 0b enforces
# everywhere else.
#
# Why this exists: `gcloud monitoring` has no `time-series` subcommand, so the v3 REST API is the
# only CLI-reachable path to LB *metrics*. Metrics matter here because LB request LOGS are subject
# to the backend service's logConfig sampleRate AND to any logging exclusion filter on the project
# — and excluding health/polling endpoints from LB logs is a common cost measure. Such an exclusion
# silently removes both 5xx and successes from the log-derived counts, so the log read can report
# far fewer errors than actually occurred (or none). The metric is emitted by the LB itself, before
# logging, so it is unaffected by sampling and exclusions and is the authoritative 5xx count.
#
# <label-prefix> is "label" or "labels": Monitoring's filter grammar documents the singular
# `resource.label.<key>`, but the plural is widely accepted too, and getting it wrong is a 400 that
# would read as "no data" — i.e. a false all-clear. The caller tries both rather than betting on one.
# (Note this applies only to the REQUEST; the TimeSeries response proto is always plural, so the jq
# extraction below is fixed at `.resource.labels` / `.metric.labels`.)
mon_ts() {
  local mt="$1" rt="$2" lp="$3" token="" page=0 resp err filter
  filter="metric.type=\"$mt\" AND resource.type=\"$rt\""
  while :; do
    local args=(
      -H "Authorization: Bearer $MON_TOKEN"
      --data-urlencode "filter=$filter"
      --data-urlencode "interval.startTime=$T_START"
      --data-urlencode "interval.endTime=$T_END"
      --data-urlencode "aggregation.alignmentPeriod=60s"
      --data-urlencode "aggregation.perSeriesAligner=ALIGN_DELTA"
      --data-urlencode "aggregation.crossSeriesReducer=REDUCE_SUM"
      --data-urlencode "aggregation.groupByFields=resource.$lp.backend_target_name"
      --data-urlencode "aggregation.groupByFields=resource.$lp.forwarding_rule_name"
      --data-urlencode "aggregation.groupByFields=metric.$lp.response_code"
    )
    [ -n "$token" ] && args+=(--data-urlencode "pageToken=$token")
    if ! resp=$(curl -sS --get "${args[@]}" \
      "https://monitoring.googleapis.com/v3/projects/$PROJECT/timeSeries" 2>/dev/null); then
      printf 'ERROR\tMonitoring transport failed for %s\n' "$mt"
      return 1
    fi
    err=$(printf '%s' "$resp" | jq -r '.error.message // ""' 2>/dev/null)
    # An empty body or a non-JSON one (proxy/HTML error page, curl failure) leaves $err empty and
    # extracts to zero rows — indistinguishable from a genuine "no traffic" unless caught here.
    # A successful call always returns a JSON object, even when it holds no time series.
    if [ -z "$err" ] && ! printf '%s' "$resp" | jq -e 'type == "object"' >/dev/null 2>&1; then
      err="unparseable or empty response from the Monitoring API (not a JSON object)"
    fi
    if [ -n "$err" ]; then
      printf 'ERROR\t%s\n' "$err"
      return 1
    fi
    printf '%s' "$resp" | jq -r '
      .timeSeries[]? as $s | $s.points[]? |
      [ .interval.endTime,
        ($s.resource.labels.backend_target_name // ""),
        ($s.resource.labels.forwarding_rule_name // ""),
        ($s.metric.labels.response_code // ""),
        (.value.int64Value // .value.doubleValue // 0) ] | @tsv' 2>/dev/null
    token=$(printf '%s' "$resp" | jq -r '.nextPageToken // ""' 2>/dev/null)
    page=$((page + 1))
    [ -z "$token" ] && break
    # Bail out rather than page forever, but SAY so: silently truncated totals would understate the
    # 5xx count, which is the one failure mode this whole section exists to eliminate.
    if [ "$page" -ge 20 ]; then printf '#TRUNC\n'; break; fi
  done
  return 0
}

# Tri-state verdict — grep -F '[VERDICT:' for a one-line summary of every detector.
#   FIRES-CRITICAL / FIRES-WARNING = signal present (still needs corroboration before RCA)
#   CLEAR   = data source was readable AND the condition did not hold (a real negative)
#   UNKNOWN = the data source was unreadable (auth/IAM/context/log gap) — CANNOT rule out
#   INFO    = condition held but a benign cause (planned op / recovered state) explains it
verdict() { printf '[VERDICT: %s] %s\n' "$1" "$2"; }

# Container operations for THIS cluster only, as TAB-separated
# <operationType> <status> <startTime> <endTime>.
#
# Two reasons this is not a bare `gcloud container operations list`:
# (1) The API is LOCATION-scoped, not cluster-scoped. An unrelated cluster's REPAIR_CLUSTER in the
#     same location would fire H13 (false positive) AND downgrade a real H14/H15 reclamation to INFO
#     via the planned-op guard (false negative) — one call producing both error directions.
#     targetLink is .../clusters/<cluster>[/nodePools/<pool>], so scope on that.
# (2) `value()` emits TABs and a RUNNING op has an EMPTY endTime. Under awk's default FS that empty
#     field collapses and targetLink slides into $4, so every consumer must split on TAB.
# If no row carries a targetLink at all, fall back to unscoped rather than silently reporting
# nothing (a false CLEAR), and say so.
cluster_ops() {
  gcloud container operations list --project="$PROJECT" --location="$REGION" \
    --format="value(operationType,status,startTime,endTime,targetLink)" 2>/dev/null \
  | awk -F'\t' -v cl="$CLUSTER" '
      { rows++; row[rows] = $1 FS $2 FS $3 FS $4
        if ($5 != "") linked++
        if ($5 ~ ("/clusters/" cl "(/|$)")) sel[rows] = 1 }
      END {
        if (rows == 0) exit
        if (linked == 0) {
          print "[WARNING] container operations carry no targetLink — H13 and the planned-op guard are NOT scoped to cluster " cl "; another cluster in this location can fire or mask them." > "/dev/stderr"
          for (i = 1; i <= rows; i++) print row[i]
        } else for (i = 1; i <= rows; i++) if (i in sel) print row[i]
      }'
}

# Planned/benign GKE ops overlapping the critical window — used as false-positive guards for
# H13/H14/H15 (a delete/rebuild during a planned resize/upgrade/repair is intentional cycling,
# not reclamation). Overlap = op started before window end AND (still running OR ended after start).
planned_ops_in_window() {
  cluster_ops \
  | awk -F'\t' -v s="$T_START_CRITICAL" -v e="$T_END" \
      '($1=="SET_NODE_POOL_SIZE" || $1 ~ /^UPGRADE/ || $1=="REPAIR_CLUSTER") \
       && $3<=e && ($4=="" || $4>=s) { print $1"@"$3 }'
}

GET_CREDENTIALS=0
[ "${1:-}" = "--get-credentials" ] && GET_CREDENTIALS=1

# ============================================================================
# Pre-Flight — resolve inputs (mirrors inspect-incident.md Pre-Flight exactly)
# ============================================================================
PROJECT="${PROJECT:-${GCP_PROJECT_ID:-}}"
CLUSTER="${CLUSTER:-${GKE_CLUSTER:-}}"
REGION="${REGION:-${GKE_REGION:-}}"
NAMESPACE="${NAMESPACE:-${GKE_NAMESPACE:-}}"
SERVICES="${SERVICES:-${GKE_SERVICES:-}}"
T_DURATION="${T_DURATION:-now}"
T_TZ="${T_TZ:-Asia/Ho_Chi_Minh}"

MISSING=0
for v in PROJECT CLUSTER REGION NAMESPACE SERVICES; do
  if [ -z "${!v:-}" ]; then
    echo "MISSING: $v — provide it or export its \$GCP_*/\$GKE_* default"
    MISSING=1
  fi
done
[ "$MISSING" = "1" ] && { echo "Aborting: resolve missing inputs and re-run."; exit 1; }

# Warn (don't abort) on missing tooling — a gcloud-only or kubectl-only run still yields
# partial evidence, but the operator should know why whole sections come back empty.
for bin in gcloud kubectl jq curl; do   # curl+jq back the Cloud Monitoring LB-metric read (1d.2m)
  command -v "$bin" >/dev/null 2>&1 || echo "WARNING: '$bin' not on PATH — sections needing it will be empty."
done

SVC_RE=$(printf '%s\n' "${SERVICES//,/$'\n'}" | while read -r s; do
  s="${s//[[:space:]]/}"; [ -z "$s" ] && continue
  case "$s" in
    *\*) printf '^%s|' "${s%\*}" ;;
    *)   printf '^%s-|' "$s" ;;
  esac
done | sed 's/|$//')
SERVICE="${SERVICE:-$(printf '%s' "${SERVICES%%,*}" | tr -d ' *')}"
DEPLOYMENT="${DEPLOYMENT:-$SERVICE}"

if [ -n "${T_USER:-}" ]; then
  T_UTC=$(TZ=UTC date -d "TZ=\"$T_TZ\" $T_USER" +%Y-%m-%dT%H:%M:%SZ)
else
  T_UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)
fi
# The skill documents the duration grammar \d+(s|m|h|d) — but `date -d` does not understand a bare
# "20m"/"2h", it needs "20 minutes"/"2 hours". Left untranslated, `date` returns empty, T_END goes
# blank, and every windowed query dies with INVALID_ARGUMENT while the report still prints section
# headers as if it had run. Translate the documented grammar; pass anything else through unchanged
# so "90 minutes" and other date-native phrasings keep working.
norm_duration() {
  case "$1" in
    *[0-9]s) printf '%s seconds' "${1%s}" ;;
    *[0-9]m) printf '%s minutes' "${1%m}" ;;
    *[0-9]h) printf '%s hours'   "${1%h}" ;;
    *[0-9]d) printf '%s days'    "${1%d}" ;;
    *)       printf '%s' "$1" ;;
  esac
}

T_SYMPTOM_LOOKBACK="$(norm_duration "${T_SYMPTOM_LOOKBACK:-30m}")"
T_CHANGE_LOOKBACK="$(norm_duration "${T_CHANGE_LOOKBACK:-2h}")"
T_CRITICAL_LOOKBACK="$(norm_duration "${T_CRITICAL_LOOKBACK:-6h}")"

T_START=$(date -u -d "$T_UTC - $T_SYMPTOM_LOOKBACK" +%Y-%m-%dT%H:%M:%SZ)

if [ -z "$T_DURATION" ] || [ "$T_DURATION" = "now" ]; then
  T_END=$(date -u +%Y-%m-%dT%H:%M:%SZ)
else
  T_END=$(date -u -d "$T_UTC + $(norm_duration "$T_DURATION") + 10 minutes" +%Y-%m-%dT%H:%M:%SZ)
fi

T_START_MINUS_2H=$(date -u -d "$T_UTC - $T_CHANGE_LOOKBACK" +%Y-%m-%dT%H:%M:%SZ)
T_START_CRITICAL=$(date -u -d "$T_UTC - $T_CRITICAL_LOOKBACK" +%Y-%m-%dT%H:%M:%SZ)

# A blank timestamp poisons every query downstream but leaves the report looking populated —
# fail loudly here instead.
for tv in T_START T_END T_START_MINUS_2H T_START_CRITICAL; do
  if [ -z "${!tv:-}" ]; then
    echo "Aborting: $tv is empty — a duration input could not be parsed by 'date'." >&2
    echo "  T_USER='${T_USER:-<now>}' T_DURATION='${T_DURATION:-now}' T_SYMPTOM_LOOKBACK='$T_SYMPTOM_LOOKBACK' T_CHANGE_LOOKBACK='$T_CHANGE_LOOKBACK' T_CRITICAL_LOOKBACK='$T_CRITICAL_LOOKBACK'" >&2
    exit 1
  fi
done
NODE_DELETE_BURST="${NODE_DELETE_BURST:-3}"
NOTREADY_MAX="${NOTREADY_MAX:-2}"
AGE_RESET_FRAC="${AGE_RESET_FRAC:-0.5}"
PENDING_GRACE_MIN="${PENDING_GRACE_MIN:-10}"   # H16: minutes a pod may sit Pending awaiting scale-up before CRITICAL
LB_LOG_LIMIT="${LB_LOG_LIMIT:-5000}"           # 1d.2: max LB log entries read for the 5xx-ratio aggregation

# All collected evidence goes to a single report file the agent then reads; only the
# path (and any fatal pre-flight error above) reaches the terminal. Override with $REPORT.
REPORT="${REPORT:-/tmp/gke-incident-${CLUSTER}-$(date -u +%Y%m%dT%H%M%SZ).txt}"
# The report carries app logs, IAM bindings, SA identities and deployment env — create it 0600
# rather than leaving it world-readable in a shared /tmp under the usual umask 022.
( umask 077 && : >"$REPORT" ) 2>/dev/null || true
exec 3>&1                 # fd 3 = real terminal
echo "gke-collect: writing report to $REPORT" >&3
exec >"$REPORT" 2>&1      # stdout+stderr of the sweep now land in the report file

section "Pre-Flight — Resolved Inputs"
# $REGION is used as the --region/--location for every cluster-scoped gcloud call. If the caller
# passes a zone for a regional cluster (or vice-versa) those calls 404 one by one and their
# detectors silently look "empty" rather than UNKNOWN. Ask GKE where the cluster actually lives
# and correct the value once, here, instead of losing 1f.7/1g.4/1g.5/H13 to a typo.
REGION_INPUT="$REGION"
CLUSTER_LOCATION=$(gcloud container clusters describe "$CLUSTER" --project="$PROJECT" \
  --location="$REGION" --format="value(location)" 2>/dev/null)
if [ -z "$CLUSTER_LOCATION" ]; then
  CLUSTER_LOCATIONS=$(gcloud container clusters list --project="$PROJECT" \
    --filter="name=$CLUSTER" --format="value(location)" 2>/dev/null)
  # A name can occur in several locations. Correct a typo only when the name is unique.
  if [ "$(printf '%s\n' "$CLUSTER_LOCATIONS" | awk 'NF {n++} END {print n+0}')" = 1 ]; then
    CLUSTER_LOCATION="$CLUSTER_LOCATIONS"
  fi
fi
if [ -n "$CLUSTER_LOCATION" ] && [ "$CLUSTER_LOCATION" != "$REGION" ]; then
  REGION="$CLUSTER_LOCATION"
  echo "[WARNING] REGION corrected: input '$REGION_INPUT' is not where '$CLUSTER' lives — GKE reports location '$CLUSTER_LOCATION'. Using the reported location for all cluster-scoped calls. Fix \$GKE_REGION to '$CLUSTER_LOCATION' to silence this."
elif [ -z "$CLUSTER_LOCATION" ]; then
  echo "[WARNING] Could not resolve '$CLUSTER' location via 'gcloud container clusters list' (permission or wrong name?) — proceeding with the supplied REGION='$REGION' unverified. Cluster-scoped sections that come back empty may be 404s, not clean results."
fi
# A GKE location is a REGION for a regional cluster and a ZONE for a zonal one; the skill documents
# both, and the correction above can itself hand us a zone. `gcloud container` accepts either via
# --location, but compute/redis are region-scoped and 404 on a zone — which surfaced as CAP_COMPUTE=0
# and an empty 1g.4 quota block, i.e. a missing-permission story for a supported topology. Derive the
# enclosing region once (a zone is "<region>-<letter>").
case "$REGION" in
  *-*-[a-z]) REGION_ONLY="${REGION%-*}" ;;
  *)         REGION_ONLY="$REGION" ;;
esac
echo "PROJECT=$PROJECT CLUSTER=$CLUSTER REGION=$REGION (location; enclosing region $REGION_ONLY) NAMESPACE=$NAMESPACE"
echo "Services=$SERVICES  SVC_RE=$SVC_RE  primary=$SERVICE  deployment=$DEPLOYMENT"
echo "T_START=$T_START  T_END=$T_END"
echo "T_START_MINUS_2H=$T_START_MINUS_2H  T_START_CRITICAL=$T_START_CRITICAL ($T_CRITICAL_LOOKBACK)"
echo "Thresholds: NODE_DELETE_BURST=$NODE_DELETE_BURST NOTREADY_MAX=$NOTREADY_MAX AGE_RESET_FRAC=$AGE_RESET_FRAC PENDING_GRACE_MIN=$PENDING_GRACE_MIN LB_LOG_LIMIT=$LB_LOG_LIMIT"
note "Fast retrieval — every section header is tagged {HYP: ...}. To read all blocks for one"
note "  hypothesis (e.g. H14), print each tagged section up to the next '=====':"
note "    awk -v h=H14 '/^===== /{f=(\$0 ~ (\"[{ ]\" h \"[ }]\"))} f' \"\$REPORT\""
note "  Or just locate them:  grep -nE '\\{HYP:[^}]*[{ ]H14[ }]' \"\$REPORT\""
note "Verdicts — grep -F '[VERDICT:' for every detector's state: FIRES-CRITICAL/FIRES-WARNING (signal,"
note "  needs corroboration), CLEAR (real negative), UNKNOWN (source unreadable — do NOT treat as clear),"
note "  INFO (fired but a planned op / recovered state explains it). Never call UNKNOWN a pass."

# ============================================================================
# Phase 0 — Auth (gated; kubeconfig mutation only with --get-credentials)
# ============================================================================
section "Phase 0 — Auth Validation"
gcloud auth list --filter="status:ACTIVE" --format="value(account)"
gcloud config get-value project
if [ "$GET_CREDENTIALS" = "1" ]; then
  gcloud container clusters get-credentials "$CLUSTER" --location "$REGION" --project "$PROJECT"
else
  note "Skipped 'gcloud container clusters get-credentials' (mutates local kubeconfig). Re-run with --get-credentials after confirming with the user, or run it manually if the current context doesn't already target $CLUSTER."
fi
kubectl config current-context 2>/dev/null
kubectl cluster-info --request-timeout=5s 2>/dev/null

# ============================================================================
# Phase 0b — Capability Preflight — which data sources can we actually read?
# A detector whose source is UNREADABLE must report UNKNOWN, never CLEAR: an empty
# query result under a missing permission looks identical to a real all-clear.
# ============================================================================
section "Phase 0b — Capability Preflight (empty ≠ clear)"
gcloud logging read 'timestamp>="'$T_START'"' --project="$PROJECT" --limit=1 --format='value(timestamp)' >/dev/null 2>&1 \
  && CAP_LOGGING=1 || CAP_LOGGING=0
gcloud compute regions describe "$REGION_ONLY" --project="$PROJECT" --format='value(name)' >/dev/null 2>&1 \
  && CAP_COMPUTE=1 || CAP_COMPUTE=0
gcloud container operations list --project="$PROJECT" --location="$REGION" --limit=1 >/dev/null 2>&1 \
  && CAP_OPS=1 || CAP_OPS=0
BILLING_NOW=$(gcloud billing projects describe "$PROJECT" --format='value(billingEnabled)' 2>/dev/null) \
  && CAP_BILLING=1 || CAP_BILLING=0    # one call: capture current state and readability together
# Cloud Monitoring read (LB request_count metric — the authoritative 5xx signal, see mon_ts).
# Probe with a cheap metricDescriptors call rather than a time-series read.
CAP_MONITORING=0
MON_TOKEN=""
if command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  MON_TOKEN=$(gcloud auth print-access-token 2>/dev/null)
  if [ -n "$MON_TOKEN" ]; then
    curl -sS --get -H "Authorization: Bearer $MON_TOKEN" \
      --data-urlencode 'filter=metric.type="loadbalancing.googleapis.com/https/request_count"' \
      "https://monitoring.googleapis.com/v3/projects/$PROJECT/metricDescriptors" 2>/dev/null \
      | jq -e '.error | not' >/dev/null 2>&1 && CAP_MONITORING=1
  fi
fi
if kubectl cluster-info --request-timeout=5s >/dev/null 2>&1; then CAP_KUBECTL=1; else CAP_KUBECTL=0; fi
CUR_CTX=$(kubectl config current-context 2>/dev/null)
EXPECTED_CTX="gke_${PROJECT}_${REGION}_${CLUSTER}"
[ "$CUR_CTX" = "$EXPECTED_CTX" ] && CAP_KUBECTL_CTX=1 || CAP_KUBECTL_CTX=0
[ "$CAP_KUBECTL" = 1 ] && [ "$CAP_KUBECTL_CTX" = 1 ] && CAP_K8S=1 || CAP_K8S=0
# Bind every resource read to the verified context even if another process changes the default.
kube_read() {
  [ "$CAP_K8S" = 1 ] || return 1
  kubectl --context="$EXPECTED_CTX" "$@"
}
echo "CAP_LOGGING=$CAP_LOGGING (Cloud Logging read: log-based detectors B1/H13-partial/H14/H1-H12 audit)"
echo "CAP_COMPUTE=$CAP_COMPUTE (Compute read: quota 1g.4, node instance-id, stockout)"
echo "CAP_OPS=$CAP_OPS (container operations: H13 ops, planned-op guards)"
echo "CAP_MONITORING=$CAP_MONITORING (Cloud Monitoring read: LB request_count metric — authoritative G1 5xx counts + true denominator, 1d.2m)"
echo "CAP_BILLING=$CAP_BILLING (Cloud Billing read: B1 current-state guard)  billingEnabled_now=${BILLING_NOW:-<unreadable>}"
echo "CAP_KUBECTL=$CAP_KUBECTL  CAP_KUBECTL_CTX=$CAP_KUBECTL_CTX (context '$CUR_CTX' targets '$CLUSTER'?)  CAP_K8S=$CAP_K8S (live kubectl detectors H1/H2/H5/H15/H16)"
[ "$CAP_LOGGING" = 0 ] && verdict UNKNOWN "Cloud Logging unreadable — ALL log-based detectors are UNKNOWN, not CLEAR. Grant roles/logging.viewer (+ privateLogViewer for Data Access) and re-run."
[ "$CAP_K8S" = 0 ] && verdict UNKNOWN "kubectl not targeting $CLUSTER (or unreachable) — live cluster-state detectors are UNKNOWN. Re-run with --get-credentials (after confirming) or fix the context."
[ "$CAP_MONITORING" = 0 ] && verdict UNKNOWN "Cloud Monitoring unreadable (needs curl+jq, a token, and roles/monitoring.viewer) — the authoritative LB 5xx metric (1d.2m) cannot run, so G1 rests on LB logs alone, which a logging exclusion filter can gut. Grant roles/monitoring.viewer and re-run before trusting a low/zero 5xx count."

# ============================================================================
# Auto-discovery — read-only, feeds Phase 3 deep-dives
# ============================================================================
section "Auto-discovery"
POD_SELECTOR_RAW=$(kube_read get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.spec.selector.matchLabels}' 2>/dev/null)
POD_SELECTOR=$(kube_read get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o json 2>/dev/null | \
  jq -r '.spec.selector.matchLabels | to_entries | map("\(.key)=\(.value)") | join(",")' 2>/dev/null)
[ -z "$POD_SELECTOR" ] || [ "$POD_SELECTOR" = "null" ] && POD_SELECTOR="app=$SERVICE"
echo "POD_SELECTOR=$POD_SELECTOR (raw matchLabels: $POD_SELECTOR_RAW)"

POD_NAME="${POD_NAME:-$(kube_read get pods -n "$NAMESPACE" -l "$POD_SELECTOR" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)}"
echo "POD_NAME=${POD_NAME:-<none found>}"

NODE_NAME=""
NODE_ZONE=""
NODE_INSTANCE_ID=""
if [ -n "$POD_NAME" ]; then
  NODE_NAME=$(kube_read get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.nodeName}' 2>/dev/null)
  # GKE nodes carry no instance_id annotation — derive the numeric GCE id from providerID
  # (gce://PROJECT/ZONE/INSTANCE_NAME; the node name is the instance name).
  PROVIDER_ID=$(kube_read get node "$NODE_NAME" -o jsonpath='{.spec.providerID}' 2>/dev/null)
  NODE_ZONE=$(printf '%s' "$PROVIDER_ID" | awk -F/ '{print $(NF-1)}')
  if [ -n "$NODE_NAME" ] && [ -n "$NODE_ZONE" ]; then
    NODE_INSTANCE_ID=$(gcloud compute instances describe "$NODE_NAME" --zone="$NODE_ZONE" --project="$PROJECT" --format="value(id)" 2>/dev/null || true)
  fi
fi
echo "NODE_NAME=${NODE_NAME:-<none>}  NODE_ZONE=${NODE_ZONE:-<none>}  NODE_INSTANCE_ID=${NODE_INSTANCE_ID:-<none — substitute manually from an eviction event>}"

LB_NAME="${LB_NAME:-}"
LB_BACKEND_NAME="${LB_BACKEND_NAME:-}"
# The fronting LB may be an Ingress OR a Gateway (GKE Gateway API creates forwarding rules with no
# Ingress object at all). Try both before giving up, else 1d.2-1d.5 — the whole 5xx-ratio signal —
# are skipped on every Gateway-fronted cluster.
LB_VIP=$(kube_read get ingress -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.status.loadBalancer.ingress[*].ip}{"\n"}{end}' 2>/dev/null | head -1)
LB_SOURCE="ingress"
if [ -z "$LB_VIP" ]; then
  LB_VIP=$(kube_read get gateway -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.status.addresses[*].value}{"\n"}{end}' 2>/dev/null | head -1)
  [ -n "$LB_VIP" ] && LB_SOURCE="gateway"
fi
if [ -z "$LB_NAME" ] && [ -n "$LB_VIP" ]; then
  LB_NAME=$(gcloud compute forwarding-rules list --project="$PROJECT" --filter="IPAddress=$LB_VIP" --format="value(name)" 2>/dev/null | head -1)
fi
# Backend services owned by THIS namespace's services. Both Ingress (k8s-be/k8s2-be) and Gateway
# (gkegw1-<hash>-<ns>-<svc>-<port>) name their backends after the NEG, and the NEG name always
# carries namespace + service — so match on that, per service. The previous `backend-services
# list | head -1` grabbed whichever backend sorted first in the whole project, which on a shared
# project is another tenant's service entirely.
LB_BACKEND_RE=""
NS_SHORT=$(printf '%s' "$NAMESPACE" | cut -c1-12)   # GKE truncates ns/svc inside generated names
# Hoisted out of the branch below: 1d.2m uses it to decide whether an unrouted request
# ((no-backend-matched)) arrived on THIS namespace's gateway, and that must work even when
# $LB_BACKEND_NAME was supplied by hand and the discovery branch is skipped.
if [ -z "$LB_BACKEND_NAME" ]; then
  LB_BACKENDS=$(gcloud compute backend-services list --project="$PROJECT" \
      --format="value(name,backends[].group)" 2>/dev/null | \
    awk -v ns="$NS_SHORT" -v svcre="$SVC_RE" '
      $0 ~ ns {
        n=split(svcre, pats, "|")
        for (i=1; i<=n; i++) { p=pats[i]; sub(/^\^/, "", p); if (index($0, p)) { print $1; break } }
      }' | sort -u)
  LB_BACKEND_NAME=$(printf '%s\n' "$LB_BACKENDS" | head -1)
  LB_BACKEND_RE=$(printf '%s\n' "$LB_BACKENDS" | paste -sd'|' -)
fi
[ -z "$LB_BACKEND_RE" ] && [ -n "$LB_BACKEND_NAME" ] && LB_BACKEND_RE="$LB_BACKEND_NAME"
echo "LB_VIP=${LB_VIP:-<none>} (source: $LB_SOURCE)"
echo "LB_NAME=${LB_NAME:-<not discovered — see 1d step 1 output below>}  LB_BACKEND_NAME=${LB_BACKEND_NAME:-<not discovered>}"
echo "LB_BACKEND_RE=${LB_BACKEND_RE:-<no backend service matched this namespace + services>}"

# ============================================================================
# Phase 1 — Broad Sweep
# ============================================================================

section "1a — K8s Warning Events (namespaced)" "H2 H3"
gcloud logging read \
  'resource.type="k8s_cluster"
   log_name="projects/'$PROJECT'/logs/events"
   severity>=WARNING
   resource.labels.cluster_name="'$CLUSTER'"
   resource.labels.namespace_name="'$NAMESPACE'"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,jsonPayload.involvedObject.name,jsonPayload.reason,jsonPayload.message)" \
  --limit=300

section "1a — K8s Warning Events (node-scoped)" "H3 H15"
gcloud logging read \
  'resource.type="k8s_cluster"
   log_name="projects/'$PROJECT'/logs/events"
   resource.labels.cluster_name="'$CLUSTER'"
   jsonPayload.reason=~"NodeNotReady|NodeHasInsufficientMemory|NodeHasDiskPressure|NodeHasPIDPressure|EvictionThreshold"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,jsonPayload.involvedObject.name,jsonPayload.reason,jsonPayload.message)" \
  --limit=100

section "1b — Pod Restart Fingerprint" "H1"
kube_read get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.spec.selector.matchLabels}' 2>/dev/null && echo
kube_read get pods -n "$NAMESPACE" -l "$POD_SELECTOR" -o json 2>/dev/null | jq -r '
  .items[] | .metadata.name as $pod |
  .status.containerStatuses[]? |
  [$pod, .name, .ready, .restartCount,
   .lastState.terminated.reason // "-",
   .lastState.terminated.exitCode // "-",
   .lastState.terminated.finishedAt // "-"] | @tsv' | \
  column -t -s $'\t' -N POD,CONTAINER,READY,RESTARTS,REASON,EXIT,FINISHED

section "1c — Endpoint Availability" "H2"
kube_read get endpoints -n "$NAMESPACE"
kube_read describe endpoints -n "$NAMESPACE" 2>/dev/null | grep -A5 -E "^Name:|Addresses:|NotReadyAddresses:"
gcloud logging read \
  'resource.type="k8s_cluster"
   protoPayload.resourceName=~"namespaces/'$NAMESPACE'/endpoints"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,protoPayload.methodName,protoPayload.resourceName,protoPayload.response.status)" \
  --limit=50

section "1d.1 — LB Identification"
gcloud compute forwarding-rules list --project=$PROJECT --format="table(name,IPAddress,target,region,loadBalancingScheme)"
gcloud compute backend-services list --project=$PROJECT --format="table(name,protocol,loadBalancingScheme,backends[].group)"
kube_read get ingress -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.loadBalancer.ingress[*].ip}{"\n"}{end}' 2>/dev/null
kube_read get service "$SERVICE" -n "$NAMESPACE" -o jsonpath='{.metadata.annotations.cloud\.google\.com/neg}' 2>/dev/null && echo
gcloud compute network-endpoint-groups list --project=$PROJECT --format="table(name,zone,size)" 2>/dev/null | grep -i "$SERVICE" || true

LB_LOGGING_ENABLED="false"
if [ -n "$LB_BACKEND_NAME" ]; then
  LB_LOGGING_ENABLED=$(gcloud compute backend-services describe "$LB_BACKEND_NAME" --global --project=$PROJECT --format="value(logConfig.enable)" 2>/dev/null || \
                       gcloud compute backend-services describe "$LB_BACKEND_NAME" --region=$REGION_ONLY --project=$PROJECT --format="value(logConfig.enable)" 2>/dev/null || echo false)
fi
# gcloud prints the boolean as 'True'/'False' (Python repr), so a `= "true"` test never matched and
# 1d.2-1d.5 were skipped even on a correctly-logging LB. Normalise before comparing.
LB_LOGGING_ENABLED=$(printf '%s' "$LB_LOGGING_ENABLED" | tr '[:upper:]' '[:lower:]')
echo "LB_BACKEND_NAME=$LB_BACKEND_NAME  logConfig.enable=$LB_LOGGING_ENABLED"

# Scope the LB log reads by forwarding rule when we know it, else by the backend services owned by
# this namespace. The backend-scoped filter is in fact the *better* denominator on a shared LB: it
# excludes sibling tenants' traffic that would otherwise dilute the 5xx ratio.
LB_FILTER=""
LB_SCOPE=""
if [ -n "$LB_BACKEND_RE" ]; then
  # Prefer the backend-scoped filter: one forwarding rule commonly fronts every namespace in the
  # project (a shared Gateway), so scoping by rule puts other tenants' traffic in the denominator
  # and a service that is 100% down reads as a couple of percent.
  LB_FILTER='resource.labels.backend_service_name=~"'$LB_BACKEND_RE'"'
  LB_SCOPE="backend_service_name (this namespace's services only)"
elif [ -n "$LB_NAME" ]; then
  LB_FILTER='resource.labels.forwarding_rule_name="'$LB_NAME'"'
  LB_SCOPE="forwarding_rule_name=$LB_NAME (WHOLE rule — may include other namespaces/tenants; read the per-backend block, not the window ratio)"
fi
[ -n "$LB_FILTER" ] && echo "LB log scope: $LB_SCOPE"

# The same scope, but applied client-side (see mon_ts). `https_lb_rule`'s backend_target_name IS the
# backend service name, so the metric and log reads cover the same traffic and are comparable.
MON_SCOPE_KIND=""
MON_SCOPE=""
if [ -n "$LB_BACKEND_RE" ]; then
  MON_SCOPE_KIND="backend"
  MON_SCOPE="backend_target_name ∈ {$(printf '%s' "$LB_BACKEND_RE" | tr '|' ' ')} — this namespace's services only"
elif [ -n "$LB_NAME" ]; then
  MON_SCOPE_KIND="rule"
  MON_SCOPE="forwarding_rule_name=$LB_NAME (WHOLE rule — may include other namespaces/tenants; read the per-backend block, not the window ratio)"
fi
[ -n "$MON_SCOPE" ] && echo "LB metric scope: $MON_SCOPE"

# ---------------------------------------------------------------------------
# 1d.2m — the AUTHORITATIVE 5xx read. Runs independently of logConfig.enable, because the whole
# point is that it does not depend on LB logging: neither sampleRate nor a project logging
# exclusion (e.g. one dropping health/polling endpoints) can remove requests from this metric.
# ---------------------------------------------------------------------------
section "1d.2m — LB 5xx from Cloud Monitoring metric (AUTHORITATIVE — counts AND true denominator)" "G1"
if [ -z "$MON_SCOPE_KIND" ]; then
  note "Skipped: no LB scope resolved (no backend service matched this namespace, and no forwarding rule from an Ingress/Gateway VIP). Set \$LB_BACKEND_NAME or \$LB_NAME and re-run. G1 is UNKNOWN, not CLEAR."
  verdict UNKNOWN "G1: LB 5xx metric could not be scoped to this namespace."
elif [ "${CAP_MONITORING:-0}" = 0 ]; then
  note "Skipped: CAP_MONITORING=0 (needs curl, jq, an access token and roles/monitoring.viewer)."
  verdict UNKNOWN "G1: LB 5xx metric unreadable — fall back to 1d.2a/1d.2b logs, but treat their counts as a LOWER BOUND (logging exclusions/sampling remove requests)."
else
  # Query external AND internal ALB and MERGE the results — do not stop at the first that answers.
  # A cluster can front different services with both, and since scoping is now client-side, "this
  # metric returned rows" says nothing about whether any of them are ours. Stopping early on the
  # external metric while the namespace sits behind an internal one would leave in-scope traffic at
  # zero and report "scope is probably wrong" — a false UNKNOWN manufactured by the shortcut.
  # Within each metric, try the singular then the plural label form and keep whichever answers.
  MON_TSV=""; MON_KIND=""; MON_ERR=""; MON_EMPTY_OK=""; MON_TRUNC=0; MON_NL=$'\n'
  for mon_combo in \
    "loadbalancing.googleapis.com/https/request_count|https_lb_rule|external ALB" \
    "loadbalancing.googleapis.com/https/internal/request_count|internal_http_lb_rule|internal ALB"
  do
    IFS='|' read -r mon_mt mon_rt mon_kind <<<"$mon_combo"
    mon_ok=0; mon_error=""
    for mon_lp in label labels; do
      mon_out=$(mon_ts "$mon_mt" "$mon_rt" "$mon_lp")
      if printf '%s' "$mon_out" | grep -q '^ERROR'; then
        mon_error="$mon_out"
        continue                                 # wrong label form (or real failure) — try the twin
      fi
      # This form is accepted; whether it carried points or not, don't retry its twin.
      mon_ok=1
      printf '%s' "$mon_out" | grep -q '^#TRUNC' && MON_TRUNC=1
      mon_out=$(printf '%s' "$mon_out" | grep -v '^#TRUNC') || true
      if [ -n "$mon_out" ]; then
        # Via a variable, NOT an inline $'\n': ANSI-C quoting is not applied inside ${x:+...}, so
        # the literal four characters would be spliced in and the two result sets welded together.
        MON_TSV="${MON_TSV:+$MON_TSV$MON_NL}$mon_out"
        MON_KIND="${MON_KIND:+$MON_KIND + }$mon_kind ($mon_rt, resource.$mon_lp.*)"
      else
        MON_EMPTY_OK="${MON_EMPTY_OK:+$MON_EMPTY_OK, }$mon_kind (accepted, no points)"
      fi
      break
    done
    if [ "$mon_ok" = 0 ]; then
      MON_ERR="${MON_ERR:+$MON_ERR$MON_NL}$mon_kind: $mon_error"
    fi
  done
  MON_COMPLETE=1
  if [ -n "$MON_ERR" ] || [ "$MON_TRUNC" = 1 ]; then MON_COMPLETE=0; fi
  [ "$MON_TRUNC" = 1 ] && note "Paging cap hit: the metric read stopped at 20 pages, so these totals are TRUNCATED and are a lower bound. Narrow the window before quoting any figure."
  echo "metric source: ${MON_KIND:-<none returned data>}   window: $T_START → $T_END   alignment: 60s ALIGN_DELTA"
  echo "note: 60s buckets are anchored to the query END time, not to wall-clock minutes, and are labelled by the bucket's end. So a bucket labelled 10:15 typically covers ~10:14:4x-10:15:4x, and the metric onset can read up to a minute later than the log onset in 1d.2a (which labels by request time). Do not call that a discrepancy."
  echo "note: LB metrics ingest with a delay of up to ~4 minutes, so for an ONGOING incident the last few minutes of the window are undercounted or absent. Judge onset and peak from the middle of the window, not its trailing edge."
  if [ -n "$MON_ERR" ]; then
    printf '%s\n' "$MON_ERR"
    note "One or more metric sources failed; any rows below are partial evidence, not complete totals."
  fi
  if [ -z "$MON_TSV" ]; then
    note "Query accepted (${MON_EMPTY_OK:-scope readable}) but returned no request_count points in window. Either the LB genuinely served no traffic, or the scope is wrong — check 'LB metric scope' above against the backend services in 1d.1."
    verdict UNKNOWN "G1: no metric data points — cannot distinguish 'no traffic' from 'wrong scope'."
  else
    printf '%s\n' "$MON_TSV" | awk -F'\t' \
      -v complete="$MON_COMPLETE" \
      -v minreq="${MON_PEAK_MIN_REQ:-20}" -v kind="$MON_SCOPE_KIND" \
      -v backends="$LB_BACKEND_RE" -v rule="$LB_NAME" -v ns="$NS_SHORT" '
      BEGIN { n = split(backends, ba, "|"); for (i = 1; i <= n; i++) if (ba[i] != "") inset[ba[i]] = 1 }
      {
        m = substr($1, 1, 16); b = $2; fr = $3; code = $4 + 0; v = $5 + 0
        # The API returns an EMPTY backend label (not null) for requests the LB could not route to
        # any backend — the empty-NEG / all-backends-unhealthy signature, and 100%-failure evidence.
        # Treated as a real bucket, and claimed as in-scope when it arrived on this namespace own
        # gateway, otherwise it would be misfiled as a healthy sibling and the signal would vanish.
        if (b == "") b = "(no-backend-matched)"
        if (fr == "") fr = "(no-rule)"
        # Scope client-side. Everything outside the scope is kept as the sibling aggregate — it is
        # what distinguishes "this service is dead" from "the whole LB/cluster is degraded".
        if (kind == "backend")
          mine = (b in inset) || (b == "(no-backend-matched)" && ns != "" && index(fr, ns) > 0)
        else
          mine = (fr == rule)
        if (!mine) { otot += v; if (code >= 500) oerr += v; next }
        tot[m] += v; btot[b] += v; T += v
        ccode[code] += v
        if (code >= 500) { err[m] += v; berr[b] += v; E += v }
        if (code >= 500 && v > 0 && (onset == "" || $1 < onset)) onset = $1
      }
      END {
        if (T == 0) {
          printf "(no in-scope traffic; siblings outside the scope carried total=%d 5xx=%d)\n", otot+0, oerr+0
          print "[VERDICT: UNKNOWN] G1: metric returned data but none of it matched this namespace scope — the scope is probably wrong. Check LB metric scope against 1d.1."
          exit
        }
        print (complete ? "-- per minute (complete: numerator AND denominator from the metric) --" : "-- per minute (PARTIAL metric collection; totals and ratios may be incomplete) --"); fflush()
        for (m in tot) printf "%s  total=%-7d 5xx=%-6d 5xx_ratio=%.1f%%\n", \
          m, tot[m], err[m]+0, (tot[m] ? 100*(err[m]+0)/tot[m] : 0) | "sort"
        close("sort")
        print ""
        print "-- per backend service (one dead service, or all of them?) --"; fflush()
        for (b in btot) printf "%-62s total=%-7d 5xx=%-6d 5xx_ratio=%.1f%%\n", \
          b, btot[b], berr[b]+0, (btot[b] ? 100*(berr[b]+0)/btot[b] : 0) | "sort"
        close("sort")
        print ""
        printf "-- response codes --  "
        for (c in ccode) if (ccode[c] > 0) printf "%d:%d  ", c, ccode[c]
        print ""
        printf "SIBLINGS (same LB, OUTSIDE this scope)  total=%d 5xx=%d 5xx_ratio=%.2f%%\n", \
          otot+0, oerr+0, (otot ? 100*(oerr+0)/otot : 0)
        print "  -> siblings healthy while in-scope is not = the fault is this service/its NEG."
        print "  -> siblings elevated too = cluster / node / network-wide (H3 H9 H12 H15 B1)."

        # Peak minute, over minutes carrying enough traffic to mean anything (a 1-request minute
        # that returned 503 is 100%, and is noise). The RCA template asks for this figure directly.
        peak = -1
        for (m in tot) {
          if (tot[m] < minreq) continue
          pr = 100*(err[m]+0)/tot[m]
          if (pr > peak) { peak = pr; pm = m; ptot = tot[m]; perr = err[m]+0 }
        }
        # Worst single backend, same volume guard. One dead service among many healthy ones is
        # diluted in the aggregate exactly as a short burst is diluted across the window.
        worst = -1
        for (b in btot) {
          if (btot[b] < minreq) continue
          br = 100*(berr[b]+0)/btot[b]
          if (br > worst) { worst = br; wb = b; wtot = btot[b]; werr = berr[b]+0 }
        }
        rw = (T ? 100*(E+0)/T : 0)
        printf "METRIC_WINDOW  total=%d 5xx=%d 5xx_ratio=%.2f%%  onset=%s\n", \
          T, E+0, rw, (onset == "" ? "(none)" : onset)
        if (peak >= 0) printf "METRIC_PEAK    %s  total=%d 5xx=%d 5xx_ratio=%.2f%%  (busiest-qualifying minute, >=%d req)\n", pm, ptot, perr, peak, minreq
        else           printf "METRIC_PEAK    (no minute carried >=%d requests — too little traffic to rate a per-minute ratio)\n", minreq
        if (worst >= 0) printf "METRIC_WORST   %s  total=%d 5xx=%d 5xx_ratio=%.2f%%  (worst backend, >=%d req)\n", wb, wtot, werr, worst, minreq

        # Severity takes the WORST of three views: whole window, worst minute, worst backend. Any
        # one of them alone is a dilution trap — a 2-minute total outage inside a 30-minute window,
        # or one dead backend among a dozen healthy ones, both vanish into a sub-1% aggregate and
        # would read INFO. That false all-clear is the exact failure this section exists to prevent.
        r = rw; src = "window"
        if (peak  > r) { r = peak;  src = "peak minute " pm }
        if (worst > r) { r = worst; src = "worst backend " wb }
        if (!complete)   printf "[VERDICT: UNKNOWN] G1: metric collection failed or was truncated; observed counts do not establish a complete error rate.\n"
        else if (E+0 == 0) printf "[VERDICT: CLEAR] G1: zero 5xx in the LB metric across the window for this scope.\n"
        else if (r >= 10) printf "[VERDICT: FIRES-CRITICAL] G1: %.2f%% 5xx by %s (window %d of %d) — outage-level error rate; onset %s.\n", r, src, E, T, onset
        else if (r >= 1)  printf "[VERDICT: FIRES-WARNING] G1: %.2f%% 5xx by %s (window %d of %d) — partial degradation; onset %s.\n", r, src, E, T, onset
        else              printf "[VERDICT: INFO] G1: %.2f%% 5xx by %s (window %d of %d) — below the 1%% noise floor even at peak; %d errors did occur, so scan the per-minute rows before dismissing.\n", r, src, E, T, E
      }'
  fi
fi

if [ -n "$LB_FILTER" ] && [ "$LB_LOGGING_ENABLED" = "true" ]; then
  # The LOG reads below are SECONDARY to the metric in 1d.2m. They exist for what a metric cannot
  # give — statusDetails, requestUrl, per-request latency — and their counts are a LOWER BOUND:
  # logConfig.sampleRate and any project logging exclusion (commonly one dropping health/polling
  # endpoints) silently remove requests from both numerator and denominator here, but not from the
  # metric. Where the two disagree, the metric wins.
  #
  # Two reads, because one cannot answer both halves of the ratio on a busy LB.
  #
  # Read A (5xx only) is complete across the window *as far as logging captured it*: errors are rare
  # enough to fit under the limit, so it can still name the worst backend. Read B (all requests) is
  # a capped SAMPLE that only supplies a denominator — at a few thousand req/min, $LB_LOG_LIMIT
  # entries can cover well under a minute of a 30-minute window, so a single combined read would
  # report "0 5xx" for an incident that produced hundreds of them minutes later. That is exactly
  # how a real burst gets missed, so the counts and the ratio are reported separately and labelled.
  section "1d.2a — LB 5xx Counts from LOGS (secondary — LOWER BOUND, see 1d.2m for the true count)"
  gcloud logging read \
    'resource.type="http_load_balancer"
     '"$LB_FILTER"'
     httpRequest.status>=500
     timestamp>="'$T_START'"
     timestamp<="'$T_END'"' \
    --project=$PROJECT --order=asc \
    --format="value(timestamp,httpRequest.status,resource.labels.backend_service_name)" \
    --limit=${LB_5XX_LIMIT:-5000} | \
    awk -F'\t' -v lim="${LB_5XX_LIMIT:-5000}" '
      {
        m=substr($1,1,16); b=($3==""?"(no-backend-matched)":$3)
        emin[m]++; eb[b]++; ecode[$2+0]++; E++
        if (first=="") first=$1
      }
      END {
        if (E==0) {print "(no 5xx in the LB LOGS for this scope — NOT a G1 all-clear on its own: a logging exclusion filter or sampleRate<1 can hide every one of them. Take the verdict from 1d.2m.)"; exit}
        print "-- 5xx per minute (complete) --  onset = first minute that steps up"; fflush()
        for (m in emin) printf "%s  5xx=%d\n", m, emin[m] | "sort"
        close("sort")
        print ""
        print "-- 5xx per backend service (complete) --"; fflush()
        for (b in eb) printf "%-62s 5xx=%d\n", b, eb[b] | "sort -k2 -t= -rn"
        close("sort -k2 -t= -rn")
        print ""
        printf "-- status codes --  "
        for (c in ecode) printf "%d:%d  ", c, ecode[c]
        printf "\nWINDOW_5XX_TOTAL=%d  first_5xx=%s\n", E, first
        if (E>=lim) printf "[NOTE] 5xx read hit --limit=%d — even the error stream is truncated; raise $LB_5XX_LIMIT.\n", lim
      }'

  section "1d.2b — LB Traffic Volume from LOGS (SAMPLE — superseded by 1d.2m's denominator)"
  gcloud logging read \
    'resource.type="http_load_balancer"
     '"$LB_FILTER"'
     timestamp>="'$T_START'"
     timestamp<="'$T_END'"' \
    --project=$PROJECT --order=asc \
    --format="value(timestamp,httpRequest.status,resource.labels.backend_service_name)" \
    --limit=$LB_LOG_LIMIT | \
    awk -F'\t' -v lim="$LB_LOG_LIMIT" '
      {
        m=substr($1,1,16); b=($3==""?"(no-backend-matched)":$3); is5=($2+0>=500)
        tot[m]++; btot[b]++; T++
        if (first=="") first=$1
        last=$1
        if (is5) {err[m]++; berr[b]++; E++}
      }
      END {
        if (T==0) {print "(no LB log entries in window)"; exit}
        # fflush() before each "sort" co-process: awk own-output is block-buffered when stdout is
        # the report file, while sort writes to that same fd — without the flush the block headers
        # can land after the rows they label.
        print "-- per minute --"; fflush()
        for (m in tot) printf "%s  total=%-6d 5xx=%-6d 5xx_ratio=%.1f%%\n", \
          m, tot[m], err[m]+0, 100*(err[m]+0)/tot[m] | "sort"
        close("sort")
        print ""
        print "-- per backend service (denominator check: is one service dead, or all of them?) --"
        fflush()
        for (b in btot) printf "%-62s total=%-6d 5xx=%-6d 5xx_ratio=%.1f%%\n", \
          b, btot[b], berr[b]+0, 100*(berr[b]+0)/btot[b] | "sort"
        close("sort")
        printf "\nSAMPLE_TOTAL  total=%d 5xx=%d 5xx_ratio=%.1f%%\n", T, E+0, 100*(E+0)/T
        printf "SAMPLE_SPAN   %s → %s\n", first, last
        if (T>=lim) {
          printf "[NOTE] Read hit --limit=%d (ASC): this sample covers ONLY %s → %s, not the whole window. Its 0%%/low ratio says nothing about the rest of the window — take the error counts from 1d.2a, which are complete, and use this block only as a req/min rate. Raise $LB_LOG_LIMIT or narrow the window to widen the sample.\n", lim, first, last
        }
      }'

  section "1d.3 — LB 5xx Breakdown from LOGS (statusDetails + requestUrl — what metrics cannot carry)"
  gcloud logging read \
    'resource.type="http_load_balancer"
     '"$LB_FILTER"'
     httpRequest.status>=500
     timestamp>="'$T_START'"
     timestamp<="'$T_END'"' \
    --project=$PROJECT --order=asc \
    --format="table(timestamp,httpRequest.status,httpRequest.latency,jsonPayload.statusDetails,httpRequest.requestUrl)" \
    --limit=1000

  section "1d.4 — LB Latency Distribution from LOGS (capped sample — read the shape, not the volume)"
  gcloud logging read \
    'resource.type="http_load_balancer"
     '"$LB_FILTER"'
     timestamp>="'$T_START'"
     timestamp<="'$T_END'"' \
    --project=$PROJECT --format="value(httpRequest.latency)" --limit=5000 | \
    sed 's/s$//' | awk '
      {v=$1+0}
      v<0.1  {fast++}
      v>=0.1 && v<0.5  {mid++}
      v>=0.5 && v<2.0  {slow++}
      v>=2.0 {veryslow++}
      END {print "< 100ms:", fast; print "100-500ms:", mid; print "500ms-2s:", slow; print "> 2s:", veryslow}
    '

  section "1d.5 — LB statusDetails from LOGS (distribution across the LOGGED 5xx only)"
  gcloud logging read \
    'resource.type="http_load_balancer"
     '"$LB_FILTER"'
     httpRequest.status>=500
     timestamp>="'$T_START'"
     timestamp<="'$T_END'"' \
    --project=$PROJECT --format="value(jsonPayload.statusDetails)" --limit=1000 | sort | uniq -c | sort -rn

else
  note "1d log steps 2a-5 skipped: no LB scope (neither Ingress nor Gateway VIP resolved to a forwarding rule, and no backend service matched this namespace) or logConfig.enable=false. Set \$LB_NAME or \$LB_BACKEND_NAME and re-run, or run the LB queries manually (see skill 1d). The 5xx COUNTS are unaffected — take them from the metric in 1d.2m, which needs no LB logging at all. What is lost here is the qualitative detail only: statusDetails, requestUrl and latency are UNKNOWN."
fi

section "1e — Deploy Gate (H7)"
gcloud logging read \
  'resource.type="k8s_cluster"
   protoPayload.resourceName=~"namespaces/'$NAMESPACE'/deployments/"
   protoPayload.methodName=~"\.deployments\.(create|update|patch|replace)"
   resource.labels.cluster_name="'$CLUSTER'"
   timestamp>="'$T_START_MINUS_2H'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,protoPayload.authenticationInfo.principalEmail,protoPayload.methodName,protoPayload.resourceName)" \
  --limit=50

section "1f.1 — Cluster Autoscaler" "H4 H11"
gcloud logging read \
  'resource.type="k8s_cluster"
   log_name=~"cluster-autoscaler"
   (textPayload=~"Scale-down|ScaleDown|removing node|evicting pod"
    OR jsonPayload.message=~"Scale-down|ScaleDown|removing node")
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc --format="table(timestamp,textPayload)" --limit=50

section "1f.2 — Node Auto-repair / MIG Recreation" "H13 H14"
gcloud logging read \
  'resource.type="gce_instance"
   protoPayload.methodName=~"compute\.instances\.(insert|bulkInsert|delete)"
   protoPayload.authenticationInfo.principalEmail=~"system:|gke-|container-engine|cloudservices\.gserviceaccount\.com"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,protoPayload.methodName,protoPayload.authenticationInfo.principalEmail,protoPayload.resourceName)" \
  --limit=60

section "1f.3 — GKE Automatic Upgrades" "H13"
gcloud logging read \
  '(resource.type="gce_instance" OR resource.type="gke_cluster")
   (protoPayload.methodName=~"UpdateCluster|SetNodePoolVersion|UpdateNodePool"
    OR textPayload=~"upgrade|Upgrading")
   timestamp>="'$T_START_MINUS_2H'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc --format="table(timestamp,protoPayload.methodName,textPayload)" --limit=30

section "1f.4 — Preemptible/Spot VM Preemption" "H3"
gcloud logging read \
  'resource.type="gce_instance"
   protoPayload.methodName="compute.instances.preempted"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,resource.labels.instance_id,protoPayload.resourceName)" --limit=20

section "1f.5 — Node Pool Resize" "H14 H15"
gcloud logging read \
  'resource.type="gke_nodepool"
   protoPayload.methodName=~"SetNodePoolSize|SetNodePoolAutoscaling"
   timestamp>="'$T_START_MINUS_2H'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,protoPayload.authenticationInfo.principalEmail,protoPayload.methodName)" --limit=20

section "1f.6 — HPA Scale Events" "H4"
gcloud logging read \
  'resource.type="k8s_cluster"
   log_name="projects/'$PROJECT'/logs/events"
   jsonPayload.involvedObject.kind="HorizontalPodAutoscaler"
   jsonPayload.reason=~"SuccessfulRescale|DesiredReplicasComputed"
   resource.labels.namespace_name="'$NAMESPACE'"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,jsonPayload.involvedObject.name,jsonPayload.reason,jsonPayload.message)" --limit=50

section "1f.7 — Maintenance Window" "H13"
gcloud container clusters describe "$CLUSTER" --location=$REGION --project=$PROJECT \
  --format="value(maintenancePolicy.window.dailyMaintenanceWindow,maintenancePolicy.window.recurringWindow)"

section "1f.8 — IAM / Workload Identity Policy Changes (critical window T-6h)" "H8"
gcloud logging read \
  'protoPayload.serviceName="iam.googleapis.com"
   (protoPayload.methodName=~"SetIamPolicy|CreateServiceAccountKey|DeleteServiceAccountKey|DisableServiceAccount"
    OR protoPayload.methodName=~"roles.update|bindings")
   timestamp>="'$T_START_CRITICAL'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,protoPayload.authenticationInfo.principalEmail,protoPayload.methodName,protoPayload.resourceName)" \
  --limit=30

section "1g.1 — Autoscaler Scale-up Decisions/Blockers (H11)" "H16"
gcloud logging read \
  'resource.type="k8s_cluster"
   log_name=~"container.googleapis.com%2Fcluster-autoscaler-visibility"
   resource.labels.cluster_name="'$CLUSTER'"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc --format="json" --limit=200

section "1g.2 — GCE VM Create Failures (stockout smoking gun, H11)"
gcloud logging read \
  'resource.type="gce_instance"
   protoPayload.methodName=~"compute\.instances\.(insert|bulkInsert)"
   (protoPayload.response.error.errors.code=~"ZONE_RESOURCE_POOL_EXHAUSTED|QUOTA_EXCEEDED|RESOURCE_POOL_EXHAUSTED|IP_SPACE_EXHAUSTED"
    OR protoPayload.status.message=~"exhausted|does not have enough resources|resource pool")
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,protoPayload.authenticationInfo.principalEmail,protoPayload.response.error.errors.code,protoPayload.status.message)" \
  --limit=100

section "1g.3 — GKE Create/Delete Churn (H11)"
gcloud logging read \
  'resource.type="gce_instance_group_manager"
   protoPayload.methodName=~"createInstances|deleteInstances"
   protoPayload.authenticationInfo.principalEmail=~"container-engine-robot|system:"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,protoPayload.methodName,protoPayload.resourceName)" --limit=100

section "1g.4 — Quota Headroom Check (rules out H4-quota)"
# Keep only the quotas that gate GKE node autoscaling. Every per-family vCPU quota is
# named <FAMILY>_CPUS, so the bare "CPUS" substring matches all machine families
# (E2/N2/N2D/C2D/T2D/C3/N4/C4/…) automatically — no need to hardcode family names.
gcloud compute regions describe "$REGION_ONLY" --project=$PROJECT \
  --format="table(quotas.metric,quotas.usage,quotas.limit)" | grep -iE "CPUS|IN_USE_ADDRESSES" || true

section "1g.5 — Node Pool Topology" "H11 H15 H16"
gcloud container node-pools list --cluster="$CLUSTER" --location=$REGION --project=$PROJECT \
  --format="table(name,config.machineType,initialNodeCount,autoscaling.enabled,locations)"

section "1h.1 — VPC/Firewall/Route/NAT Changes (H12, T-2h)"
gcloud logging read \
  'protoPayload.serviceName="compute.googleapis.com"
   protoPayload.methodName=~"compute\.(firewalls|routes|networks|subnetworks|routers|globalAddresses|addresses)\.(insert|update|patch|delete)"
   timestamp>="'$T_START_MINUS_2H'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,protoPayload.authenticationInfo.principalEmail,protoPayload.methodName,protoPayload.resourceName)" \
  --limit=50

section "1h.2 — Cloud NAT Exhaustion (H12)"
gcloud logging read \
  'resource.type="nat_gateway"
   (jsonPayload.allocation_status="DROPPED"
    OR textPayload=~"OUT_OF_RESOURCES|allocation|dropped")
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,resource.labels.gateway_name,jsonPayload.allocation_status,textPayload)" --limit=100

section "1h.3 — CNI / Pod-Sandbox Failures (H12)"
gcloud logging read \
  'resource.type="k8s_cluster"
   log_name="projects/'$PROJECT'/logs/events"
   jsonPayload.reason=~"FailedCreatePodSandBox|NetworkNotReady|CNI|FailedCreatePodContainer"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,jsonPayload.involvedObject.name,jsonPayload.reason,jsonPayload.message)" --limit=100

section "1h.4 — Subnet/Pod-IP Exhaustion (H12)"
gcloud logging read \
  '(resource.type="gce_subnetwork" OR (resource.type="gce_instance" AND protoPayload.response.error.errors.code="IP_SPACE_EXHAUSTED"))
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,protoPayload.methodName,protoPayload.status.message)" --limit=50
gcloud container clusters describe "$CLUSTER" --location=$REGION --project=$PROJECT \
  --format="value(ipAllocationPolicy.clusterSecondaryRangeName,ipAllocationPolicy.servicesSecondaryRangeName,ipAllocationPolicy.podCidrOverprovisionConfig)" 2>/dev/null

section "1h.5 — LB Backend Health, Network Side (H12)"
if [ -n "$LB_BACKEND_NAME" ]; then
  gcloud compute backend-services get-health "$LB_BACKEND_NAME" --global --project=$PROJECT \
    --format="table(status.healthStatus[].instance,status.healthStatus[].healthState)" 2>/dev/null || true
else
  note "LB_BACKEND_NAME not discovered — skip or run manually."
fi

section "1i — B1 Billing Disabled Scan (critical window T-6h)"
BILLING_LOG=$(gcloud logging read \
  'severity>=ERROR
   (textPayload:"BILLING_DISABLED" OR textPayload:"requires billing to be enabled")
   timestamp>="'$T_START_CRITICAL'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,resource.type,textPayload)" --limit=50) && BILLING_LOG_OK=1 || BILLING_LOG_OK=0
printf '%s\n' "$BILLING_LOG"
gcloud billing projects describe "$PROJECT" --format="value(billingEnabled,billingAccountName)" 2>/dev/null
gcloud logging read \
  'protoPayload.serviceName="cloudbilling.googleapis.com"
   protoPayload.methodName=~"UpdateBillingInfo|AssignResourceToBillingAccount|DisableResourceBilling"
   timestamp>="'$T_START_MINUS_2H'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,protoPayload.methodName,protoPayload.authenticationInfo.principalEmail)" --limit=20
if [ "${CAP_LOGGING:-0}" = 0 ] || [ "$BILLING_LOG_OK" = 0 ]; then
  verdict UNKNOWN "B1: Cloud Logging unreadable — cannot confirm or deny a billing-disabled event."
elif printf '%s' "$BILLING_LOG" | grep -q .; then
  if [ "${BILLING_NOW:-}" = "True" ]; then
    verdict INFO "B1: in-window billing-disabled log FOUND but billing is ENABLED now — likely resolved/transient. Score CRITICAL only if the log timestamps overlap the symptom window (it was causal then)."
  else
    verdict FIRES-CRITICAL "B1: in-window billing-disabled log present (billingEnabled_now=${BILLING_NOW:-unreadable}) — project billing is the root cause reclaiming nodes/services."
  fi
else
  verdict CLEAR "B1: no in-window billing-disabled log (logging readable)."
fi

section "1i — H13 Repair/Upgrade Op Scan (critical window T-6h)"
if [ "${CAP_OPS:-0}" = 0 ]; then
  verdict UNKNOWN "H13: container operations unreadable — cannot rule out an in-window repair/upgrade op."
else
  H13_OPS=$(cluster_ops \
    | awk -F'\t' -v s="$T_START_CRITICAL" -v e="$T_END" '$3>=s && $3<=e && ($1=="REPAIR_CLUSTER" || $1 ~ /^UPGRADE/) {print}') && H13_READ_OK=1 || H13_READ_OK=0
  printf '%s\n' "$H13_OPS"
  # maintenance-window guard: a scheduled UPGRADE inside the cluster's window is expected, not an incident.
  MAINT=$(gcloud container clusters describe "$CLUSTER" --location=$REGION --project=$PROJECT \
    --format="value(maintenancePolicy.window.recurringWindow.recurrence,maintenancePolicy.window.dailyMaintenanceWindow.startTime)" 2>/dev/null)
  printf '%s' "$H13_OPS" | grep -q 'REPAIR_CLUSTER' && H13_REP=1 || H13_REP=0
  printf '%s' "$H13_OPS" | grep -q 'UPGRADE'        && H13_UP=1  || H13_UP=0
  [ "$H13_REP" = 1 ] && verdict FIRES-WARNING "H13: in-window REPAIR_CLUSTER (node auto-repair) rebuilt nodes — correlate its startTime with symptom onset."
  if [ "$H13_UP" = 1 ]; then
    if [ -n "$MAINT" ]; then
      verdict INFO "H13: in-window UPGRADE_* op with a maintenance window configured ($MAINT) — may be the scheduled upgrade. Score WARNING only if it falls outside/over-runs the window AND correlates with symptom onset."
    else
      verdict FIRES-WARNING "H13: in-window UPGRADE_* op with NO maintenance window configured — unplanned upgrade during the incident."
    fi
  fi
  if [ "$H13_READ_OK" = 0 ]; then
    verdict UNKNOWN "H13: operations query failed after preflight; absence of an operation is unverified."
  elif [ "$H13_REP" = 0 ] && [ "$H13_UP" = 0 ]; then
    verdict CLEAR "H13: no in-window REPAIR_CLUSTER/UPGRADE_* op (operations readable)."
  fi
fi

section "1i — H14 Node VM Delete Burst"
if [ "${CAP_LOGGING:-0}" = 0 ]; then
  verdict UNKNOWN "H14: Cloud Logging unreadable — cannot count node-delete events (note: these are Admin Activity logs, always emitted; the gap is read permission)."
else
  DEL_LOG=$(gcloud logging read \
    'resource.type="gce_instance"
     protoPayload.methodName=~"compute\.instances\.delete"
     protoPayload.resourceName:"gke-'$CLUSTER'-"
     protoPayload.authenticationInfo.principalEmail=~"cloudservices\.gserviceaccount\.com"
     timestamp>="'$T_START'"
     timestamp<="'$T_END'"' \
    --project=$PROJECT --format="value(timestamp)" --limit=500) && DEL_READ_OK=1 || DEL_READ_OK=0
  DEL=$(printf '%s\n' "$DEL_LOG" | awk 'NF {n++} END {print n+0}')
  echo "in-window MIG node VM deletes: $DEL (burst threshold $NODE_DELETE_BURST)"
  PLANNED_OP=$(planned_ops_in_window | head -1)
  GUARD_NOTE=""; [ "${CAP_OPS:-0}" = 0 ] && GUARD_NOTE=" [planned-op guard unavailable — CAP_OPS=0]"
  if [ "$DEL_READ_OK" = 0 ]; then
    verdict UNKNOWN "H14: node-delete query failed after preflight; delete count is unverified."
  elif [ "$DEL" -ge "$NODE_DELETE_BURST" ]; then
    if [ -n "$PLANNED_OP" ]; then
      verdict INFO "H14: $DEL deletes >= $NODE_DELETE_BURST but a planned op overlaps ($PLANNED_OP) — intentional node cycling from a resize/upgrade, not reclamation. Confirm the timeline before dismissing."
    else
      verdict FIRES-WARNING "H14: $DEL in-window MIG node VM deletes >= $NODE_DELETE_BURST by cloudservices SA, no overlapping planned op — node reclamation.$GUARD_NOTE"
    fi
  elif [ "$DEL" -gt 0 ]; then
    verdict CLEAR "H14: $DEL in-window deletes, below burst threshold $NODE_DELETE_BURST (non-zero — watch if it climbs)."
  else
    verdict CLEAR "H14: no in-window node deletes (logging readable)."
  fi
fi

section "1i — H15 Node Count Loss / NotReady / Age Reset"
kube_read get nodes -o wide
POOLS=$(gcloud container node-pools list --cluster="$CLUSTER" --location=$REGION --project=$PROJECT \
  --format="value(name,autoscaling.minNodeCount)" 2>/dev/null) && POOLS_OK=1 || POOLS_OK=0
printf '%s\n' "$POOLS"
MIN_SUM=$(printf '%s\n' "$POOLS" | awk '{s+=$2} END{print s+0}')   # $2 = per-zone minNodeCount
NODES_JSON=$(kube_read get nodes -o json 2>/dev/null) && NODES_OK=1 || NODES_OK=0
printf '%s' "$NODES_JSON" | jq -e '.items | type == "array"' >/dev/null 2>&1 || NODES_OK=0
NODES=$(printf '%s' "$NODES_JSON" | jq '.items | length' 2>/dev/null || echo 0)
NOTREADY=$(printf '%s' "$NODES_JSON" | jq '[.items[] | select((.status.conditions[]? | select(.type=="Ready") | .status) != "True")] | length' 2>/dev/null || echo 0)
YOUNG=$(printf '%s' "$NODES_JSON" | jq --arg t "$T_START" '[.items[] | select(.metadata.creationTimestamp > $t)] | length' 2>/dev/null || echo 0)
NODES=${NODES:-0}; NOTREADY=${NOTREADY:-0}; YOUNG=${YOUNG:-0}   # jq emits empty (not 0) on empty stdin
echo "nodes=$NODES notReady=$NOTREADY young=$YOUNG  minNodeCount_sum=${MIN_SUM:-?} (frac threshold $AGE_RESET_FRAC, NotReady threshold $NOTREADY_MAX)"
if [ "${CAP_K8S:-0}" = 0 ] || [ "$NODES_OK" = 0 ] || [ "$POOLS_OK" = 0 ]; then
  verdict UNKNOWN "H15: verified node/pool data unavailable — check context and individual query errors; cannot rule out reclamation."
else
  PLANNED_OP=$(planned_ops_in_window | head -1)
  [ "${CAP_OPS:-0}" = 0 ] && note "H15: planned-op guard unavailable (CAP_OPS=0) — a FIRES here may actually be planned cycling; confirm operations manually."
  H15_FIRED=0
  if [ "$NOTREADY" -ge "$NOTREADY_MAX" ] 2>/dev/null; then
    verdict FIRES-WARNING "H15: $NOTREADY NotReady nodes >= $NOTREADY_MAX (still present, not gone → H3/eviction territory, not reclamation)."; H15_FIRED=1
  fi
  if [ "$NODES" -gt 0 ] 2>/dev/null && awk -v y="$YOUNG" -v n="$NODES" -v frac="$AGE_RESET_FRAC" 'BEGIN{exit !(y/n>=frac)}'; then
    if [ -n "$PLANNED_OP" ]; then
      verdict INFO "H15: young-node fraction $YOUNG/$NODES >= $AGE_RESET_FRAC but a planned op overlaps ($PLANNED_OP) — expected mass re-creation from a resize/upgrade."
    else
      verdict FIRES-WARNING "H15: young-node fraction $YOUNG/$NODES >= $AGE_RESET_FRAC (mass creation-age reset) with no planned op — the fleet was rebuilt."
    fi
    H15_FIRED=1
  fi
  if [ "${MIN_SUM:-0}" -gt 0 ] 2>/dev/null && [ "$NODES" -lt "$MIN_SUM" ] 2>/dev/null; then
    if [ -n "$PLANNED_OP" ]; then
      verdict INFO "H15: node count $NODES < summed minNodeCount $MIN_SUM but a planned op overlaps ($PLANNED_OP) — likely a deliberate scale-down/drain, not reclamation."
    else
      verdict FIRES-CRITICAL "H15: node count $NODES < summed minNodeCount $MIN_SUM with no planned op — nodes reclaimed below the pool minimum (conservative: minNodeCount is per-zone, so a regional pool's true floor is higher)."
    fi
    H15_FIRED=1
  fi
  [ "$H15_FIRED" = 0 ] && verdict CLEAR "H15: nodes=$NODES, NotReady<$NOTREADY_MAX, age/count within bounds (kubectl readable)."
fi

# ============================================================================
# Phase 3 — Auto-discoverable Deep-Dive Data (per hypothesis)
# ============================================================================

section "H1 (OOMKill) — OS-level OOMKill"
gcloud logging read \
  'resource.type="gce_instance"
   textPayload=~"oom_kill_process|Out of memory"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,resource.labels.instance_id,textPayload)" --limit=50

section "H1 (OOMKill) — Container names, previous logs, memory limits, VPA"
if [ -n "$POD_NAME" ]; then
  kube_read get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{range .spec.containers[*]}{.name}{"\n"}{end}' 2>/dev/null
  kube_read logs "$POD_NAME" -n "$NAMESPACE" --previous --timestamps=true 2>/dev/null | tail -300
  kube_read get pod "$POD_NAME" -n "$NAMESPACE" \
    -o jsonpath='{range .spec.containers[*]}{.name}{"\t"}{"req: "}{.resources.requests.memory}{"\t"}{"lim: "}{.resources.limits.memory}{"\n"}{end}' 2>/dev/null
else
  note "POD_NAME not discovered — set \$POD_NAME to the crashing pod and re-run for previous logs/limits."
fi
kube_read describe vpa -n "$NAMESPACE" 2>/dev/null
manual "fetch k8s_container | metric 'kubernetes.io/container/memory/limit_utilization' | filter resource.cluster_name == '$CLUSTER' && resource.namespace_name == '$NAMESPACE' && resource.pod_name =~ '$SERVICE.*' | within(30m, d'$T_UTC') | every 1m
Values >0.85 in the 5min before crash = strong H1 confirmation."

section "H2 (Probe Failure) — Unhealthy events"
gcloud logging read \
  'resource.type="k8s_cluster"
   log_name="projects/'$PROJECT'/logs/events"
   jsonPayload.reason="Unhealthy"
   resource.labels.namespace_name="'$NAMESPACE'"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,jsonPayload.involvedObject.name,jsonPayload.message)" --limit=200

section "H2 (Probe Failure) — Probe configs"
kube_read get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o json 2>/dev/null | jq -r '
  .spec.template.spec.containers[] |
  "Container: \(.name)",
  "  startup:   \(.startupProbe // "none" | if type == "object" then tojson else . end)",
  "  liveness:  \(.livenessProbe // "none" | if type == "object" then tojson else . end)",
  "  readiness: \(.readinessProbe // "none" | if type == "object" then tojson else . end)"'

section "H2 (Probe Failure) — Restart count / sub-variant + endpoint oscillation + app warnings"
kube_read get pods -n "$NAMESPACE" -l "$POD_SELECTOR" -o json 2>/dev/null | jq -r '
  .items[] | .metadata.name as $pod |
  .status.containerStatuses[]? |
  [$pod, .name, .restartCount, .lastState.terminated.exitCode // "-"] | @tsv' | \
  column -t -s $'\t' -N POD,CONTAINER,RESTARTS,EXIT
gcloud logging read \
  'resource.type="k8s_cluster"
   protoPayload.resourceName=~"namespaces/'$NAMESPACE'/endpoints/'$SERVICE'"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,protoPayload.methodName,protoPayload.response)" --limit=100
gcloud logging read \
  'resource.type="k8s_container"
   resource.labels.cluster_name="'$CLUSTER'"
   resource.labels.namespace_name="'$NAMESPACE'"
   resource.labels.pod_name=~"'$SVC_RE'"
   severity>=WARNING
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,resource.labels.pod_name,jsonPayload.message,textPayload)" --limit=300

section "H3 (Node Eviction) — Evicted / pressure / FailedScheduling / node syslog / preemption / node state"
gcloud logging read \
  'resource.type="k8s_cluster"
   log_name="projects/'$PROJECT'/logs/events"
   jsonPayload.reason="Evicted"
   resource.labels.namespace_name="'$NAMESPACE'"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,jsonPayload.involvedObject.name,jsonPayload.message)" --limit=100
gcloud logging read \
  'resource.type="k8s_cluster"
   log_name="projects/'$PROJECT'/logs/events"
   jsonPayload.reason=~"NodeHas|NodeNot|Pressure"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,jsonPayload.involvedObject.name,jsonPayload.reason,jsonPayload.message)" --limit=100
gcloud logging read \
  'resource.type="k8s_cluster"
   log_name="projects/'$PROJECT'/logs/events"
   jsonPayload.reason="FailedScheduling"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,jsonPayload.involvedObject.name,jsonPayload.message)" --limit=50
if [ -n "$NODE_INSTANCE_ID" ]; then
  gcloud logging read \
    'resource.type="gce_instance"
     resource.labels.instance_id="'$NODE_INSTANCE_ID'"
     timestamp>="'$T_START'"
     timestamp<="'$T_END'"' \
    --project=$PROJECT --order=asc \
    --format="table(timestamp,textPayload,jsonPayload.message)" --limit=100
else
  note "NODE_INSTANCE_ID not discovered — set \$NODE_INSTANCE_ID (from an eviction event or 'kubectl describe pod <pod> | grep Node:') and re-run for node syslog."
fi
gcloud logging read \
  'resource.type="gce_instance"
   protoPayload.methodName=~"compute.instances.delete|preempted|migrate"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc --limit=20
kube_read get nodes -o wide
kube_read get nodes -o json 2>/dev/null | jq -r '
  .items[] | "\(.metadata.name): \(.status.conditions | map(select(.status=="True")) | map(.type) | join(", "))"'

section "H4 (HPA/Quota) — HPA state, scale events, autoscaler, FailedScheduling, top pods, quota"
kube_read get hpa -n "$NAMESPACE" 2>/dev/null
kube_read describe hpa -n "$NAMESPACE" 2>/dev/null
gcloud logging read \
  'resource.type="k8s_cluster"
   log_name="projects/'$PROJECT'/logs/events"
   jsonPayload.involvedObject.kind="HorizontalPodAutoscaler"
   resource.labels.namespace_name="'$NAMESPACE'"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,jsonPayload.involvedObject.name,jsonPayload.reason,jsonPayload.message)" --limit=100
gcloud logging read \
  'resource.type="k8s_cluster"
   log_name=~"cluster-autoscaler"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc --format="table(timestamp,textPayload)" --limit=100
gcloud logging read \
  'resource.type="k8s_cluster"
   log_name="projects/'$PROJECT'/logs/events"
   jsonPayload.reason="FailedScheduling"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc --limit=50
kube_read top pods -n "$NAMESPACE" 2>/dev/null
kube_read describe resourcequota -n "$NAMESPACE" 2>/dev/null

section "H5 (Pool Exhausted) — App logs, DB logs, pool config"
gcloud logging read \
  'resource.type="k8s_container"
   resource.labels.cluster_name="'$CLUSTER'"
   resource.labels.namespace_name="'$NAMESPACE'"
   resource.labels.pod_name=~"'$SVC_RE'"
   (textPayload=~"connection pool|pool exhausted|too many connections|pool timeout|acquire.*timeout|no idle connection|max.*connections.*reached"
    OR jsonPayload.message=~"connection pool|pool exhausted|too many connections|pool timeout|acquire.*timeout|no idle connection")
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,resource.labels.pod_name,jsonPayload.message,textPayload)" --limit=300
gcloud logging read \
  'resource.type="cloudsql_database"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,severity,jsonPayload.message,textPayload)" --limit=100
gcloud logging read \
  'resource.type="cloudsql_database"
   severity>=WARNING
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc --limit=50
# Collect numeric pool sizing only. Connection strings have too many credential formats
# to safely redact by URI substitution, and their values are not needed for this check.
kube_read get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o json 2>/dev/null | jq -r '
  .spec.template.spec.containers[] | .name as $container | .env[]? |
  select(.name | test("^(DB_POOL_SIZE|DB_MAX_CONNECTIONS|MAX_CONNECTIONS|MAX_CONN|PG_POOL_MAX|PG_POOL_MIN|HIKARI_MAX_POOL_SIZE|HIKARI_MIN_IDLE|C3P0_MAX_POOL_SIZE|C3P0_MIN_POOL_SIZE)$"; "i")) |
  select((.value // "") | test("^[0-9]+$")) |
  "\($container): \(.name) = \(.value)"'

section "H6 (Dependency/Redis) — App error signatures, instance state, blast radius, connectivity"
gcloud logging read \
  'resource.type="k8s_container"
   resource.labels.cluster_name="'$CLUSTER'"
   resource.labels.namespace_name="'$NAMESPACE'"
   resource.labels.pod_name=~"'$SVC_RE'"
   (textPayload=~"redis|:6379|READONLY|LOADING|MISCONF|NOAUTH|WRONGPASS|max number of clients|OOM command not allowed|connection pool|pool timeout|connection reset|ECONNREFUSED|i/o timeout|context deadline exceeded|dial tcp"
    OR jsonPayload.message=~"redis|:6379|READONLY|LOADING|MISCONF|NOAUTH|max number of clients|OOM command not allowed|connection pool|pool timeout|connection reset|ECONNREFUSED|dial tcp")
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,resource.labels.pod_name,jsonPayload.message,textPayload)" --limit=300
gcloud redis instances list --region=$REGION_ONLY --project=$PROJECT \
  --format="table(name,tier,memorySizeGb,host,port,state,redisVersion)" 2>/dev/null
gcloud logging read \
  'resource.type="redis_instance"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,severity,protoPayload.methodName,jsonPayload.message,textPayload)" --limit=100
kube_read get pods -n "$NAMESPACE" -o json 2>/dev/null | jq -r '
  .items[] | select(.metadata.name | test("'$SERVICE'") | not) |
  [.metadata.name,
   ([.status.containerStatuses[]?.restartCount] | add // 0),
   ([.status.containerStatuses[]?.ready] | all)] | @tsv' | \
  column -t -s $'\t' -N POD,RESTARTS,READY | head -20
kube_read get pods -n "$NAMESPACE" -l "$POD_SELECTOR" -o wide 2>/dev/null | head
manual "fetch redis_instance | metric 'redis.googleapis.com/stats/memory/usage_ratio' -- also clients/connected, clients/blocked, stats/reject_connections_count, stats/evicted_keys, stats/cpu_utilization, replication/master_slave_lag | filter resource.instance_id =~ '.*' | within(30m, d'$T_UTC') | every 1m"

section "H7 (Bad Deploy) — New pod status, failure events, missing refs, rollout history"
kube_read get pods -n "$NAMESPACE" -l "$POD_SELECTOR" -o json 2>/dev/null | jq -r '
  .items | sort_by(.metadata.creationTimestamp) | .[] |
  [.metadata.name, .metadata.creationTimestamp,
   (.status.phase),
   (.status.containerStatuses[]?.state | keys[0] // "-"),
   (.status.containerStatuses[]?.state.waiting.reason // "-")] | @tsv' | \
  column -t -s $'\t' -N POD,CREATED,PHASE,STATE,REASON
gcloud logging read \
  'resource.type="k8s_cluster"
   log_name="projects/'$PROJECT'/logs/events"
   jsonPayload.reason=~"Failed|BackOff|FailedMount|FailedAttachVolume|CreateContainerConfigError"
   resource.labels.namespace_name="'$NAMESPACE'"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,jsonPayload.involvedObject.name,jsonPayload.reason,jsonPayload.message)" --limit=100
kube_read get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o json 2>/dev/null | jq -r '
  .spec.template.spec |
  (.containers[].env[]?.valueFrom.secretKeyRef.name // empty),
  (.containers[].env[]?.valueFrom.configMapKeyRef.name // empty),
  (.volumes[]?.secret.secretName // empty),
  (.volumes[]?.configMap.name // empty)' | sort -u | while read -r ref; do
    [ -z "$ref" ] && continue
    kube_read get secret "$ref" -n "$NAMESPACE" 2>/dev/null >/dev/null || kube_read get configmap "$ref" -n "$NAMESPACE" 2>/dev/null >/dev/null || echo "MISSING: $ref"
done
kube_read rollout history deployment/"$DEPLOYMENT" -n "$NAMESPACE" 2>/dev/null

section "H8 (IAM/WI) — App auth errors, WI annotations, IAM changes (critical window), IAM policy, SA keys"
gcloud logging read \
  'resource.type="k8s_container"
   resource.labels.cluster_name="'$CLUSTER'"
   resource.labels.namespace_name="'$NAMESPACE'"
   resource.labels.pod_name=~"'$SVC_RE'"
   (textPayload=~"permission denied|PERMISSION_DENIED|403|token expired|invalid_grant|iam|workload identity|metadata server"
    OR jsonPayload.message=~"permission denied|PERMISSION_DENIED|403|token expired|invalid_grant|iam|workload identity")
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,resource.labels.pod_name,jsonPayload.message,textPayload)" --limit=200
kube_read get serviceaccount -n "$NAMESPACE" -o json 2>/dev/null | jq -r '
  .items[] | "\(.metadata.name): \(.metadata.annotations["iam.gke.io/gcp-service-account"] // "NO WI ANNOTATION")"'
gcloud logging read \
  'protoPayload.serviceName="iam.googleapis.com"
   (protoPayload.methodName=~"SetIamPolicy|CreateServiceAccountKey|DeleteServiceAccountKey|DisableServiceAccount"
    OR protoPayload.resourceName=~"'$PROJECT'")
   timestamp>="'$T_START_CRITICAL'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,protoPayload.authenticationInfo.principalEmail,protoPayload.methodName,protoPayload.resourceName)" --limit=30
gcloud projects get-iam-policy "$PROJECT" \
  --format="table(bindings.role,bindings.members)" \
  --flatten="bindings[].members" \
  --filter="bindings.members=serviceAccount:$PROJECT.svc.id.goog[*]" 2>/dev/null | head -40
# Resolve the GSA from the Workload-Identity annotation on the pod's KSA (the KSA name
# is NOT the GSA email — building <ksa>@<proj>.iam... would query a nonexistent account).
DEPLOY_KSA=$(kube_read get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.serviceAccountName}' 2>/dev/null)
DEPLOY_KSA="${DEPLOY_KSA:-default}"
GSA_EMAIL=$(kube_read get serviceaccount "$DEPLOY_KSA" -n "$NAMESPACE" -o jsonpath='{.metadata.annotations.iam\.gke\.io/gcp-service-account}' 2>/dev/null)
if [ -n "$GSA_EMAIL" ]; then
  echo "Workload-Identity GSA for KSA '$DEPLOY_KSA': $GSA_EMAIL"
  gcloud iam service-accounts keys list --iam-account="$GSA_EMAIL" --project=$PROJECT 2>/dev/null
else
  note "KSA '$DEPLOY_KSA' has no iam.gke.io/gcp-service-account annotation — Workload Identity may be disabled or the pod uses the node SA; see the WI annotation list above."
fi

section "H9 (DNS/CoreDNS) — Cluster-wide DNS errors, CoreDNS state/logs/resources/config"
gcloud logging read \
  'resource.type="k8s_container"
   resource.labels.cluster_name="'$CLUSTER'"
   (textPayload=~"no such host|dns|lookup failed|NXDOMAIN|SERVFAIL|i/o timeout.*53"
    OR jsonPayload.message=~"no such host|dns|lookup failed|NXDOMAIN|SERVFAIL")
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,resource.labels.namespace_name,resource.labels.pod_name,jsonPayload.message,textPayload)" --limit=200
kube_read get pods -n kube-system -l k8s-app=kube-dns -o wide 2>/dev/null
kube_read get pods -n kube-system -l k8s-app=kube-dns -o json 2>/dev/null | jq -r '
  .items[] | [.metadata.name, .status.phase,
   ([.status.containerStatuses[]?.restartCount] | add // 0),
   (.status.containerStatuses[]?.ready)] | @tsv' | \
  column -t -s $'\t' -N POD,PHASE,RESTARTS,READY
gcloud logging read \
  'resource.type="k8s_container"
   resource.labels.cluster_name="'$CLUSTER'"
   resource.labels.namespace_name="kube-system"
   resource.labels.container_name="coredns"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,resource.labels.pod_name,textPayload,jsonPayload.message)" --limit=200
kube_read top pods -n kube-system -l k8s-app=kube-dns 2>/dev/null
gcloud logging read \
  'resource.type="k8s_cluster"
   log_name="projects/'$PROJECT'/logs/events"
   jsonPayload.involvedObject.namespace="kube-system"
   jsonPayload.reason=~"OOMKilling|Unhealthy|BackOff"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,jsonPayload.involvedObject.name,jsonPayload.reason,jsonPayload.message)" --limit=50
kube_read get configmap coredns -n kube-system -o yaml 2>/dev/null

section "H10 (CPU Throttling) — CPU limits, probe timeoutSeconds, Unhealthy events, node CPU"
kube_read get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
  -o jsonpath='{range .spec.template.spec.containers[*]}{.name}{"\t"}{"req: "}{.resources.requests.cpu}{"\t"}{"lim: "}{.resources.limits.cpu}{"\n"}{end}' 2>/dev/null
kube_read get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o json 2>/dev/null | jq -r '
  .spec.template.spec.containers[] |
  "Container: \(.name)",
  "  liveness timeoutSeconds:  \(.livenessProbe.timeoutSeconds // "default(1)")",
  "  readiness timeoutSeconds: \(.readinessProbe.timeoutSeconds // "default(1)")",
  "  liveness periodSeconds:   \(.livenessProbe.periodSeconds // "default(10)")"'
gcloud logging read \
  'resource.type="k8s_cluster"
   log_name="projects/'$PROJECT'/logs/events"
   jsonPayload.reason="Unhealthy"
   resource.labels.namespace_name="'$NAMESPACE'"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,jsonPayload.involvedObject.name,jsonPayload.message)" --limit=100
kube_read get nodes -o json 2>/dev/null | jq -r '
  .items[] | "\(.metadata.name): \(.status.conditions | map(select(.type=="Ready")) | .[0].status)"'
kube_read top nodes 2>/dev/null
manual "fetch k8s_container | metric 'kubernetes.io/container/cpu/limit_utilization' | filter resource.cluster_name == '$CLUSTER' && resource.namespace_name == '$NAMESPACE' && resource.pod_name =~ '$SERVICE.*' | within(30m, d'$T_UTC') | every 1m
Values >0.8 sustained = strong H10 signal."

section "H11 (Capacity Stockout) — Pending pods, stockout errors, quota, topology" "H16"
kube_read get pods -A --field-selector=status.phase=Pending -o wide 2>/dev/null | head -40
gcloud logging read \
  'resource.type="k8s_cluster"
   log_name="projects/'$PROJECT'/logs/events"
   jsonPayload.reason="FailedScheduling"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,jsonPayload.involvedObject.namespace,jsonPayload.involvedObject.name,jsonPayload.message)" --limit=100
STOCKOUT=$(gcloud logging read \
  'resource.type="gce_instance"
   protoPayload.methodName=~"compute\.instances\.(insert|bulkInsert)"
   protoPayload.response.error.errors.code=~"ZONE_RESOURCE_POOL_EXHAUSTED|RESOURCE_POOL_EXHAUSTED"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,protoPayload.response.error.errors.code,protoPayload.status.message)" --limit=100) && STOCKOUT_OK=1 || STOCKOUT_OK=0
printf '%s\n' "$STOCKOUT"
if [ "${CAP_LOGGING:-0}" = 0 ] || [ "$STOCKOUT_OK" = 0 ]; then
  STOCKOUT_HIT=0
  verdict UNKNOWN "H11: Cloud Logging unreadable — cannot detect ZONE_RESOURCE_POOL_EXHAUSTED; stockout can neither be confirmed nor ruled out."
elif printf '%s' "$STOCKOUT" | grep -q .; then
  STOCKOUT_HIT=1
  verdict FIRES-CRITICAL "H11: capacity stockout — GCE rejects instances.insert with ZONE_RESOURCE_POOL_EXHAUSTED; new nodes cannot be created and this will NOT self-resolve."
else
  STOCKOUT_HIT=0
  verdict CLEAR "H11: no ZONE_RESOURCE_POOL_EXHAUSTED/RESOURCE_POOL_EXHAUSTED in window (logging readable). If pods are still Pending, this is scale-up latency → see H16 below."
fi
gcloud container node-pools list --cluster="$CLUSTER" --location=$REGION --project=$PROJECT \
  --format="table(name,config.machineType,autoscaling.enabled,autoscaling.minNodeCount,autoscaling.maxNodeCount,locations)"

section "H16 (Scale-up Pending Latency) — pods Pending awaiting new nodes past grace"
# Distinct from H11: nodes CAN be created, but pods have waited too long for scale-up.
# Expected briefly (provisioning takes 1-5m); CRITICAL only once oldest Pending age >= grace
# AND there is no stockout (a stockout is H11, not latency).
PENDING_JSON=$(kube_read get pods -A --field-selector=status.phase=Pending -o json 2>/dev/null) && PENDING_OK=1 || PENDING_OK=0
printf '%s' "$PENDING_JSON" | jq -e '.items | type == "array"' >/dev/null 2>&1 || PENDING_OK=0
UNSCHED=$(printf '%s' "$PENDING_JSON" | jq '[.items[] | select(any(.status.conditions[]?; .type=="PodScheduled" and .status=="False"))] | length' 2>/dev/null || echo 0)
OLDEST_PENDING_S=$(printf '%s' "$PENDING_JSON" | jq -r --argjson now "$(date -u +%s)" '
  [ .items[]
    | select(any(.status.conditions[]?; .type=="PodScheduled" and .status=="False"))
    | (.status.conditions[] | select(.type=="PodScheduled") | .lastTransitionTime | fromdateiso8601) ]
  | if length==0 then 0 else ($now - min) end' 2>/dev/null || echo 0)
UNSCHED=${UNSCHED:-0}; OLDEST_PENDING_S=${OLDEST_PENDING_S:-0}   # jq emits empty (not 0) on empty stdin
GRACE_S=$(( PENDING_GRACE_MIN * 60 ))
echo "unschedulable pods=$UNSCHED  oldest Pending age=${OLDEST_PENDING_S}s  grace=${GRACE_S}s (${PENDING_GRACE_MIN}m)  stockout=${STOCKOUT_HIT:-0}"
# Was the autoscaler actually asked to scale up (TriggeredScaleUp → true H16) vs. refusing
# (NotTriggerScaleUp = max-nodes reached / pod fits no pool → that is H4, not H16)?
SCALEUP=$(gcloud logging read \
  'resource.type="k8s_cluster"
   log_name="projects/'$PROJECT'/logs/events"
   (jsonPayload.reason="TriggeredScaleUp" OR jsonPayload.reason="NotTriggerScaleUp")
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,jsonPayload.involvedObject.name,jsonPayload.reason,jsonPayload.message)" --limit=50) && SCALEUP_OK=1 || SCALEUP_OK=0
printf '%s\n' "$SCALEUP"
printf '%s' "$SCALEUP" | grep -q 'TriggeredScaleUp'  && TRIG=1    || TRIG=0
printf '%s' "$SCALEUP" | grep -q 'NotTriggerScaleUp' && NOTRIG=1  || NOTRIG=0
# NOTE: UNSCHED/OLDEST_PENDING_S are a LIVE kubectl snapshot (now), while the log queries above
# are windowed to T_START..T_END. For a past/recovered incident the numeric verdict may read
# "does not fire" even though the windowed TriggeredScaleUp/FailedScheduling events show the latency.
if [ "${CAP_K8S:-0}" = 0 ] || [ "$PENDING_OK" = 0 ]; then
  verdict UNKNOWN "H16: kubectl not targeting $CLUSTER — cannot measure Pending pods/age; scale-up latency can neither be confirmed nor ruled out."
elif [ "${UNSCHED:-0}" -gt 0 ] 2>/dev/null; then
  if [ "${STOCKOUT_HIT:-0}" = 1 ]; then
    verdict INFO "H16: the Pending pods are explained by the H11 stockout above (fix capacity, not latency)."
  elif [ "${OLDEST_PENDING_S:-0}" -ge "$GRACE_S" ] 2>/dev/null; then
    if [ "$STOCKOUT_OK" = 0 ] || [ "$SCALEUP_OK" = 0 ]; then
      verdict UNKNOWN "H16: stockout or scale-up query failed; cannot distinguish latency from blocked provisioning."
    elif [ "$TRIG" = 1 ]; then
      verdict FIRES-CRITICAL "H16: scale-up TRIGGERED but pods Pending ${OLDEST_PENDING_S}s >= grace ${GRACE_S}s with no stockout — new nodes are not arriving. Check 1g.4 quota, IP space (H12), or node boot failures."
    elif [ "$NOTRIG" = 1 ]; then
      verdict INFO "H16 → H4: autoscaler logged NotTriggerScaleUp (max-nodes reached or pod fits no pool); pods stay Pending until replicas/quota/pool-max change. Score under H4, not H16."
    elif [ "${CAP_LOGGING:-0}" = 0 ]; then
      verdict UNKNOWN "H16: pods Pending ${OLDEST_PENDING_S}s >= grace but the scale-up decision is unreadable (logging) — cannot separate H16 (latency) from H4 (declined scale-up)."
    else
      verdict FIRES-WARNING "H16: pods Pending ${OLDEST_PENDING_S}s >= grace, no stockout, no scale-up decision logged in window — confirm a scale-up was attempted (1g.1) before scoring H16 vs H4."
    fi
  else
    verdict INFO "H16 EXPECTED (not an incident yet): pods Pending within grace — autoscaler scale-up in progress. Re-run after ${PENDING_GRACE_MIN}m; fires CRITICAL only if still Pending."
  fi
else
  verdict CLEAR "H16: no unschedulable pods (kubectl readable)."
fi

section "H12 (Network/VPC) — Confirm pods/CoreDNS healthy (deep-dive queries already run in 1h)"
kube_read get pods -n "$NAMESPACE" -l "$POD_SELECTOR" -o wide 2>/dev/null | head
kube_read get pods -n kube-system -l k8s-app=kube-dns -o wide 2>/dev/null
note "H12's log/audit queries are identical to 1h.1-1h.5 above — see those sections."

section "B1/H13/H14/H15 (Billing & Node Reclamation) — outage span + REPAIR_CLUSTER op detail"
gcloud logging read \
  '(textPayload:"BILLING_DISABLED" OR textPayload:"requires billing to be enabled")
   timestamp>="'$T_START_CRITICAL'"' \
  --project=$PROJECT --order=asc --format="value(timestamp)" --limit=1
echo "^ FIRST billing-disabled occurrence (if any)"
gcloud logging read \
  '(textPayload:"BILLING_DISABLED" OR textPayload:"requires billing to be enabled")
   timestamp>="'$T_START_CRITICAL'"' \
  --project=$PROJECT --order=desc --format="value(timestamp)" --limit=1
echo "^ LAST billing-disabled occurrence (if any)"
gcloud logging read \
  'resource.type="gce_instance"
   protoPayload.methodName="v1.compute.instances.delete"
   protoPayload.resourceName:"gke-'$CLUSTER'-"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --format="value(timestamp)" --limit=500 | awk '{print substr($1,1,16)}' | sort | uniq -c
echo "^ node VM delete count per minute"
gcloud logging read \
  'resource.type="gce_instance" protoPayload.methodName="v1.compute.instances.delete"
   protoPayload.resourceName:"gke-'$CLUSTER'-" timestamp>="'$T_START'" timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc --limit=1 \
  --format="value(protoPayload.authenticationInfo.principalEmail,protoPayload.requestMetadata.callerSuppliedUserAgent)"
echo "^ actor of first delete (expect cloudservices SA / 'GCE Managed Instance Group for GKE')"
cluster_ops | grep -Ei "REPAIR_CLUSTER|UPGRADE|SET_NODE_POOL_SIZE" | head
echo "^ THIS cluster's repair/upgrade/resize ops (operationType, status, startTime, endTime)"

section "Done"
echo "Collector finished. Interpret each ===== section ===== against the corresponding table in inspect-incident.md."
echo "gke-collect: report complete → $REPORT" >&3
