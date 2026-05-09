---
name: gke-pod-restarts
description: "Use this skill to investigate GKE incidents involving pod restart cascades, 503/504 errors, service unavailability, or CrashLoopBackOff. Triggers: 'pods keep restarting', '503/504 errors', 'service is down', 'crash loop', 'what caused the incident at <time>'. Inputs required: GCP project, cluster name+region, namespace, service/deployment names, approximate incident time + timezone. All commands are read-only. Never mutate cluster state."
model: gpt-5.3-codex
effort: medium
---

# GKE Incident Investigator

**Method**: Observe → Hypothesize → Falsify → Confirm. Data drives queries. ≥2 independent signals to confirm. Missing expected signal = evidence against.

---

## Required Inputs (all 7 mandatory)

```
PROJECT     = <gcp-project-id>
CLUSTER     = <cluster-name>
REGION      = <cluster-region>     # zonal: use ZONE + --zone flag
NAMESPACE   = <namespace>
SERVICE     = <k8s Service name>   # for endpoints/LB queries
DEPLOYMENT  = <Deployment name>    # for rollout/probe queries
T_USER      = <incident time>
T_TZ        = <timezone>
```

Window: [T_UTC - 30min, T_UTC + 30min]. Deploy lookback: T_UTC - 2h.
```bash
# Convert user time to UTC (adjust TZ value to user's timezone)
T_UTC=$(TZ=UTC date -d "TZ=\"$T_TZ\" $T_USER" +%Y-%m-%dT%H:%M:%SZ)
T_START=$(date -u -d "$T_UTC - 30 minutes" +%Y-%m-%dT%H:%M:%SZ)
T_END=$(date -u -d "$T_UTC + 30 minutes" +%Y-%m-%dT%H:%M:%SZ)
T_START_MINUS_2H=$(date -u -d "$T_UTC - 2 hours" +%Y-%m-%dT%H:%M:%SZ)
```

---

## Phase 0 — Auth Validation (Blocking)

```bash
gcloud auth list --filter="status:ACTIVE" --format="value(account)"
gcloud config get-value project
gcloud container clusters get-credentials $CLUSTER --region $REGION --project $PROJECT
kubectl config current-context   # must contain cluster name
kubectl cluster-info --request-timeout=5s
```

---

## Phase 1 — Broad Sweep (Run All)

### 1a — K8s Warning Events

```bash
gcloud logging read \
  'resource.type="k8s_cluster"
   log_name="projects/'$PROJECT'/logs/events"
   severity>=WARNING
   resource.labels.cluster_name="'$CLUSTER'"
   resource.labels.namespace_name="'$NAMESPACE'"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT \
  --order=asc \
  --format="table(timestamp,jsonPayload.involvedObject.name,jsonPayload.reason,jsonPayload.message)" \
  --limit=300
```

**Event → Hypothesis mapping:**
| Reason | H |
|--------|---|
| `OOMKilling` | H1 |
| `Unhealthy`, `Killing` | H2 |
| `BackOff`, `CrashLoopBackOff` | H1/H7 |
| `Evicted`, `NodeNotReady` | H3 |
| `FailedScheduling` | H3/H4 |
| `ScalingReplicaSet` | H4/H7 |
| `FailedMount`, `FailedAttachVolume`, `CreateContainerConfigError` | H7 |

Node-scoped events (not namespaced):

```bash
gcloud logging read \
  'resource.type="k8s_cluster"
   log_name="projects/'$PROJECT'/logs/events"
   resource.labels.cluster_name="'$CLUSTER'"
   jsonPayload.reason=~"NodeNotReady|NodeHasInsufficientMemory|NodeHasDiskPressure|NodeHasPIDPressure|EvictionThreshold"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT \
  --order=asc \
  --format="table(timestamp,jsonPayload.involvedObject.name,jsonPayload.reason,jsonPayload.message)" \
  --limit=100
```

### 1b — Pod Restart Fingerprint

```bash
# Verify actual label selector before assuming app=$SERVICE
kubectl get deployment $DEPLOYMENT -n $NAMESPACE \
  -o jsonpath='{.spec.selector.matchLabels}' && echo
# Use the selector output to set POD_SELECTOR (e.g., "app=my-service" or "app.kubernetes.io/name=my-service")

# Pod restart details — handles multi-container pods cleanly
kubectl get pods -n $NAMESPACE -l $POD_SELECTOR -o json | jq -r '
  .items[] | .metadata.name as $pod |
  .status.containerStatuses[]? |
  [$pod, .name, .ready, .restartCount,
   .lastState.terminated.reason // "-",
   .lastState.terminated.exitCode // "-",
   .lastState.terminated.finishedAt // "-"] | @tsv' | \
  column -t -s $'\t' -N POD,CONTAINER,READY,RESTARTS,REASON,EXIT,FINISHED
```

**Exit codes:**
| Code | Signal | Hypothesis |
|------|--------|------------|
| `137` | SIGKILL | H1 (OOM) or H2 liveness (ignored SIGTERM) |
| `143` | SIGTERM caught | H3/H7 eviction, H2 liveness |
| `0` | Clean exit | H2 liveness (check Unhealthy event) |
| `1`/`2` | App error | H2/H5/H6 |
| `139` | SIGSEGV | H7 (code bug) |

Liveness kill: SIGTERM → grace period → SIGKILL. Exit 0/143 = responded. Exit 137 = force-killed. Confirm via `Unhealthy/Liveness` event.

### 1c — Endpoint Availability

```bash
kubectl get endpoints -n $NAMESPACE

kubectl describe endpoints -n $NAMESPACE | \
  grep -A5 -E "^Name:|Addresses:|NotReadyAddresses:"

# Endpoint mutations in audit log
gcloud logging read \
  'resource.type="k8s_cluster"
   protoPayload.resourceName=~"namespaces/'$NAMESPACE'/endpoints"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT \
  --order=asc \
  --format="table(timestamp,protoPayload.methodName,protoPayload.resourceName,protoPayload.response.status)" \
  --limit=50
```

`notReadyAddresses` spike + `addresses` drop = 503s explained. Find why pods went NotReady.

### 1d — GCP Load Balancer Analysis

Determines traffic-driven vs pod-driven causality.

**Step 1 — Identify LB_NAME**

```bash
gcloud compute forwarding-rules list --project=$PROJECT \
  --format="table(name,IPAddress,target,region,loadBalancingScheme)"
gcloud compute backend-services list --project=$PROJECT \
  --format="table(name,protocol,loadBalancingScheme,backends[].group)"
kubectl get ingress -n $NAMESPACE \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.loadBalancer.ingress[*].ip}{"\n"}{end}'
# Set LB_NAME = forwarding rule matching Ingress IP
# Set LB_BACKEND_NAME = backend service name

# NEG mode check
kubectl get service $SERVICE -n $NAMESPACE \
  -o jsonpath='{.metadata.annotations.cloud\.google\.com/neg}' && echo
gcloud compute network-endpoint-groups list --project=$PROJECT \
  --format="table(name,zone,size)" 2>/dev/null | grep -i $SERVICE || true

# Verify LB logging enabled (if False, skip steps 2-7)
gcloud compute backend-services describe $LB_BACKEND_NAME \
  --global --project=$PROJECT --format="value(logConfig.enable,logConfig.sampleRate)"
```

**Step 2 — Request rate (per minute)**

```bash
gcloud logging read \
  'resource.type="http_load_balancer"
   resource.labels.forwarding_rule_name="'$LB_NAME'"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT \
  --order=asc \
  --format="value(timestamp)" \
  --limit=5000 | \
  awk '{print substr($1,1,16)}' | sort | uniq -c
```

**Step 3 — 5xx breakdown**

```bash
gcloud logging read \
  'resource.type="http_load_balancer"
   resource.labels.forwarding_rule_name="'$LB_NAME'"
   httpRequest.status>=500
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT \
  --order=asc \
  --format="table(timestamp,httpRequest.status,httpRequest.latency,jsonPayload.statusDetails,httpRequest.requestUrl)" \
  --limit=1000
```

**Status codes:** 502 = pod crashed mid-request (H1/H3). 503 = no healthy backend (H1/H2/H3/H7). 504 = timeout (H4/H5/H6).

**Step 4 — Latency distribution**

```bash
gcloud logging read \
  'resource.type="http_load_balancer"
   resource.labels.forwarding_rule_name="'$LB_NAME'"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT \
  --format="value(httpRequest.latency)" \
  --limit=5000 | \
  sed 's/s$//' | awk '
    {v=$1+0}
    v<0.1  {fast++}
    v>=0.1 && v<0.5  {mid++}
    v>=0.5 && v<2.0  {slow++}
    v>=2.0 {veryslow++}
    END {print "< 100ms:", fast; print "100-500ms:", mid; print "500ms-2s:", slow; print "> 2s:", veryslow}
  '
```

Rising slow bucket before errors = saturation (H4/H5/H6). Latency flat + errors = endpoints dropped (H1/H2/H3/H7).

**Step 5 — statusDetails**

```bash
gcloud logging read \
  'resource.type="http_load_balancer"
   resource.labels.forwarding_rule_name="'$LB_NAME'"
   httpRequest.status>=500
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT \
  --format="value(jsonPayload.statusDetails)" \
  --limit=1000 | sort | uniq -c | sort -rn
```

**statusDetails mapping:**
| Value | Hypothesis |
|-------|------------|
| `backend_connection_closed_*` | H1/H3 (pod killed mid-request) |
| `failed_to_connect_to_backend` | H1/H2/H3/H7 (endpoints zero) |
| `backend_timeout` | H4/H5/H6 (overload/dep) |
| `backend_early_response` | H2/H5/H6 (app rejection) |

**Step 6 — Baseline (T-7d)**

```bash
T_BASELINE_START=$(date -u -d "$T_START - 7 days" +%Y-%m-%dT%H:%M:%SZ)
T_BASELINE_END=$(date -u -d "$T_END - 7 days" +%Y-%m-%dT%H:%M:%SZ)
gcloud logging read \
  'resource.type="http_load_balancer"
   resource.labels.forwarding_rule_name="'$LB_NAME'"
   timestamp>="'$T_BASELINE_START'"
   timestamp<="'$T_BASELINE_END'"' \
  --project=$PROJECT \
  --format="value(timestamp)" \
  --limit=5000 | \
  awk '{print substr($1,1,16)}' | sort | uniq -c
```

Spike vs baseline: >2x = traffic-driven, flat = pod-driven.

**Step 7 — Client IP distribution**

```bash
gcloud logging read \
  'resource.type="http_load_balancer"
   resource.labels.forwarding_rule_name="'$LB_NAME'"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT \
  --format="value(httpRequest.remoteIp)" \
  --limit=5000 | sort | uniq -c | sort -rn | head -20
```

Skewed = single client/DDoS (H4). Uniform = organic or pod-side.

**LB Decision Matrix:**
| Pattern | Hypothesis |
|---------|------------|
| Spike + 503s | H1/H4 (overload) |
| Spike + 504s | H4/H5/H6 (saturated) |
| No spike + 503s | H1/H2/H3/H7 (pod failure) |
| No spike + 504s | H5/H6 (dep degraded) |
| Errors before spike | Retry storm (H1/H2/H3/H5/H6/H7 primary) |
| `failed_to_connect_to_backend` | H1/H2/H3/H7 |
| `backend_timeout` | H4/H5/H6 |

### 1e — Deploy Gate (H7)

```bash
gcloud logging read \
  'resource.type="k8s_cluster"
   protoPayload.methodName=~"deployments"
   resource.labels.cluster_name="'$CLUSTER'"
   resource.labels.namespace_name="'$NAMESPACE'"
   timestamp>="'$T_START_MINUS_2H'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT \
  --order=asc \
  --format="table(timestamp,protoPayload.authenticationInfo.principalEmail,protoPayload.methodName,protoPayload.resourceName)" \
  --limit=50
```

No results = H7 ruled out. Results = check system vs manual (1f), set `DEPLOY_TIME`.

### 1f — System Changes (Score Higher Than Manual)

System changes affect multiple pods, low visibility. Score +4 vs manual +2.

```bash
# 1. Cluster autoscaler
gcloud logging read \
  'resource.type="k8s_cluster"
   log_name=~"cluster-autoscaler"
   (textPayload=~"Scale-down|ScaleDown|removing node|evicting pod"
    OR jsonPayload.message=~"Scale-down|ScaleDown|removing node")
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT \
  --order=asc \
  --format="table(timestamp,textPayload)" \
  --limit=50

# 2. Node auto-repair — GKE replacing unhealthy node
gcloud logging read \
  'resource.type="gce_instance"
   protoPayload.methodName=~"compute.instances.insert|compute.instances.delete"
   protoPayload.authenticationInfo.principalEmail=~"system:|gke-|container-engine"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT \
  --order=asc \
  --format="table(timestamp,protoPayload.methodName,protoPayload.authenticationInfo.principalEmail,protoPayload.resourceName)" \
  --limit=30

# 3. GKE automatic upgrades (control plane or node pool)
gcloud logging read \
  'resource.type="gce_instance" OR resource.type="gke_cluster"
   (protoPayload.methodName=~"UpdateCluster|SetNodePoolVersion|UpdateNodePool"
    OR textPayload=~"upgrade|Upgrading")
   timestamp>="'$T_START_MINUS_2H'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT \
  --order=asc \
  --format="table(timestamp,protoPayload.methodName,textPayload)" \
  --limit=30

# 4. Preemptible/Spot VM preemption — GCE terminates node with 30s warning
gcloud logging read \
  'resource.type="gce_instance"
   protoPayload.methodName="compute.instances.preempted"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT \
  --order=asc \
  --format="table(timestamp,resource.labels.instance_id,protoPayload.resourceName)" \
  --limit=20

# 5. Node pool resize (automatic or manual)
gcloud logging read \
  'resource.type="gke_nodepool"
   protoPayload.methodName=~"SetNodePoolSize|SetNodePoolAutoscaling"
   timestamp>="'$T_START_MINUS_2H'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT \
  --order=asc \
  --format="table(timestamp,protoPayload.authenticationInfo.principalEmail,protoPayload.methodName)" \
  --limit=20

# 6. HPA scale events — automatic scaling can cascade failures
gcloud logging read \
  'resource.type="k8s_cluster"
   log_name="projects/'$PROJECT'/logs/events"
   jsonPayload.involvedObject.kind="HorizontalPodAutoscaler"
   jsonPayload.reason=~"SuccessfulRescale|DesiredReplicasComputed"
   resource.labels.namespace_name="'$NAMESPACE'"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT \
  --order=asc \
  --format="table(timestamp,jsonPayload.involvedObject.name,jsonPayload.reason,jsonPayload.message)" \
  --limit=50

# 7. Maintenance window activity
gcloud container clusters describe $CLUSTER --region=$REGION --project=$PROJECT \
  --format="value(maintenancePolicy.window.dailyMaintenanceWindow,maintenancePolicy.window.recurringWindow)"
```

**HPA cascades:** Scale-down → overload remaining. Scale-up → thundering herd on DB. Flapping → endpoint churn.

**System vs manual:** `principalEmail` = `system:|gke-|container-engine` → SYSTEM (+4). Human/CI → MANUAL (+2).

**System signals:**
| Signal | H | Score |
|--------|---|-------|
| Autoscaler scale-down | H3 | +4 |
| Node auto-repair | H3 | +4 |
| GKE upgrade | H3/H7 | +4 |
| Spot/preemption | H3 | +4 |
| HPA scale-down | H1/H4 | +4 |
| HPA scale-up | H4/H5 | +4 |
| HPA flapping | H2/H4 | +4 |

---

**Before Phase 2:** Traffic spike? Dominant status code? statusDetails? System change? Manual deploy?

---

## Phase 2 — Hypothesis Scoring

Score all 7 from Phase 1. No dismissal without evidence.

```
EVIDENCE LEDGER
---------------
Signal                          | Timestamp | Source           | Type     | Points To
Cluster autoscaler scale-down   | T-05      | autoscaler logs  | SYSTEM   | H3 (+4)
Node gke-pool-abc123 removed    | T-03      | GCE audit log    | SYSTEM   | H3 (+4)
OOMKilling event on svc-pod-x   | T+02      | k8s events       | -        | H1 (+2)
Exit code 137 on 3 pods         | T+02      | kubectl get pods | -        | H1 (+2)
Unhealthy/Readiness on svc-pod-y| T+01      | k8s events       | -        | H2 (+1)
Endpoints dropped: 3→0          | T+03      | kubectl describe | -        | all
Manual deploy by user@company   | T+00      | audit log        | MANUAL   | H7 (+2)
```

**Key**: SYSTEM changes score +4, MANUAL changes score +2. Investigate highest-scoring hypothesis first.

### Scoring

| Points | Trigger |
|--------|---------|
| +4 | System change (autoscaler, node repair, upgrade, preemption, HPA) |
| +5 | System change → H3/H7 (investigate first) |
| +3 | Manual deploy → H7 |
| +2 | Direct signal (OOMKilling, exit 137, Evicted, FailedScheduling, pool error) |
| +1 | Indirect signal (Unhealthy, ScalingReplicaSet), statusDetails match, traffic spike before failures |

### The 7 Hypotheses

| H | Name | Smoking Gun | Required Signal |
|---|------|-------------|-----------------|
| H1 | OOMKill | `OOMKilling` + exit 137 + mem >85% | exit 137 |
| H2 | Probe failure | `Unhealthy` + (startup/liveness: high restarts; readiness: endpoint flap) | Unhealthy event |
| H3 | Node eviction | `Evicted` + node pressure condition + FailedScheduling | Evicted event |
| H4 | HPA maxed | HPA at max + high CPU/mem + 504s dominant | HPA at maxReplicas |
| H5 | Pool exhausted | `pool exhausted` in app logs + DB clean | pool error in logs |
| H6 | Dep failure | connection timeout/refused before probe fail + dep degraded | conn error in logs |
| H7 | Bad deploy | deploy event + ImagePullBackOff/CrashLoopBackOff | deploy event |

**H2 sub-variants:** Startup (never Ready, high restarts), Liveness (was Ready, high restarts), Readiness (running, endpoint flap, low restarts).

**H5 vs H6:** H5 = pool full but DB healthy. H6 = DB/dep itself degraded.

---

## Phase 3 — Deep-Dive (Highest Score First)

Stop at ≥2 independent signals confirming causal chain.

### H1 — OOMKill

```bash
# 1. OS-level OOMKill
gcloud logging read \
  'resource.type="gce_instance"
   textPayload=~"oom_kill_process|Out of memory"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT \
  --order=asc \
  --format="table(timestamp,resource.labels.instance_id,textPayload)" \
  --limit=50

# 2. Container names (needed for Monitoring filter)
kubectl get pod $POD_NAME -n $NAMESPACE \
  -o jsonpath='{range .spec.containers[*]}{.name}{"\n"}{end}'

# 3. Memory utilization — Cloud Console Metrics Explorer (MQL):
#  fetch k8s_container
#  | metric 'kubernetes.io/container/memory/limit_utilization'
#  | filter resource.cluster_name == 'CLUSTER'
#       && resource.namespace_name == 'NAMESPACE'
#       && resource.pod_name =~ 'SERVICE.*'
#  | within(30m, d'INCIDENT_TIME_UTC') | every 1m
# Values >0.85 in 5min before crash = strong H1 confirmation

# 4. Previous container logs — what was app doing before OOM
kubectl logs $POD_NAME -n $NAMESPACE --previous --timestamps=true 2>/dev/null | tail -300

# 5. Memory limits — is the limit realistic?
kubectl get pod $POD_NAME -n $NAMESPACE \
  -o jsonpath='{range .spec.containers[*]}{.name}{"\t"}{"req: "}{.resources.requests.memory}{"\t"}{"lim: "}{.resources.limits.memory}{"\n"}{end}'

# 6. VPA recommendation if installed — was limit undersized?
kubectl describe vpa -n $NAMESPACE 2>/dev/null
```

**Confirmed if**: oom_kill_process in node syslog + exit 137 + memory utilization >85% in 5min before crash
**Ruled out if**: no oom_kill_process, exit codes not 137, memory flat

---

### H2 — Probe Failure

**Step 1 — Unhealthy events**

```bash
gcloud logging read \
  'resource.type="k8s_cluster"
   log_name="projects/'$PROJECT'/logs/events"
   jsonPayload.reason="Unhealthy"
   resource.labels.namespace_name="'$NAMESPACE'"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT \
  --order=asc \
  --format="table(timestamp,jsonPayload.involvedObject.name,jsonPayload.message)" \
  --limit=200
```

**Step 2 — Probe configs**

```bash
kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o json | jq -r '
  .spec.template.spec.containers[] |
  "Container: \(.name)",
  "  startup:   \(.startupProbe // "none" | if type == "object" then tojson else . end)",
  "  liveness:  \(.livenessProbe // "none" | if type == "object" then tojson else . end)",
  "  readiness: \(.readinessProbe // "none" | if type == "object" then tojson else . end)"'
```

**Step 3 — Check restart count to distinguish sub-variant**

```bash
# Use POD_SELECTOR from 1b
kubectl get pods -n $NAMESPACE -l $POD_SELECTOR -o json | jq -r '
  .items[] | .metadata.name as $pod |
  .status.containerStatuses[]? |
  [$pod, .name, .restartCount, .lastState.terminated.exitCode // "-"] | @tsv' | \
  column -t -s $'\t' -N POD,CONTAINER,RESTARTS,EXIT
```

- Restarts HIGH + pod never reached Ready → **startup** probe killing slow-starting app
- Restarts HIGH + pod was Ready before → **liveness** (exit 0/143/137 all possible — check for `Unhealthy/Liveness` event)
- Restarts LOW or zero → **readiness** excluded pod from endpoints, pod still running

**Step 4 — Endpoint oscillation (readiness sub-variant)**

```bash
gcloud logging read \
  'resource.type="k8s_cluster"
   protoPayload.resourceName=~"namespaces/'$NAMESPACE'/endpoints/'$SERVICE'"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT \
  --order=asc \
  --format="table(timestamp,protoPayload.methodName,protoPayload.response)" \
  --limit=100
```

**Step 5 — App logs around probe failure timestamps**

```bash
gcloud logging read \
  'resource.type="k8s_container"
   resource.labels.cluster_name="'$CLUSTER'"
   resource.labels.namespace_name="'$NAMESPACE'"
   resource.labels.pod_name=~"'$SERVICE'"
   severity>=WARNING
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT \
  --order=asc \
  --format="table(timestamp,resource.labels.pod_name,jsonPayload.message,textPayload)" \
  --limit=300
```

**Red flags in probe config:**
- `timeoutSeconds: 1` with any I/O in the handler
- `failureThreshold: 1` — zero tolerance
- HTTP probe hitting an endpoint that queries DB (slow under load)
- `initialDelaySeconds` too low — app not ready when kubelet starts probing
- Startup probe: `failureThreshold × periodSeconds` < actual app startup time → kills before ready
- No startup probe on slow-starting app → liveness probe kills during startup

**Startup confirmed if**: Unhealthy/Startup events + pod never reached Ready + restarts high + tight startup probe config (low failureThreshold × periodSeconds)
**Liveness confirmed if**: Unhealthy/Liveness events + tight probe config + restarts high + (exit 0/143/137)
**Readiness confirmed if**: Unhealthy/Readiness events + endpoints oscillating + restarts flat + app logs show errors during probe window
**Ruled out if**: no Unhealthy events at all

---

### H3 — Node Eviction

```bash
# 1. Eviction events — pod name, node, pressure type
gcloud logging read \
  'resource.type="k8s_cluster"
   log_name="projects/'$PROJECT'/logs/events"
   jsonPayload.reason="Evicted"
   resource.labels.namespace_name="'$NAMESPACE'"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT \
  --order=asc \
  --format="table(timestamp,jsonPayload.involvedObject.name,jsonPayload.message)" \
  --limit=100

# 2. Node condition events — what pressure type fired and when
gcloud logging read \
  'resource.type="k8s_cluster"
   log_name="projects/'$PROJECT'/logs/events"
   jsonPayload.reason=~"NodeHas|NodeNot|Pressure"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT \
  --order=asc \
  --format="table(timestamp,jsonPayload.involvedObject.name,jsonPayload.reason,jsonPayload.message)" \
  --limit=100

# 3. FailedScheduling — evicted pods couldn't find a new node
gcloud logging read \
  'resource.type="k8s_cluster"
   log_name="projects/'$PROJECT'/logs/events"
   jsonPayload.reason="FailedScheduling"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT \
  --order=asc \
  --format="table(timestamp,jsonPayload.involvedObject.name,jsonPayload.message)" \
  --limit=50

# 4. Node system logs — substitute NODE_INSTANCE_ID from eviction event or: kubectl describe pod $POD_NAME -n $NAMESPACE | grep Node:
gcloud logging read \
  'resource.type="gce_instance"
   resource.labels.instance_id="NODE_INSTANCE_ID"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT \
  --order=asc \
  --format="table(timestamp,textPayload,jsonPayload.message)" \
  --limit=100

# 5. GCE preemption or live migration?
gcloud logging read \
  'resource.type="gce_instance"
   protoPayload.methodName=~"compute.instances.delete|preempted|migrate"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT \
  --order=asc \
  --limit=20

# 6. Current node state — conditions summary
kubectl get nodes -o wide
kubectl get nodes -o json | jq -r '
  .items[] | "\(.metadata.name): \(.status.conditions | map(select(.status=="True")) | map(.type) | join(", "))"'
```

**Confirmed if**: Evicted events + node condition (MemoryPressure/DiskPressure) fires before evictions + FailedScheduling if pods can't reschedule
**Ruled out if**: no Evicted events, nodes all Ready, pods distributed across multiple healthy nodes

---

### H4 — HPA Maxed

```bash
# 1. HPA current state — is it at maxReplicas?
kubectl get hpa -n $NAMESPACE
kubectl describe hpa -n $NAMESPACE

# 2. HPA scale events in window
gcloud logging read \
  'resource.type="k8s_cluster"
   log_name="projects/'$PROJECT'/logs/events"
   jsonPayload.involvedObject.kind="HorizontalPodAutoscaler"
   resource.labels.namespace_name="'$NAMESPACE'"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT \
  --order=asc \
  --format="table(timestamp,jsonPayload.involvedObject.name,jsonPayload.reason,jsonPayload.message)" \
  --limit=100

# 3. Cluster autoscaler — tried to add nodes and failed?
gcloud logging read \
  'resource.type="k8s_cluster"
   log_name=~"cluster-autoscaler"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT \
  --order=asc \
  --format="table(timestamp,textPayload)" \
  --limit=100

# 4. FailedScheduling — new pods pending, no node capacity
gcloud logging read \
  'resource.type="k8s_cluster"
   log_name="projects/'$PROJECT'/logs/events"
   jsonPayload.reason="FailedScheduling"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT \
  --order=asc \
  --limit=50

# 5. Pod CPU/memory utilization
kubectl top pods -n $NAMESPACE 2>/dev/null

# 6. Namespace resource quotas — can cause FailedScheduling independent of node capacity
kubectl describe resourcequota -n $NAMESPACE 2>/dev/null
# Hard limits on cpu/memory/pods hit → scheduler rejects new pods → HPA can't scale even with node headroom
```

**503 vs 504**: H4 produces 504s (connection accepted, upstream timed out) not 503s (no endpoint). Pure 503s → H4 unlikely. Mixed → H2+H4 may both be active.

**Confirmed if**: HPA at maxReplicas + CPU/memory high on pods + FailedScheduling or autoscaler blocked + 504 pattern dominant
**Ruled out if**: HPA has headroom, pod count scaled up, errors pure 503

---

### H5 — Pool Exhausted

```bash
# 1. App logs — pool exhaustion signatures
gcloud logging read \
  'resource.type="k8s_container"
   resource.labels.cluster_name="'$CLUSTER'"
   resource.labels.namespace_name="'$NAMESPACE'"
   resource.labels.pod_name=~"'$SERVICE'"
   (textPayload=~"connection pool|pool exhausted|too many connections|pool timeout|acquire.*timeout|no idle connection|max.*connections.*reached"
    OR jsonPayload.message=~"connection pool|pool exhausted|too many connections|pool timeout|acquire.*timeout|no idle connection")
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT \
  --order=asc \
  --format="table(timestamp,resource.labels.pod_name,jsonPayload.message,textPayload)" \
  --limit=300

# 2. DB server — active connection count at incident time
#    Cloud SQL: check connections metric
gcloud logging read \
  'resource.type="cloudsql_database"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT \
  --order=asc \
  --format="table(timestamp,severity,jsonPayload.message,textPayload)" \
  --limit=100

# 3. DB server — was it healthy? (no errors = pool is the problem, not the DB)
#    If DB logs are clean while app shows pool errors → H5 confirmed over H6
gcloud logging read \
  'resource.type="cloudsql_database"
   severity>=WARNING
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT \
  --order=asc \
  --limit=50

# 4. Readiness probe timing — did probe failures follow pool exhaustion messages?
#    Cross-reference pool error timestamps vs Unhealthy event timestamps
#    Pool errors must predate probe failures to be causal

# 5. App config — what is max pool size configured?
#    Check env vars on the deployment for pool-related settings
kubectl get deployment $DEPLOYMENT -n $NAMESPACE \
  -o jsonpath='{range .spec.template.spec.containers[*]}{.name}{"\n"}{range .env[*]}{.name}{" = "}{.value}{"\n"}{end}{"\n"}{end}' | \
  grep -iE "pool|conn|database|db_max|max_conn|pg_pool|hikari|c3p0|drizzle"
# Look for: DB_POOL_SIZE, DATABASE_POOL_MAX, HIKARI_MAX_POOL_SIZE, PG_POOL_MAX, etc.
# If value is not set → app uses default (often 10 for most ORMs — easy to exhaust under load)
```

**H5 vs H6 distinction — critical:**
| Signal | H5 (pool exhausted) | H6 (dep failure) |
|---|---|---|
| App log message | `pool exhausted`, `acquire timeout` | `connection refused`, `timeout`, `ECONNREFUSED` |
| DB server logs | Clean — no errors | Errors, slow queries, or unreachable |
| DB connection count | At max (pool ceiling) | May be low (DB rejecting or unreachable) |
| DB response time | Normal (DB healthy) | Elevated or no response |

**Confirmed if**: pool exhaustion log messages predate probe failures + DB server logs clean + DB connection count at configured max
**Ruled out if**: no pool exhaustion messages in app logs, DB connection count has headroom, DB logs show errors (→ H6)

---

### H6 — Dep Failure

```bash
# 1. App error logs — connection errors to downstream
gcloud logging read \
  'resource.type="k8s_container"
   resource.labels.cluster_name="'$CLUSTER'"
   resource.labels.namespace_name="'$NAMESPACE'"
   resource.labels.pod_name=~"'$SERVICE'"
   (textPayload=~"connection refused|timeout|dial tcp|ECONNREFUSED|context deadline exceeded|no such host|i/o timeout"
    OR jsonPayload.message=~"connection refused|timeout|dial tcp|ECONNREFUSED|context deadline exceeded|no such host")
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT \
  --order=asc \
  --format="table(timestamp,resource.labels.pod_name,jsonPayload.message,textPayload)" \
  --limit=300

# 2. Other pods in namespace — also restarting or unhealthy? (may indicate shared dep failure)
kubectl get pods -n $NAMESPACE -o json | jq -r '
  .items[] | select(.metadata.name | test("'$SERVICE'") | not) |
  [.metadata.name,
   ([.status.containerStatuses[]?.restartCount] | add // 0),
   ([.status.containerStatuses[]?.ready] | all)] | @tsv' | \
  column -t -s $'\t' -N POD,RESTARTS,READY | head -20

# 3. Cloud SQL / Memorystore / Pub-Sub errors
gcloud logging read \
  'resource.type="cloudsql_database"
   severity>=WARNING
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT \
  --order=asc \
  --limit=50

# 4. DNS resolution failures
gcloud logging read \
  'resource.type="k8s_container"
   resource.labels.cluster_name="'$CLUSTER'"
   (textPayload=~"no such host|dns|lookup failed"
    OR jsonPayload.message=~"no such host|dns|lookup failed")
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT \
  --order=asc \
  --limit=50
```

**Causal direction check**: dependency error logs must predate readiness probe failures. If probe failures came first → H6 is downstream, not root cause.

**Confirmed if**: connection error/timeout logs to dependency predate probe failures + other pods in namespace also degraded, or DB/external service logs show errors
**Ruled out if**: app logs show no connection errors, other pods in namespace healthy, DB logs clean (if DB clean but pool errors exist → H5)

---

### H7 — Bad Deploy

**Gate already run in Phase 1e.** No deploy found → stop here. Deploy found → set `DEPLOY_TIME` and continue:

```bash
# New pod status — stuck in bad state? (use POD_SELECTOR from 1b)
kubectl get pods -n $NAMESPACE -l $POD_SELECTOR -o json | jq -r '
  .items | sort_by(.metadata.creationTimestamp) | .[] |
  [.metadata.name, .metadata.creationTimestamp,
   (.status.phase),
   (.status.containerStatuses[]?.state | keys[0] // "-"),
   (.status.containerStatuses[]?.state.waiting.reason // "-")] | @tsv' | \
  column -t -s $'\t' -N POD,CREATED,PHASE,STATE,REASON

# Image pull, config, or mount errors on new pods
gcloud logging read \
  'resource.type="k8s_cluster"
   log_name="projects/'$PROJECT'/logs/events"
   jsonPayload.reason=("Failed" OR "BackOff" OR "FailedMount" OR "FailedAttachVolume" OR "CreateContainerConfigError")
   resource.labels.namespace_name="'$NAMESPACE'"
   timestamp>="'$T_START'"
   timestamp<="'$T_END'"' \
  --project=$PROJECT \
  --order=asc \
  --format="table(timestamp,jsonPayload.involvedObject.name,jsonPayload.reason,jsonPayload.message)" \
  --limit=100

# Check for missing secrets/configmaps referenced by new deployment
kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o json | jq -r '
  .spec.template.spec |
  (.containers[].env[]?.valueFrom.secretKeyRef.name // empty),
  (.containers[].env[]?.valueFrom.configMapKeyRef.name // empty),
  (.volumes[]?.secret.secretName // empty),
  (.volumes[]?.configMap.name // empty)' | sort -u | while read ref; do
    [ -z "$ref" ] && continue
    kubectl get secret "$ref" -n $NAMESPACE 2>/dev/null || kubectl get configmap "$ref" -n $NAMESPACE 2>/dev/null || echo "MISSING: $ref"
done

# Rollout history — what image/config changed?
kubectl rollout history deployment/$DEPLOYMENT -n $NAMESPACE
```

**Confirmed if**: deploy timestamp precedes first error + new pods in ImagePullBackOff/CrashLoopBackOff/CreateContainerConfigError/Pending + endpoint count dropped as old pods terminated
**Ruled out if**: no deploy changes in [T-2h, T_END] — stop after gate query

**Common H7 sub-causes**:
- `ImagePullBackOff` → wrong image tag, registry auth failed, image doesn't exist
- `CreateContainerConfigError` → missing secret/configmap key, invalid env var reference
- `FailedMount` → PVC not bound, secret/configmap doesn't exist
- `CrashLoopBackOff` → app crashes on startup (bad config, missing dep, code bug)

---

## Phase 4 — Cross-Correlation (6 Checks)

Complete all before RCA.

| # | Check | Rule |
|---|-------|------|
| 1 | Timestamp order | Root cause < all downstream. Out-of-order = invalid |
| 2 | Two signals | H1: oom_kill + exit 137. H2: Unhealthy + endpoint flap. H5: pool error + DB conn max. H6: dep error + dep degraded |
| 3 | Parsimony | One H explains all signals? Don't force-fit a second |
| 4 | Required signal | H1: 137. H2: Unhealthy. H3: Evicted. H4: HPA max. H5: pool msg. H6: conn error. H7: deploy event |
| 5 | User match | Data ≠ reported time? Real incident started earlier |
| 6 | Traffic direction | A) spike < k8s event → traffic caused (H4/H1). B) k8s event < spike → retry storm. C) flat → pod-only |

---

## Phase 5 — RCA Report

```
## GKE Incident Report

Cluster:     <name> / <region>
Namespace:   <namespace>
Services:    <service names>
Window:      <T_START UTC> → <T_END UTC>
MTTD:        <duration from first symptom to first alert/detection>
MTTM:        <duration from first alert to service fully restored>

---

### Root Cause
<One precise sentence. What failed, why, when.>

---

### Causal Chain
| Time (UTC) | Event                              | Source              |
|------------|------------------------------------|---------------------|
| T-05       | Memory utilization crosses 85%     | Cloud Monitoring    |
| T+00       | First OOMKilling event             | k8s events          |
| T+01       | Pod exits with code 137            | kubectl get pods    |
| T+02       | oom_kill_process in node syslog    | Cloud Logging / GCE |
| T+02       | Endpoint addresses: 3 → 0          | kubectl describe    |
| T+02       | 503s begin                         | Cloud Logging       |
| T+10       | Pod restarts, readiness passes     | k8s events          |
| T+10       | Endpoints recover: 0 → 3           | kubectl describe    |

---

### Evidence Ledger
| Signal                          | Value         | Source              | Timestamp |
|---------------------------------|---------------|---------------------|-----------|
| Exit code on pod                | 137 (OOMKill) | kubectl get pods    | T+01      |
| oom_kill_process in node syslog | confirmed     | Cloud Logging / GCE | T+02      |
| memory/limit_utilization        | 0.97          | Cloud Monitoring    | T-02      |
| Endpoint addresses              | dropped 3→0   | kubectl describe    | T+02      |
| OOMKilling k8s event            | confirmed     | k8s events log      | T+00      |

---

### Traffic Analysis (GCP Load Balancer)
| Metric                  | Incident Window       | Baseline (T-7d)       |
|-------------------------|-----------------------|-----------------------|
| Request rate (req/min)  | <n>                   | <n>                   |
| Error rate (5xx %)      | <n>%                  | <n>%                  |
| Dominant status code    | 503 / 504 / 502       | —                     |
| Dominant statusDetails  | <value>               | —                     |
| Traffic spike?          | Yes / No (Δ <n>x)     | —                     |
| Spike vs pod failure    | Spike before / after  | —                     |
| Causality direction     | A / B / C (see above) | —                     |

---

### Hypotheses Evaluated
| # | Hypothesis                              | Verdict     | Key Evidence                              |
|---|-----------------------------------------|-------------|-------------------------------------------|
| H1 | OOMKill → restart cascade              | CONFIRMED   | exit 137 + oom_kill_process + mem spike   |
| H2 | Probe failure (liveness/readiness)     | RULED OUT   | no Unhealthy events                       |
| H3 | Node pressure → eviction               | RULED OUT   | no Evicted events, nodes all Ready        |
| H4 | HPA maxed out                          | RULED OUT   | HPA had headroom, scaled successfully     |
| H5 | DB connection pool exhausted           | RULED OUT   | no pool exhaustion messages in app logs   |
| H6 | Upstream dependency failure            | RULED OUT   | no connection errors in app logs          |
| H7 | Bad deploy → pods never Ready          | RULED OUT   | no deploy changes in -2h window           |

---

### Contributing Factors
- <e.g. memory limit set without profiling peak load — no headroom>
- <e.g. single replica — no redundancy during restart window>
- <e.g. no PodDisruptionBudget>
- <e.g. readiness initialDelaySeconds too low — long recovery window>

### Blind Spots
- <data unavailable or ambiguous>
- <log gaps>
- <hypotheses not fully falsifiable due to missing data>
```

---

## Safety Rules

**Allowed:** `kubectl get/describe/logs/top/rollout history`, `gcloud logging read`, `gcloud monitoring metrics list`, `gcloud compute/container describe`, `gcloud auth list`, `gcloud config get-value`

**Never:** `kubectl apply/delete/edit/patch/exec/cp/port-forward`, `gcloud create/delete/update/set/patch`. Redact secrets.

---

## Common Pitfalls

| Area | Pitfall | Fix |
|------|---------|-----|
| Logs | K8s events expire ~1h in etcd | Query Cloud Logging, not `kubectl get events` |
| Logs | Cloud Logging 30-60s lag | Extend window ±5min |
| Logs | textPayload vs jsonPayload | Query both in filter |
| Logs | `--previous` shows last crash only | Cloud Logging for full history |
| Logs | `gcloud logging read` limit=1000 | Set `--limit` explicitly (≤50000) |
| Pod | Multi-container: which crashed? | Specify `--container` |
| Pod | Restarts=0 ≠ healthy | H2 readiness: running but excluded |
| Pod | Startup vs liveness event | Message says "Startup probe failed" |
| Codes | 503 vs 504 | 503 = no endpoint (H1/H2/H3/H7). 504 = timeout (H4/H5/H6) |
| Codes | 502 timing | `backend_connection_closed` = died mid-request. `failed_to_connect` = already dead |
| Time | GCP timestamps UTC | Convert user timezone first |
| Time | H6 causal direction | Dep errors must predate probe failures |
| Time | Retry storm looks like spike | Compare LB spike vs k8s event timestamp |
| LB | Log sampling at high RPS | Verify `logConfig.sampleRate` |
| LB | statusDetails fastest signal | Aggregate with `uniq -c` first |
| LB | Multiple forwarding rules | Check internal + external LBs |
| LB | NEG health check lag | LB checks differ from k8s readiness |
| kubectl | `top` is current only | Cloud Monitoring MQL for history |
| kubectl | Label selector mismatch | Verify `matchLabels` first |
| Node | Instance ID not in event | `kubectl describe pod` → node → GCE ID |
| Node | System changes invisible | Run 1f queries always |
| Node | Spot/preempt 30s warning | `terminationGracePeriodSeconds > 30` → SIGKILL |
| HPA | Scale-down cascade | Fewer pods → overload → more die |
| HPA | Scale-up thundering herd | All pods connect DB at once → H5 |
