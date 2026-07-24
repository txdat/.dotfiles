#!/usr/bin/env bash
# gke-collect.sh — single-pass, read-only evidence collector for the gke-service-incident skill.
#
# Runs the full Phase 1 broad sweep (1a-1i) plus every auto-discoverable Phase 3 deep-dive query,
# and prints results under "===== <section> =====" headers that map 1:1 to the interpretation
# tables in service-incident.md. Nothing here mutates cluster or project state.
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
         | grep -oiE '\b(B1|H1[0-6]|H[1-9])\b' | tr 'a-z' 'A-Z' | sort -uV | paste -sd' ' -)
  if [ -n "$hyps" ]; then
    printf '\n===== %s =====  {HYP: %s}\n' "$title" "$hyps"
  else
    printf '\n===== %s =====\n' "$title"
  fi
}
note()    { printf '[NOTE] %s\n' "$1"; }
manual()  { printf '[MANUAL: Cloud Console Metrics Explorer — MQL]\n%s\n' "$1"; }

# Tri-state verdict — grep -F '[VERDICT:' for a one-line summary of every detector.
#   FIRES-CRITICAL / FIRES-WARNING = signal present (still needs corroboration before RCA)
#   CLEAR   = data source was readable AND the condition did not hold (a real negative)
#   UNKNOWN = the data source was unreadable (auth/IAM/context/log gap) — CANNOT rule out
#   INFO    = condition held but a benign cause (planned op / recovered state) explains it
verdict() { printf '[VERDICT: %s] %s\n' "$1" "$2"; }

# Planned/benign GKE ops overlapping the critical window — used as false-positive guards for
# H13/H14/H15 (a delete/rebuild during a planned resize/upgrade/repair is intentional cycling,
# not reclamation). Overlap = op started before window end AND (still running OR ended after start).
planned_ops_in_window() {
  gcloud container operations list --project="$PROJECT" --region="$REGION" \
    --format="value(operationType,status,startTime,endTime)" 2>/dev/null \
  | awk -v s="$T_START_CRITICAL" -v e="$T_END" \
      '($1=="SET_NODE_POOL_SIZE" || $1 ~ /^UPGRADE/ || $1=="REPAIR_CLUSTER") \
       && $3<=e && ($4=="" || $4>=s) { print $1"@"$3 }'
}

GET_CREDENTIALS=0
[ "${1:-}" = "--get-credentials" ] && GET_CREDENTIALS=1

# ============================================================================
# Pre-Flight — resolve inputs (mirrors service-incident.md Pre-Flight exactly)
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
for bin in gcloud kubectl jq; do
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
T_START=$(date -u -d "$T_UTC - 30 minutes" +%Y-%m-%dT%H:%M:%SZ)

if [ -z "$T_DURATION" ] || [ "$T_DURATION" = "now" ]; then
  T_END=$(date -u +%Y-%m-%dT%H:%M:%SZ)
else
  T_END=$(date -u -d "$T_UTC + $T_DURATION + 10 minutes" +%Y-%m-%dT%H:%M:%SZ)
fi

T_START_MINUS_2H=$(date -u -d "$T_UTC - 2 hours" +%Y-%m-%dT%H:%M:%SZ)
T_CRITICAL_LOOKBACK="${T_CRITICAL_LOOKBACK:-6 hours}"
T_START_CRITICAL=$(date -u -d "$T_UTC - $T_CRITICAL_LOOKBACK" +%Y-%m-%dT%H:%M:%SZ)
NODE_DELETE_BURST="${NODE_DELETE_BURST:-3}"
NOTREADY_MAX="${NOTREADY_MAX:-2}"
AGE_RESET_FRAC="${AGE_RESET_FRAC:-0.5}"
PENDING_GRACE_MIN="${PENDING_GRACE_MIN:-10}"   # H16: minutes a pod may sit Pending awaiting scale-up before CRITICAL
LB_LOG_LIMIT="${LB_LOG_LIMIT:-5000}"           # 1d.2: max LB log entries read for the 5xx-ratio aggregation

# All collected evidence goes to a single report file the agent then reads; only the
# path (and any fatal pre-flight error above) reaches the terminal. Override with $REPORT.
REPORT="${REPORT:-/tmp/gke-incident-${CLUSTER}-$(date -u +%Y%m%dT%H%M%SZ).txt}"
exec 3>&1                 # fd 3 = real terminal
echo "gke-collect: writing report to $REPORT" >&3
exec >"$REPORT" 2>&1      # stdout+stderr of the sweep now land in the report file

section "Pre-Flight — Resolved Inputs"
echo "PROJECT=$PROJECT CLUSTER=$CLUSTER REGION=$REGION NAMESPACE=$NAMESPACE"
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
  gcloud container clusters get-credentials "$CLUSTER" --region "$REGION" --project "$PROJECT"
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
gcloud compute regions describe "$REGION" --project="$PROJECT" --format='value(name)' >/dev/null 2>&1 \
  && CAP_COMPUTE=1 || CAP_COMPUTE=0
gcloud container operations list --project="$PROJECT" --region="$REGION" --limit=1 >/dev/null 2>&1 \
  && CAP_OPS=1 || CAP_OPS=0
BILLING_NOW=$(gcloud billing projects describe "$PROJECT" --format='value(billingEnabled)' 2>/dev/null) \
  && CAP_BILLING=1 || CAP_BILLING=0    # one call: capture current state and readability together
if kubectl cluster-info --request-timeout=5s >/dev/null 2>&1; then CAP_KUBECTL=1; else CAP_KUBECTL=0; fi
CUR_CTX=$(kubectl config current-context 2>/dev/null)
case "$CUR_CTX" in *"_${CLUSTER}") CAP_KUBECTL_CTX=1 ;; *) CAP_KUBECTL_CTX=0 ;; esac
[ "$CAP_KUBECTL" = 1 ] && [ "$CAP_KUBECTL_CTX" = 1 ] && CAP_K8S=1 || CAP_K8S=0
echo "CAP_LOGGING=$CAP_LOGGING (Cloud Logging read: log-based detectors B1/H13-partial/H14/H1-H12 audit)"
echo "CAP_COMPUTE=$CAP_COMPUTE (Compute read: quota 1g.4, node instance-id, stockout)"
echo "CAP_OPS=$CAP_OPS (container operations: H13 ops, planned-op guards)"
echo "CAP_BILLING=$CAP_BILLING (Cloud Billing read: B1 current-state guard)  billingEnabled_now=${BILLING_NOW:-<unreadable>}"
echo "CAP_KUBECTL=$CAP_KUBECTL  CAP_KUBECTL_CTX=$CAP_KUBECTL_CTX (context '$CUR_CTX' targets '$CLUSTER'?)  CAP_K8S=$CAP_K8S (live kubectl detectors H1/H2/H5/H15/H16)"
[ "$CAP_LOGGING" = 0 ] && verdict UNKNOWN "Cloud Logging unreadable — ALL log-based detectors are UNKNOWN, not CLEAR. Grant roles/logging.viewer (+ privateLogViewer for Data Access) and re-run."
[ "$CAP_K8S" = 0 ] && verdict UNKNOWN "kubectl not targeting $CLUSTER (or unreachable) — live cluster-state detectors are UNKNOWN. Re-run with --get-credentials (after confirming) or fix the context."

# ============================================================================
# Auto-discovery — read-only, feeds Phase 3 deep-dives
# ============================================================================
section "Auto-discovery"
POD_SELECTOR_RAW=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.spec.selector.matchLabels}' 2>/dev/null)
POD_SELECTOR=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o json 2>/dev/null | \
  jq -r '.spec.selector.matchLabels | to_entries | map("\(.key)=\(.value)") | join(",")' 2>/dev/null)
[ -z "$POD_SELECTOR" ] || [ "$POD_SELECTOR" = "null" ] && POD_SELECTOR="app=$SERVICE"
echo "POD_SELECTOR=$POD_SELECTOR (raw matchLabels: $POD_SELECTOR_RAW)"

POD_NAME="${POD_NAME:-$(kubectl get pods -n "$NAMESPACE" -l "$POD_SELECTOR" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)}"
echo "POD_NAME=${POD_NAME:-<none found>}"

NODE_NAME=""
NODE_ZONE=""
NODE_INSTANCE_ID=""
if [ -n "$POD_NAME" ]; then
  NODE_NAME=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.nodeName}' 2>/dev/null)
  # GKE nodes carry no instance_id annotation — derive the numeric GCE id from providerID
  # (gce://PROJECT/ZONE/INSTANCE_NAME; the node name is the instance name).
  PROVIDER_ID=$(kubectl get node "$NODE_NAME" -o jsonpath='{.spec.providerID}' 2>/dev/null)
  NODE_ZONE=$(printf '%s' "$PROVIDER_ID" | awk -F/ '{print $(NF-1)}')
  if [ -n "$NODE_NAME" ] && [ -n "$NODE_ZONE" ]; then
    NODE_INSTANCE_ID=$(gcloud compute instances describe "$NODE_NAME" --zone="$NODE_ZONE" --project="$PROJECT" --format="value(id)" 2>/dev/null || true)
  fi
fi
echo "NODE_NAME=${NODE_NAME:-<none>}  NODE_ZONE=${NODE_ZONE:-<none>}  NODE_INSTANCE_ID=${NODE_INSTANCE_ID:-<none — substitute manually from an eviction event>}"

LB_NAME="${LB_NAME:-}"
LB_BACKEND_NAME="${LB_BACKEND_NAME:-}"
INGRESS_IP=$(kubectl get ingress -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.status.loadBalancer.ingress[*].ip}{"\n"}{end}' 2>/dev/null | head -1)
if [ -z "$LB_NAME" ] && [ -n "$INGRESS_IP" ]; then
  LB_NAME=$(gcloud compute forwarding-rules list --project="$PROJECT" --filter="IPAddress=$INGRESS_IP" --format="value(name)" 2>/dev/null | head -1)
fi
if [ -n "$LB_NAME" ] && [ -z "$LB_BACKEND_NAME" ]; then
  LB_TARGET=$(gcloud compute forwarding-rules describe "$LB_NAME" --project="$PROJECT" --global --format="value(target)" 2>/dev/null || \
              gcloud compute forwarding-rules describe "$LB_NAME" --project="$PROJECT" --region="$REGION" --format="value(target)" 2>/dev/null)
  LB_BACKEND_NAME=$(gcloud compute backend-services list --project="$PROJECT" --format="value(name)" 2>/dev/null | head -1)
fi
echo "LB_NAME=${LB_NAME:-<not discovered — see 1d step 1 output below>}  LB_BACKEND_NAME=${LB_BACKEND_NAME:-<not discovered>}"

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
kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.spec.selector.matchLabels}' 2>/dev/null && echo
kubectl get pods -n "$NAMESPACE" -l "$POD_SELECTOR" -o json 2>/dev/null | jq -r '
  .items[] | .metadata.name as $pod |
  .status.containerStatuses[]? |
  [$pod, .name, .ready, .restartCount,
   .lastState.terminated.reason // "-",
   .lastState.terminated.exitCode // "-",
   .lastState.terminated.finishedAt // "-"] | @tsv' | \
  column -t -s $'\t' -N POD,CONTAINER,READY,RESTARTS,REASON,EXIT,FINISHED

section "1c — Endpoint Availability" "H2"
kubectl get endpoints -n "$NAMESPACE"
kubectl describe endpoints -n "$NAMESPACE" 2>/dev/null | grep -A5 -E "^Name:|Addresses:|NotReadyAddresses:"
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
kubectl get ingress -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.loadBalancer.ingress[*].ip}{"\n"}{end}' 2>/dev/null
kubectl get service "$SERVICE" -n "$NAMESPACE" -o jsonpath='{.metadata.annotations.cloud\.google\.com/neg}' 2>/dev/null && echo
gcloud compute network-endpoint-groups list --project=$PROJECT --format="table(name,zone,size)" 2>/dev/null | grep -i "$SERVICE" || true

LB_LOGGING_ENABLED="false"
if [ -n "$LB_BACKEND_NAME" ]; then
  LB_LOGGING_ENABLED=$(gcloud compute backend-services describe "$LB_BACKEND_NAME" --global --project=$PROJECT --format="value(logConfig.enable)" 2>/dev/null || echo false)
fi
echo "LB_BACKEND_NAME=$LB_BACKEND_NAME  logConfig.enable=$LB_LOGGING_ENABLED"

if [ -n "$LB_NAME" ] && [ "$LB_LOGGING_ENABLED" = "true" ]; then
  # One read, three aggregations: per minute, per backend service, and a truncation guard.
  # Per-backend matters because the ratio's denominator is the whole forwarding rule — one dead
  # service behind a shared LB is diluted by its healthy siblings.
  section "1d.2 — LB Request Rate & 5xx Ratio (per minute, per backend)"
  gcloud logging read \
    'resource.type="http_load_balancer"
     resource.labels.forwarding_rule_name="'$LB_NAME'"
     timestamp>="'$T_START'"
     timestamp<="'$T_END'"' \
    --project=$PROJECT --order=asc \
    --format="value(timestamp,httpRequest.status,resource.labels.backend_service_name)" \
    --limit=$LB_LOG_LIMIT | \
    awk -F'\t' -v lim="$LB_LOG_LIMIT" '
      {
        m=substr($1,1,16); b=($3==""?"(no-backend-matched)":$3); is5=($2+0>=500)
        tot[m]++; btot[b]++; T++
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
        for (b in btot) printf "%-45s total=%-6d 5xx=%-6d 5xx_ratio=%.1f%%\n", \
          b, btot[b], berr[b]+0, 100*(berr[b]+0)/btot[b] | "sort"
        close("sort")
        printf "\nWINDOW_TOTAL  total=%d 5xx=%d 5xx_ratio=%.1f%%\n", T, E+0, 100*(E+0)/T
        if (T>=lim)
          printf "[NOTE] Read hit --limit=%d and is ordered ASC: these numbers cover only the EARLIEST %d requests of the window, not all of it. Ratios are biased toward incident onset. Narrow T_START/T_END or raise $LB_LOG_LIMIT before trusting the window ratio.\n", lim, lim
      }'

  section "1d.3 — LB 5xx Breakdown"
  gcloud logging read \
    'resource.type="http_load_balancer"
     resource.labels.forwarding_rule_name="'$LB_NAME'"
     httpRequest.status>=500
     timestamp>="'$T_START'"
     timestamp<="'$T_END'"' \
    --project=$PROJECT --order=asc \
    --format="table(timestamp,httpRequest.status,httpRequest.latency,jsonPayload.statusDetails,httpRequest.requestUrl)" \
    --limit=1000

  section "1d.4 — LB Latency Distribution"
  gcloud logging read \
    'resource.type="http_load_balancer"
     resource.labels.forwarding_rule_name="'$LB_NAME'"
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

  section "1d.5 — LB statusDetails"
  gcloud logging read \
    'resource.type="http_load_balancer"
     resource.labels.forwarding_rule_name="'$LB_NAME'"
     httpRequest.status>=500
     timestamp>="'$T_START'"
     timestamp<="'$T_END'"' \
    --project=$PROJECT --format="value(jsonPayload.statusDetails)" --limit=1000 | sort | uniq -c | sort -rn

else
  note "1d steps 2-5 skipped: LB_NAME not discovered or logConfig.enable=false. Set \$LB_NAME/\$LB_BACKEND_NAME and re-run, or run the LB queries manually (see skill 1d)."
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
  'resource.type="gce_instance" OR resource.type="gke_cluster"
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
gcloud container clusters describe "$CLUSTER" --region=$REGION --project=$PROJECT \
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
gcloud compute regions describe "$REGION" --project=$PROJECT \
  --format="table(quotas.metric,quotas.usage,quotas.limit)" | grep -iE "CPUS|IN_USE_ADDRESSES" || true

section "1g.5 — Node Pool Topology" "H11 H15 H16"
gcloud container node-pools list --cluster="$CLUSTER" --region=$REGION --project=$PROJECT \
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
  'resource.type="gce_subnetwork" OR (resource.type="gce_instance" AND protoPayload.response.error.errors.code="IP_SPACE_EXHAUSTED")
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,protoPayload.methodName,protoPayload.status.message)" --limit=50
gcloud container clusters describe "$CLUSTER" --region=$REGION --project=$PROJECT \
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
  --format="table(timestamp,resource.type,textPayload)" --limit=50)
printf '%s\n' "$BILLING_LOG"
gcloud billing projects describe "$PROJECT" --format="value(billingEnabled,billingAccountName)" 2>/dev/null
gcloud logging read \
  'protoPayload.serviceName="cloudbilling.googleapis.com"
   protoPayload.methodName=~"UpdateBillingInfo|AssignResourceToBillingAccount|DisableResourceBilling"
   timestamp>="'$T_START_MINUS_2H'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,protoPayload.methodName,protoPayload.authenticationInfo.principalEmail)" --limit=20
if [ "${CAP_LOGGING:-0}" = 0 ]; then
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
  H13_OPS=$(gcloud container operations list --project=$PROJECT --region=$REGION \
    --format="value(operationType,status,startTime,endTime)" \
    | awk -v s="$T_START_CRITICAL" -v e="$T_END" '$3>=s && $3<=e && ($1=="REPAIR_CLUSTER" || $1 ~ /^UPGRADE/) {print}')
  printf '%s\n' "$H13_OPS"
  # maintenance-window guard: a scheduled UPGRADE inside the cluster's window is expected, not an incident.
  MAINT=$(gcloud container clusters describe "$CLUSTER" --region=$REGION --project=$PROJECT \
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
  [ "$H13_REP" = 0 ] && [ "$H13_UP" = 0 ] && verdict CLEAR "H13: no in-window REPAIR_CLUSTER/UPGRADE_* op (operations readable)."
fi

section "1i — H14 Node VM Delete Burst"
if [ "${CAP_LOGGING:-0}" = 0 ]; then
  verdict UNKNOWN "H14: Cloud Logging unreadable — cannot count node-delete events (note: these are Admin Activity logs, always emitted; the gap is read permission)."
else
  DEL=$(gcloud logging read \
    'resource.type="gce_instance"
     protoPayload.methodName=~"compute\.instances\.delete"
     protoPayload.resourceName:"gke-'$CLUSTER'-"
     protoPayload.authenticationInfo.principalEmail=~"cloudservices\.gserviceaccount\.com"
     timestamp>="'$T_START'"
     timestamp<="'$T_END'"' \
    --project=$PROJECT --format="value(timestamp)" --limit=500 | wc -l)
  echo "in-window MIG node VM deletes: $DEL (burst threshold $NODE_DELETE_BURST)"
  PLANNED_OP=$(planned_ops_in_window | head -1)
  GUARD_NOTE=""; [ "${CAP_OPS:-0}" = 0 ] && GUARD_NOTE=" [planned-op guard unavailable — CAP_OPS=0]"
  if [ "$DEL" -ge "$NODE_DELETE_BURST" ]; then
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
kubectl get nodes -o wide
POOLS=$(gcloud container node-pools list --cluster="$CLUSTER" --region=$REGION --project=$PROJECT \
  --format="value(name,autoscaling.minNodeCount)" 2>/dev/null)
printf '%s\n' "$POOLS"
MIN_SUM=$(printf '%s\n' "$POOLS" | awk '{s+=$2} END{print s+0}')   # $2 = per-zone minNodeCount
NODES_JSON=$(kubectl get nodes -o json 2>/dev/null)
NODES=$(printf '%s' "$NODES_JSON" | jq '.items | length' 2>/dev/null || echo 0)
NOTREADY=$(printf '%s' "$NODES_JSON" | jq '[.items[] | select((.status.conditions[]? | select(.type=="Ready") | .status) != "True")] | length' 2>/dev/null || echo 0)
YOUNG=$(printf '%s' "$NODES_JSON" | jq --arg t "$T_START" '[.items[] | select(.metadata.creationTimestamp > $t)] | length' 2>/dev/null || echo 0)
NODES=${NODES:-0}; NOTREADY=${NOTREADY:-0}; YOUNG=${YOUNG:-0}   # jq emits empty (not 0) on empty stdin
echo "nodes=$NODES notReady=$NOTREADY young=$YOUNG  minNodeCount_sum=${MIN_SUM:-?} (frac threshold $AGE_RESET_FRAC, NotReady threshold $NOTREADY_MAX)"
if [ "${CAP_K8S:-0}" = 0 ]; then
  verdict UNKNOWN "H15: kubectl not targeting $CLUSTER — node count/NotReady/age all unavailable; cannot rule out reclamation."
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
  kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{range .spec.containers[*]}{.name}{"\n"}{end}' 2>/dev/null
  kubectl logs "$POD_NAME" -n "$NAMESPACE" --previous --timestamps=true 2>/dev/null | tail -300
  kubectl get pod "$POD_NAME" -n "$NAMESPACE" \
    -o jsonpath='{range .spec.containers[*]}{.name}{"\t"}{"req: "}{.resources.requests.memory}{"\t"}{"lim: "}{.resources.limits.memory}{"\n"}{end}' 2>/dev/null
else
  note "POD_NAME not discovered — set \$POD_NAME to the crashing pod and re-run for previous logs/limits."
fi
kubectl describe vpa -n "$NAMESPACE" 2>/dev/null
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
kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o json 2>/dev/null | jq -r '
  .spec.template.spec.containers[] |
  "Container: \(.name)",
  "  startup:   \(.startupProbe // "none" | if type == "object" then tojson else . end)",
  "  liveness:  \(.livenessProbe // "none" | if type == "object" then tojson else . end)",
  "  readiness: \(.readinessProbe // "none" | if type == "object" then tojson else . end)"'

section "H2 (Probe Failure) — Restart count / sub-variant + endpoint oscillation + app warnings"
kubectl get pods -n "$NAMESPACE" -l "$POD_SELECTOR" -o json 2>/dev/null | jq -r '
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
kubectl get nodes -o wide
kubectl get nodes -o json 2>/dev/null | jq -r '
  .items[] | "\(.metadata.name): \(.status.conditions | map(select(.status=="True")) | map(.type) | join(", "))"'

section "H4 (HPA/Quota) — HPA state, scale events, autoscaler, FailedScheduling, top pods, quota"
kubectl get hpa -n "$NAMESPACE" 2>/dev/null
kubectl describe hpa -n "$NAMESPACE" 2>/dev/null
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
kubectl top pods -n "$NAMESPACE" 2>/dev/null
kubectl describe resourcequota -n "$NAMESPACE" 2>/dev/null

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
kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
  -o jsonpath='{range .spec.template.spec.containers[*]}{.name}{"\n"}{range .env[*]}{.name}{" = "}{.value}{"\n"}{end}{"\n"}{end}' 2>/dev/null | \
  grep -iE "pool|conn|database|db_max|max_conn|pg_pool|hikari|c3p0|drizzle"

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
gcloud redis instances list --region=$REGION --project=$PROJECT \
  --format="table(name,tier,memorySizeGb,host,port,state,redisVersion)" 2>/dev/null
gcloud logging read \
  'resource.type="redis_instance"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,severity,protoPayload.methodName,jsonPayload.message,textPayload)" --limit=100
kubectl get pods -n "$NAMESPACE" -o json 2>/dev/null | jq -r '
  .items[] | select(.metadata.name | test("'$SERVICE'") | not) |
  [.metadata.name,
   ([.status.containerStatuses[]?.restartCount] | add // 0),
   ([.status.containerStatuses[]?.ready] | all)] | @tsv' | \
  column -t -s $'\t' -N POD,RESTARTS,READY | head -20
kubectl get pods -n "$NAMESPACE" -l "$POD_SELECTOR" -o wide 2>/dev/null | head
manual "fetch redis_instance | metric 'redis.googleapis.com/stats/memory/usage_ratio' -- also clients/connected, clients/blocked, stats/reject_connections_count, stats/evicted_keys, stats/cpu_utilization, replication/master_slave_lag | filter resource.instance_id =~ '.*' | within(30m, d'$T_UTC') | every 1m"

section "H7 (Bad Deploy) — New pod status, failure events, missing refs, rollout history"
kubectl get pods -n "$NAMESPACE" -l "$POD_SELECTOR" -o json 2>/dev/null | jq -r '
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
kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o json 2>/dev/null | jq -r '
  .spec.template.spec |
  (.containers[].env[]?.valueFrom.secretKeyRef.name // empty),
  (.containers[].env[]?.valueFrom.configMapKeyRef.name // empty),
  (.volumes[]?.secret.secretName // empty),
  (.volumes[]?.configMap.name // empty)' | sort -u | while read -r ref; do
    [ -z "$ref" ] && continue
    kubectl get secret "$ref" -n "$NAMESPACE" 2>/dev/null >/dev/null || kubectl get configmap "$ref" -n "$NAMESPACE" 2>/dev/null >/dev/null || echo "MISSING: $ref"
done
kubectl rollout history deployment/"$DEPLOYMENT" -n "$NAMESPACE" 2>/dev/null

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
kubectl get serviceaccount -n "$NAMESPACE" -o json 2>/dev/null | jq -r '
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
DEPLOY_KSA=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.serviceAccountName}' 2>/dev/null)
DEPLOY_KSA="${DEPLOY_KSA:-default}"
GSA_EMAIL=$(kubectl get serviceaccount "$DEPLOY_KSA" -n "$NAMESPACE" -o jsonpath='{.metadata.annotations.iam\.gke\.io/gcp-service-account}' 2>/dev/null)
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
kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide 2>/dev/null
kubectl get pods -n kube-system -l k8s-app=kube-dns -o json 2>/dev/null | jq -r '
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
kubectl top pods -n kube-system -l k8s-app=kube-dns 2>/dev/null
gcloud logging read \
  'resource.type="k8s_cluster"
   log_name="projects/'$PROJECT'/logs/events"
   jsonPayload.involvedObject.namespace="kube-system"
   jsonPayload.reason=~"OOMKilling|Unhealthy|BackOff"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT --order=asc \
  --format="table(timestamp,jsonPayload.involvedObject.name,jsonPayload.reason,jsonPayload.message)" --limit=50
kubectl get configmap coredns -n kube-system -o yaml 2>/dev/null

section "H10 (CPU Throttling) — CPU limits, probe timeoutSeconds, Unhealthy events, node CPU"
kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
  -o jsonpath='{range .spec.template.spec.containers[*]}{.name}{"\t"}{"req: "}{.resources.requests.cpu}{"\t"}{"lim: "}{.resources.limits.cpu}{"\n"}{end}' 2>/dev/null
kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o json 2>/dev/null | jq -r '
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
kubectl get nodes -o json 2>/dev/null | jq -r '
  .items[] | "\(.metadata.name): \(.status.conditions | map(select(.type=="Ready")) | .[0].status)"'
kubectl top nodes 2>/dev/null
manual "fetch k8s_container | metric 'kubernetes.io/container/cpu/limit_utilization' | filter resource.cluster_name == '$CLUSTER' && resource.namespace_name == '$NAMESPACE' && resource.pod_name =~ '$SERVICE.*' | within(30m, d'$T_UTC') | every 1m
Values >0.8 sustained = strong H10 signal."

section "H11 (Capacity Stockout) — Pending pods, stockout errors, quota, topology" "H16"
kubectl get pods -A --field-selector=status.phase=Pending -o wide 2>/dev/null | head -40
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
  --format="table(timestamp,protoPayload.response.error.errors.code,protoPayload.status.message)" --limit=100)
printf '%s\n' "$STOCKOUT"
if [ "${CAP_LOGGING:-0}" = 0 ]; then
  STOCKOUT_HIT=0
  verdict UNKNOWN "H11: Cloud Logging unreadable — cannot detect ZONE_RESOURCE_POOL_EXHAUSTED; stockout can neither be confirmed nor ruled out."
elif printf '%s' "$STOCKOUT" | grep -q .; then
  STOCKOUT_HIT=1
  verdict FIRES-CRITICAL "H11: capacity stockout — GCE rejects instances.insert with ZONE_RESOURCE_POOL_EXHAUSTED; new nodes cannot be created and this will NOT self-resolve."
else
  STOCKOUT_HIT=0
  verdict CLEAR "H11: no ZONE_RESOURCE_POOL_EXHAUSTED/RESOURCE_POOL_EXHAUSTED in window (logging readable). If pods are still Pending, this is scale-up latency → see H16 below."
fi
gcloud container node-pools list --cluster="$CLUSTER" --region=$REGION --project=$PROJECT \
  --format="table(name,config.machineType,autoscaling.enabled,autoscaling.minNodeCount,autoscaling.maxNodeCount,locations)"

section "H16 (Scale-up Pending Latency) — pods Pending awaiting new nodes past grace"
# Distinct from H11: nodes CAN be created, but pods have waited too long for scale-up.
# Expected briefly (provisioning takes 1-5m); CRITICAL only once oldest Pending age >= grace
# AND there is no stockout (a stockout is H11, not latency).
PENDING_JSON=$(kubectl get pods -A --field-selector=status.phase=Pending -o json 2>/dev/null)
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
  --format="table(timestamp,jsonPayload.involvedObject.name,jsonPayload.reason,jsonPayload.message)" --limit=50)
printf '%s\n' "$SCALEUP"
printf '%s' "$SCALEUP" | grep -q 'TriggeredScaleUp'  && TRIG=1    || TRIG=0
printf '%s' "$SCALEUP" | grep -q 'NotTriggerScaleUp' && NOTRIG=1  || NOTRIG=0
# NOTE: UNSCHED/OLDEST_PENDING_S are a LIVE kubectl snapshot (now), while the log queries above
# are windowed to T_START..T_END. For a past/recovered incident the numeric verdict may read
# "does not fire" even though the windowed TriggeredScaleUp/FailedScheduling events show the latency.
if [ "${CAP_K8S:-0}" = 0 ]; then
  verdict UNKNOWN "H16: kubectl not targeting $CLUSTER — cannot measure Pending pods/age; scale-up latency can neither be confirmed nor ruled out."
elif [ "${UNSCHED:-0}" -gt 0 ] 2>/dev/null; then
  if [ "${STOCKOUT_HIT:-0}" = 1 ]; then
    verdict INFO "H16: the Pending pods are explained by the H11 stockout above (fix capacity, not latency)."
  elif [ "${OLDEST_PENDING_S:-0}" -ge "$GRACE_S" ] 2>/dev/null; then
    if [ "$TRIG" = 1 ]; then
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
kubectl get pods -n "$NAMESPACE" -l "$POD_SELECTOR" -o wide 2>/dev/null | head
kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide 2>/dev/null
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
gcloud container operations list --project=$PROJECT --region=$REGION \
  --format="value(name,operationType,status,startTime,endTime)" | grep -Ei "REPAIR_CLUSTER|UPGRADE|SET_NODE_POOL_SIZE" | head

section "Done"
echo "Collector finished. Interpret each ===== section ===== against the corresponding table in service-incident.md."
echo "gke-collect: report complete → $REPORT" >&3
