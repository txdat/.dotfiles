---
name: gke-service-incident
description: "Use this skill to investigate GKE service incidents: pod restart cascades, 503/504 errors, service unavailability, CrashLoopBackOff, pods stuck Pending/unschedulable, node autoscaling failures, cloud-provider capacity stockouts, network/VPC problems, and billing/project-suspension events that reclaim nodes. Triggers: 'pods keep restarting', '503/504 errors', 'service is down', 'crash loop', 'pods stuck pending', 'nodes not scaling', 'all nodes disappeared', 'whole node pool gone', 'BILLING_DISABLED', 'REPAIR_CLUSTER', 'ZONE_RESOURCE_POOL_EXHAUSTED', 'VPC/network/firewall issue', 'what caused the incident at <time>'. Inputs (8): GCP project, cluster, region, namespace, affected services, incident start time, duration, timezone — each defaults automatically (project/cluster/region/namespace/services from $GCP_PROJECT_ID/$GKE_CLUSTER/$GKE_REGION/$GKE_NAMESPACE/$GKE_SERVICES; start time & duration default to now; timezone to UTC+7), so it can run with no input when those env vars are set. All cluster queries are read-only — only `gcloud container clusters get-credentials` mutates local kubeconfig and requires confirmation. Never mutate cluster state."
---

# GKE Incident Investigator

**Method**: Observe → Hypothesize → Falsify → Confirm. Data drives queries. ≥2 independent signals to confirm. Missing expected signal = evidence against.

---

## Pre-Flight — Collect Inputs

Resolve each input from the user's message. **If an input is absent, apply its default below** — do not ask for anything that has a default. Every input has a default, so normally you can proceed straight to Phase 0. Only stop and ask (in **one** consolidated message) if a value is still empty *after* defaults — i.e., the backing env var is unset. Always state which defaults you applied.

| # | Variable | Meaning | Default when not provided |
|---|----------|---------|---------------------------|
| 1 | `PROJECT` | GCP Project ID | `$GCP_PROJECT_ID` |
| 2 | `CLUSTER` | Cluster name | `$GKE_CLUSTER` |
| 3 | `REGION` | Region (or zone for zonal clusters) | `$GKE_REGION` |
| 4 | `NAMESPACE` | Namespace | `$GKE_NAMESPACE` |
| 5 | `SERVICES` | Affected services, comma-separated. A trailing `*` = prefix match (all services sharing that prefix). Serves as both Service and Deployment set. | `$GKE_SERVICES` |
| 6 | `T_USER` | Incident start time, as precise as possible | **now** (anchor the window on the current time) |
| 7 | `T_DURATION` | How long the issue lasted (widens window if >30m) | **now** (incident ongoing → window ends at the present) |
| 8 | `T_TZ` | Timezone | `Asia/Ho_Chi_Minh` (UTC+7) |

All input resolution, SERVICES/SVC_RE expansion, and window-tier derivation below is performed
internally by `scripts/gke-collect.sh` — export the env vars and run it once (see "Phase 1 — Broad
Sweep" below). It prints the resolved values (`PROJECT`, `CLUSTER`, ..., `T_START`, `T_END`,
`T_START_MINUS_2H`, `T_START_CRITICAL`, thresholds) under `===== Pre-Flight — Resolved Inputs =====`
so you can sanity-check them before interpreting the rest of the output.

```bash
export GCP_PROJECT_ID=... GKE_CLUSTER=... GKE_REGION=... GKE_NAMESPACE=... GKE_SERVICES=...
# optional: T_USER, T_DURATION, T_TZ, T_CRITICAL_LOOKBACK, NODE_DELETE_BURST, NOTREADY_MAX, AGE_RESET_FRAC
```

**Query-window tiers:** queries deliberately use different lookbacks by hypothesis class — a symptom is point-in-time, but a slow root cause can predate it by hours:

| Tier | Variable | Span | Used by |
|------|----------|------|---------|
| Symptom | `T_START` | **T−30m → T_END** | H1, H2, H3, H4, H5, H6, H9, H10, H11, H14, H15, H16 + events/endpoints/LB |
| Change lookback | `T_START_MINUS_2H` | **T−2h → T_END** | H7 (deploy), H12 (network), GKE upgrade / node-pool resize |
| Critical root-cause | `T_START_CRITICAL` | **T−6h → T_END** (`$T_CRITICAL_LOOKBACK`) | **B1** (billing disable→reclaim propagation), **H13** (long-running repair/upgrade ops), **H8** (credential change → token-expiry delay) |
| Baseline | `T_BASELINE_*` | **T−7d (±window)** | LB traffic baseline only |

**Multi-service note:** app-log queries filter on `pod_name=~"'$SVC_RE'"` (the regex expanded from `SERVICES` in Pre-Flight), so they cover every affected service at once. Endpoint, NEG, and single-target `kubectl` commands use the primary `$SERVICE`/`$DEPLOYMENT` — repeat them per service when `SERVICES` lists more than one. If an exact (non-wildcard) service name is itself a prefix of a sibling (e.g. `api` vs `api-order`), verify ownership via the label selector in 1b rather than the pod-name regex.

---

## Phase 0 — Auth Validation (Blocking)

`gcloud container clusters get-credentials` mutates local kubeconfig only. Ask for confirmation before running it unless the current context already targets the requested cluster.

`scripts/gke-collect.sh` runs the read-only auth checks (`gcloud auth list`, `gcloud config
get-value project`, `kubectl config current-context`, `kubectl cluster-info`) under
`===== Phase 0 — Auth Validation =====` on every invocation. It does **not** run
`get-credentials` unless invoked with `--get-credentials` — pass that flag only after confirming
with the user, or run `gcloud container clusters get-credentials $CLUSTER --region $REGION
--project $PROJECT` manually.

---

## Phase 1 — Broad Sweep (Run All)

Run the collector once — it covers every query in 1a-1i below (and the auto-discoverable Phase 3
deep-dive queries) in a single read-only pass:

```bash
bash skills/gke/scripts/gke-collect.sh          # read-only; add --get-credentials only after confirming with the user
```

The collector writes **all** evidence to a report file and prints only its path to the terminal
(e.g. `gke-collect: report complete → /tmp/gke-incident-<cluster>-<ts>.txt`; override with
`$REPORT`). **Read that report file**, then interpret its `===== ... =====` sections against the
tables and prose below — no further commands are needed for 1a-1i or for the Phase 3 sections that
reference this same run.

**Fast per-hypothesis retrieval.** Every section header is tagged with the hypotheses it feeds,
e.g. `===== 1f.2 — Node Auto-repair / MIG Recreation =====  {HYP: H13 H14}`. To pull *only* one
hypothesis's evidence without re-reading the whole file, slice by its tag:

```bash
awk -v h=H14 '/^===== /{f=($0 ~ ("[{ ]" h "[ }]"))} f' "$REPORT"   # all H14 blocks, bodies included
grep -nE '\{HYP:[^}]*[{ ]H14[ }]' "$REPORT"                        # just the start line of each
```

Read the whole file once for the overall picture; use the tag slice when drilling into a single
hypothesis. The tag matcher is word-safe (`H1` never matches `H14`).

**Verdicts & confidence — avoiding false negatives and false positives.** Each detector emits a
one-line `[VERDICT: …]` (grep `-F '[VERDICT:'` for all of them at once). There are **five** states,
and the distinction is the whole point:

| State | Meaning | How to treat it |
|-------|---------|-----------------|
| `FIRES-CRITICAL` / `FIRES-WARNING` | The condition held on readable data | A **candidate signal**, not a conclusion — still needs corroboration (see below) |
| `CLEAR` | Source was readable **and** the condition did not hold | A real negative — safe to rule out |
| `UNKNOWN` | The data source was **unreadable** (auth/IAM/kubectl-context/log gap) | **Never treat as CLEAR.** The detector could not run; the hypothesis stays open |
| `INFO` | The condition held but a **planned op / recovered state** explains it | Benign unless it correlates with symptom onset — do not report as the cause by itself |

- **`Phase 0b — Capability Preflight`** reports which sources are readable (`CAP_LOGGING`, `CAP_K8S`, `CAP_OPS`, `CAP_COMPUTE`, `CAP_BILLING`). If a capability is 0, every detector that depends on it is `UNKNOWN` — an empty query under a missing permission is **not** an all-clear. Fix the capability (grant `roles/logging.viewer`, run `--get-credentials`, etc.) and re-run before concluding "nothing found."
- **False positives** are caught by the `INFO` downgrade: H13 checks the maintenance window, H14/H15 check for an overlapping planned `SET_NODE_POOL_SIZE`/`UPGRADE`/`REPAIR_CLUSTER` op, B1 checks whether billing is currently enabled. A fire with a matching guard is `INFO`, not a WARNING/CRITICAL.
- **The RCA gate is unchanged and final:** a `FIRES-*` becomes a *cause* only with **≥2 independent signals that correlate in time with symptom onset** (see the evidence-scoring rules). A single auto-fire, a near-threshold miss, or a live-snapshot reading is never a conclusion on its own.

### 1a — K8s Warning Events

See `===== 1a — K8s Warning Events (namespaced) =====` and `===== 1a — K8s Warning Events
(node-scoped) =====` in the script output.

**Event → Hypothesis mapping:**
| Reason | H |
|--------|---|
| `OOMKilling` | H1 |
| `Unhealthy`, `Killing` | H2 |
| `BackOff`, `CrashLoopBackOff` | H1/H7 |
| `Evicted`, `NodeNotReady` | H3 |
| `FailedScheduling` | H3/H4 — check ResourceQuota (H4) and cloud capacity stockout (H11) |
| `ScalingReplicaSet` | H4/H7 |
| `FailedMount`, `FailedAttachVolume`, `CreateContainerConfigError` | H7 |
| `FailedCreatePodSandBox`, `NetworkNotReady`, `FailedCreatePodContainer` | H12 (CNI/network) |

### 1b — Pod Restart Fingerprint

See `===== 1b — Pod Restart Fingerprint =====` in the script output (also prints the resolved
`POD_SELECTOR` under `===== Auto-discovery =====`).

**Exit codes:**
| Code | Signal | Hypothesis |
|------|--------|------------|
| `137` | SIGKILL | H1 (OOM) or H2 liveness (ignored SIGTERM) |
| `143` | SIGTERM caught | H3/H7 eviction, H2 liveness |
| `0` | Clean exit | H2 liveness (check Unhealthy event) |
| `1`/`2` | App error | H2/H5/H6/H8 |
| `139` | SIGSEGV | H7 (code bug) |

Liveness kill: SIGTERM → grace period → SIGKILL. Exit 0/143 = responded. Exit 137 = force-killed. Confirm via `Unhealthy/Liveness` event.

### 1c — Endpoint Availability

See `===== 1c — Endpoint Availability =====` in the script output.

`notReadyAddresses` spike + `addresses` drop = 503s explained. Find why pods went NotReady.

### 1d — GCP Load Balancer Analysis

Determines traffic-driven vs pod-driven causality.

**Step 1 — Identify LB_NAME**

See `===== 1d.1 — LB Identification =====` in the script output (auto-discovers `LB_NAME` /
`LB_BACKEND_NAME` from the Ingress IP where possible; check `logConfig.enable` — if `False`,
steps 2-7 are skipped by the script and must be run manually once logging is enabled).

**Step 2 — Request rate (per minute)**

See `===== 1d.2 — LB Request Rate (per minute) =====` in the script output.

**Step 3 — 5xx breakdown**

See `===== 1d.3 — LB 5xx Breakdown =====` in the script output.

**Status codes:** 502 = pod crashed mid-request (H1/H3). 503 = no healthy/reachable backend (H1/H2/H3/H7/H8/H9/H11/H12/B1+H15). 504 = timeout (H4/H5/H6/H10).

**Step 4 — Latency distribution**

See `===== 1d.4 — LB Latency Distribution =====` in the script output.

Rising slow bucket before errors = saturation (H4/H5/H6). Latency flat + errors = endpoints dropped (H1/H2/H3/H7).

**Step 5 — statusDetails**

See `===== 1d.5 — LB statusDetails =====` in the script output.

**statusDetails mapping:**
| Value | Hypothesis |
|-------|------------|
| `backend_connection_closed_*` | H1/H3 (pod killed mid-request) |
| `failed_to_connect_to_backend` | H1/H2/H3/H7/H8/H9/H11/H12/B1+H15 (no reachable backend) |
| `backend_timeout` | H4/H5/H6 (overload/dep) |
| `backend_early_response` | H2/H5/H6 (app rejection) |
| `handled_by_identity_aware_proxy` or `forbidden` | H8 (IAM/auth rejection) |

**Step 6 — Baseline (T-7d)**

See `===== 1d.6 — LB Baseline (T-7d) =====` in the script output.

Spike vs baseline: >2x = traffic-driven, flat = pod-driven.

**Step 7 — Client IP distribution**

See `===== 1d.7 — LB Client IP Distribution =====` in the script output.

Skewed = single client/DDoS (H4). Uniform = organic or pod-side.

**LB Decision Matrix:**
| Pattern | Hypothesis |
|---------|------------|
| Spike + 503s | H1/H4/H11 (overload — scale blocked by HPA/quota or capacity stockout) |
| Spike + 504s | H4/H5/H6/H10 (saturated or throttled) |
| No spike + 503s | H1/H2/H3/H7/H8/H9/H11/H12/B1+H15 (backend unavailable — pod, capacity, network, or billing/reclamation) |
| No spike + 504s | H5/H6/H10 (dep degraded or CPU throttle) |
| Errors before spike | Retry storm (primary is one of H1/H2/H3/H5/H6/H7/H8/H9/H10) |
| `failed_to_connect_to_backend` | H1/H2/H3/H7/H8/H9/H11/H12/B1+H15 |
| `backend_timeout` | H4/H5/H6/H10 |
| `forbidden` / `handled_by_identity_aware_proxy` | H8 |
| Mixed 503/504 across **multiple services** | H9 (DNS) / H12 (network infra) |
| LB backends UNHEALTHY but pods pass k8s readiness | H12 (health-check firewall/route) |

### 1e — Deploy Gate (H7)

See `===== 1e — Deploy Gate (H7) =====` in the script output.

No results = H7 ruled out. Results = check system vs manual (1f), set `DEPLOY_TIME` to earliest matching event.

### 1f — System Changes

System changes affect multiple pods with low visibility — they score higher than manual changes (+4 vs +2) and should be investigated first when present.

Each numbered sub-query below maps to a script section, in order: `===== 1f.1 — Cluster
Autoscaler =====`, `===== 1f.2 — Node Auto-repair / MIG Recreation =====`, `===== 1f.3 — GKE
Automatic Upgrades =====`, `===== 1f.4 — Preemptible/Spot VM Preemption =====`, `===== 1f.5 — Node
Pool Resize =====`, `===== 1f.6 — HPA Scale Events =====`, `===== 1f.7 — Maintenance Window =====`,
`===== 1f.8 — IAM / Workload Identity Policy Changes (critical window T-6h) =====`.

Note on 1f.2: the MIG deletes/recreates VMs as `<projnum>@cloudservices.gserviceaccount.com`
(user-agent "GCE Managed Instance Group for GKE") — that principal is NOT `system:|gke-|
container-engine`, so the script matches it explicitly or these deletes would be invisible. A
burst of such deletes = the MIG recreating the fleet (often driven by a REPAIR_CLUSTER — see 1i).

Note on 1f.8: uses the T−6h critical lookback — a key/policy change often only bites later, when
cached tokens expire.

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
| IAM policy change (gcloud audit) | H8 | +4 |
| CoreDNS config/deployment change | H9 | +4 |
| VPC / firewall / route / NAT / peering change | H12 | +4 |

> H11's stockout (`ZONE_RESOURCE_POOL_EXHAUSTED`) is a **direct signal (+2)**, not a system change — it's a failure symptom, not an action taken. Score it from the 1g sweep, not here. (H12's VPC/NAT *change* is a real action → +4; H12's NAT/IP *exhaustion* is a separate +2 direct signal — the two stack.)

---

### 1g — Node Provisioning & Capacity (H11, H16)

Run when pods are stuck `Pending`, the autoscaler keeps trying to scale up, or a scale-up "decides" but no node ever appears. Distinguishes a Kubernetes-level block (H4) from a cloud-provider capacity stockout (H11 — nodes *can't* be created) and from mere scale-up latency (H16 — nodes *can* be created but haven't arrived within `$PENDING_GRACE_MIN`m).

Five sub-queries, in order: `===== 1g.1 — Autoscaler Scale-up Decisions/Blockers (H11) =====`
(look for `jsonPayload.decision.scaleUp` / `noScaleUp`/`noDecisionStatus`; a growing gap between
`status.autoscaledNodesTarget` and `.autoscaledNodesCount` = decisions never materialized),
`===== 1g.2 — GCE VM Create Failures (stockout smoking gun, H11) =====` (`ZONE_RESOURCE_POOL_EXHAUSTED`/`RESOURCE_POOL_EXHAUSTED`
= cloud stockout → H11; `QUOTA_EXCEEDED` = H4-quota, not H11 — check 1g.4; `IP_SPACE_EXHAUSTED` =
H12, not capacity), `===== 1g.3 — GKE Create/Delete Churn (H11) =====` (repeated create→delete of
the same instance name ~10s apart = provisioning kept failing), `===== 1g.4 — Quota Headroom Check
(rules out H4-quota) =====` (usage << limit → quota is not the constraint), `===== 1g.5 — Node
Pool Topology =====` (a single-zone `locations` list = a zone stockout fully blocks scale-up —
contributing factor).

**H11 vs H4 (quota):** H11 = GCE returns `ZONE_RESOURCE_POOL_EXHAUSTED` / `RESOURCE_POOL_EXHAUSTED` — physical capacity stockout in the zone, quota has headroom. H4 (quota) = `QUOTA_EXCEEDED` — you hit a project/regional quota ceiling. H4 (HPA) = block is at the Kubernetes layer (maxReplicas or ResourceQuota), no VM create attempt fails.

### 1h — Network Infrastructure (H12)

Run when connectivity is broadly broken (multiple services, cross-node, or LB→backend) while pods themselves look healthy, or when a VPC/firewall/route/NAT change lands in the window.

Five sub-queries, in order: `===== 1h.1 — VPC/Firewall/Route/NAT Changes (H12, T-2h) =====`,
`===== 1h.2 — Cloud NAT Exhaustion (H12) =====` (breaks outbound: dep + DNS + GCP APIs), `=====
1h.3 — CNI / Pod-Sandbox Failures (H12) =====`, `===== 1h.4 — Subnet/Pod-IP Exhaustion (H12)
=====` (no free IPs to place new pods/nodes), `===== 1h.5 — LB Backend Health, Network Side (H12)
=====` (healthy pods but LB sees them DOWN = firewall/route; GKE health-check firewall ranges are
35.191.0.0/16 and 130.211.0.0/22 — a firewall change blocking these flips backends UNHEALTHY
while pods pass k8s readiness).

**H12 vs H6 / H9:** H12 = infrastructure layer (VPC/firewall/route/NAT/subnet) — broad blast radius, often spans multiple services and outbound + inbound, correlates with a network change or NAT/IP exhaustion, and pods/CoreDNS themselves are healthy. H6 = one specific downstream dependency is degraded. H9 = DNS resolution specifically (a common *symptom* of H12 when NAT/upstream breaks — if CoreDNS is healthy but resolution still fails cluster-wide, suspect H12 upstream/NAT over H9).

---

### 1i — Billing & Node-Reclamation Family (B1 / H13 / H14 / H15)

Run when **whole node pools or all nodes disappear**, node count drops far below the pool's
`minNodeCount`, nodes are all suspiciously young (fleet recreated), or a billing/lifecycle event
lands in the window. A disabled billing account makes GCP **suspend/reclaim compute** — nodes
vanish from the cluster (they do NOT show `NotReady`; they are simply gone) — and when billing is
restored GKE fires a `REPAIR_CLUSTER` that recreates the fleet. `REPAIR_CLUSTER` is **not in Cloud
Logging** — only the container operations API shows it.

This family splits into **four independently-reported rules**. Each fires only on an **in-window**
match (`$T_START..$T_END`) and carries its own severity:

| Rule | Severity | Fires when |
|------|----------|-----------|
| **B1**  | 🔴 CRITICAL | any billing-disabled log entry (`BILLING_DISABLED` / "requires billing to be enabled") matches in-window |
| **H13** | 🟡 WARNING  | an in-window `REPAIR_CLUSTER` **or** `UPGRADE_*` container operation is present |
| **H14** | 🟡 WARNING  | in-window GKE node VM deletions reach the configured burst (`$NODE_DELETE_BURST`) |
| **H15** | 🔴/🟡 (per condition) | node **count loss** below `minNodeCount`, **excessive NotReady** nodes, or **mass creation-age reset** — subject to the guards below |

Thresholds (override via env before running the collector): `NODE_DELETE_BURST` (default `3`,
H14), `NOTREADY_MAX` (default `2`, H15), `AGE_RESET_FRAC` (default `0.5`, H15). The script prints
the resolved values under `===== Pre-Flight — Resolved Inputs =====`.

**B1 — Billing disabled (CRITICAL).** Field-scoped `textPayload` (a global `"BILLING_DISABLED"`
search misses it; the string is embedded in a JSON stderr line). The real in-incident payload
reads like this — note it contains the human string, **not** the token `BILLING_DISABLED`, so the
`"requires billing to be enabled"` clause is what actually matches:

> `This API method requires billing to be enabled. Please enable billing on project #<PROJECT_NUMBER> by visiting https://console.developers.google.com/billing/enable?project=<PROJECT_NUMBER> then retry. If you enabled billing for this project recently, wait a few minutes for the action to propagate to our systems and retry.`

See `===== 1i — B1 Billing Disabled Scan (critical window T-6h) =====` in the script output. ≥1
hit in the critical window (T−6h) ⇒ B1 FIRES (CRITICAL): billing was disabled → compute reclaimed.
The disable event often predates the node loss by minutes-to-hours (propagation), so this scan
uses the longer `$T_START_CRITICAL` lookback rather than the T−30m symptom window. The same section
also confirms current billing state and who changed it (billing account disable/re-assign).

**H13 — Repair/upgrade operation (WARNING).** `REPAIR_CLUSTER`/`UPGRADE_*` live in the operations
API only, never in Cloud Logging.

See `===== 1i — H13 Repair/Upgrade Op Scan (critical window T-6h) =====` in the script output.
Uses the T−6h lookback: repair/upgrade ops are long-running and often *start* before the 30m
symptom window. `operationType` exposes *what* ran, never *why* — correlate `startTime` with B1
(billing re-enable) and H14 (delete burst) to establish the fleet-rebuild chain.

**H14 — Node VM delete burst (WARNING).** Guard: only the MIG's own deletes count (principal =
`cloudservices` SA, UA "GCE Managed Instance Group for GKE") — human/CI deletes are ordinary
maintenance, not a reclamation burst.

See `===== 1i — H14 Node VM Delete Burst =====` in the script output — it counts in-window MIG
deletes and reports whether the `$NODE_DELETE_BURST` threshold is reached.

**H15 — Node count loss / NotReady / creation-age reset (severity per condition, guarded).**

See `===== 1i — H15 Node Count Loss / NotReady / Age Reset =====` in the script output (prints
`nodes`, `notReady`, `young` counts plus per-pool `minNodeCount` and evaluates both thresholds).

**H15 fires** on any of these — each with its own severity and guard:
- **count loss** — live `NODES` < summed pool `minNodeCount` (nodes *gone*, not NotReady) ⇒ 🔴 CRITICAL.
  *Guard:* clear if a planned `SetNodePoolSize`/scale-down (1f #5) or node drain explains the drop.
- **excessive NotReady** — `NOTREADY ≥ $NOTREADY_MAX` ⇒ 🟡 WARNING.
  *Guard:* a single flapping node (`< $NOTREADY_MAX`) is noise; NotReady nodes are *present*, which
  is H3 territory — distinct from B1/reclamation where nodes vanish entirely.
- **mass creation-age reset** — `YOUNG / NODES ≥ $AGE_RESET_FRAC` (fleet recreated) ⇒ 🟡 WARNING.
  *Guard:* require the majority fraction; a couple of young nodes from routine autoscaling do not count.

**Family vs H3 vs H11:** the B1/H13/H14/H15 family = nodes **gone** (H15 count below minimum /
vanished), `BILLING_DISABLED` (B1), `REPAIR_CLUSTER`/`UPGRADE_*` in the operations API (H13), MIG
delete burst by `cloudservices` SA (H14). H3 = nodes present but `Evicted`/`NotReady` under
pressure. H11 = nodes stuck `Pending` because new VMs can't be created (`ZONE_RESOURCE_POOL_EXHAUSTED`).
Single-zone pools make H15 count-loss look total — one zone's reclamation removes the whole pool.

---

**Before Phase 2:** Traffic spike? Dominant status code? statusDetails? System change? Manual deploy? Multi-service errors (→ H9/H12)? GCP auth errors (→ H8)? CPU throttling symptoms (→ H10)? Pods stuck Pending — stockout (→ H11) vs scale-up latency past grace (→ H16)? VPC/firewall/NAT change or broad connectivity loss (→ H12)? **`BILLING_DISABLED` (→ B1), in-window `REPAIR_CLUSTER`/`UPGRADE_*` op (→ H13), MIG node-delete burst (→ H14), or node count below pool minimum / mass creation-age reset (→ H15)?**

---

## Phase 2 — Hypothesis Scoring

Score every hypothesis from Phase 1 (H1–H12 and H16, plus the B1/H13/H14/H15 billing/reclamation family). No dismissal without evidence — record signals for every H present. Treat each script `[VERDICT: FIRES-*]` as a **candidate signal**, not a verdict on the incident: it still needs a second independent, time-correlated signal to confirm. A `[VERDICT: UNKNOWN]` means the detector could not run — the hypothesis stays **open** (do not score it 0), and you should note the missing capability rather than rule it out. An `[VERDICT: INFO]` (planned op / recovered state) counts as evidence *against* the hypothesis unless its timing overlaps symptom onset.

```
EVIDENCE LEDGER (example — actual ledger should include signals for every scored H)
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

Investigate the highest-scoring hypothesis first. When multiple H tie, prefer system changes (H3/H7) over manual.

### Scoring

| Points | Trigger |
|--------|---------|
| +4 | System change — autoscaler, node repair, GKE upgrade, preemption, HPA, IAM policy change, CoreDNS change, VPC/firewall/route/NAT change (H12), billing account change, in-window `REPAIR_CLUSTER`/`UPGRADE_*` op (H13), or MIG node-delete burst (H14) |
| +2 | **Direct signal** — required-signal match for any H (OOMKilling+exit 137, Evicted, Unhealthy, pool error, IAM `permission denied`, cluster-wide `no such host`, CPU `limit_utilization`>0.8, `ZONE_RESOURCE_POOL_EXHAUSTED` (H11), pods Pending ≥ `$PENDING_GRACE_MIN`m awaiting scale-up with no stockout (H16), NAT/IP-space exhaustion (H12), `BILLING_DISABLED` (B1, critical), node count below pool minimum / mass creation-age reset (H15), etc.), **or a manual deploy → H7** (a system-driven deploy — GKE upgrade, MIG recreation — scores +4 under System change) |
| +1 | **Indirect signal** — statusDetails match, traffic spike before failures, single Unhealthy event, ScalingReplicaSet |

### The Hypotheses (H1–H12, H16 + the B1/H13/H14/H15 family)

| H | Name | Smoking Gun | Required Signal |
|---|------|-------------|-----------------|
| B1  | Billing disabled (CRITICAL) | Any in-window billing-disabled log entry → project billing off → compute reclaimed | `BILLING_DISABLED`/"requires billing to be enabled" in logs (in-window) OR billing account disable/re-assign |
| H1 | OOMKill | `OOMKilling` + exit 137 + mem >85% | exit 137 |
| H2 | Probe failure | `Unhealthy` + (startup/liveness: high restarts; readiness: endpoint flap) | Unhealthy event |
| H3 | Node eviction | `Evicted` + node pressure condition + FailedScheduling | Evicted event |
| H4 | HPA / quota maxed | HPA at max OR quota `used ≥ hard` + FailedScheduling + 504s dominant | HPA at maxReplicas OR quota hard limit hit |
| H5 | Pool exhausted | `pool exhausted` in app logs + DB clean | pool error in logs |
| H6 | Dep failure (Memorystore/Redis) | Redis errors (`READONLY`/`OOM`/`max clients`/timeout to :6379) before probe fail + instance failover/OOM/maxclients | Redis error in logs + instance-side signal |
| H7 | Bad deploy | deploy event + ImagePullBackOff/CrashLoopBackOff | deploy event |
| H8 | IAM / Workload Identity failure | `permission denied` / `token expired` / `403` to GCP API + WI annotation present | permission-denied error in app logs |
| H9 | DNS / CoreDNS degradation | `no such host` across multiple pods/services simultaneously + CoreDNS pod CPU spike or restarts | `no such host` errors cluster-wide |
| H10 | CPU throttling | `cpu/limit_utilization` near 1.0 + probe timeouts but memory flat + no OOMKill event | CPU throttling metric >80% sustained |
| H11 | Cloud capacity stockout (CRITICAL, immediate) | Pods `Pending` + autoscaler scale-up decided but `autoscaledNodesCount` < `Target` + `ZONE_RESOURCE_POOL_EXHAUSTED` on `instances.insert` + quota has headroom | `ZONE_RESOURCE_POOL_EXHAUSTED`/`RESOURCE_POOL_EXHAUSTED` in GCE audit |
| H16 | Scale-up pending latency (CRITICAL after `$PENDING_GRACE_MIN`m) | Unschedulable pods with `TriggeredScaleUp` but no node yet AND **no** stockout error; oldest Pending age ≥ `$PENDING_GRACE_MIN`m (default 10) — below that it is EXPECTED provisioning, not an incident | oldest Pending age ≥ `$PENDING_GRACE_MIN`m with scale-up triggered and no `ZONE_RESOURCE_POOL_EXHAUSTED` |
| H12 | Network infra / VPC | Broad connectivity loss (multi-service, cross-node, or LB→backend) with pods healthy + VPC/firewall/route/NAT/subnet change or NAT/IP-space exhaustion | Network infra change in audit OR NAT/`IP_SPACE_EXHAUSTED`/CNI failure |
| H13 | Repair/upgrade op (WARNING) | In-window `REPAIR_CLUSTER` or `UPGRADE_*` container operation (operations API only) | `REPAIR_CLUSTER` or `UPGRADE_*` op with `startTime` in `$T_START..$T_END` |
| H14 | Node VM delete burst (WARNING) | In-window MIG node VM deletes ≥ `$NODE_DELETE_BURST`, actor = `cloudservices` SA | delete count ≥ `$NODE_DELETE_BURST` by `cloudservices` SA (guard: exclude human/CI deletes) |
| H15 | Node count loss / NotReady / age reset | Count below `minNodeCount` (CRITICAL) OR NotReady ≥ `$NOTREADY_MAX` (WARNING) OR young-node fraction ≥ `$AGE_RESET_FRAC` (WARNING), past guards | count < summed `minNodeCount` OR `NOTREADY ≥ $NOTREADY_MAX` OR `YOUNG/NODES ≥ $AGE_RESET_FRAC`, unexplained by planned scale-down/drain |

**H2 sub-variants:** Startup (never Ready, high restarts), Liveness (was Ready, high restarts), Readiness (running, endpoint flap, low restarts).

**H4 note:** HPA and ResourceQuota are now combined — both starve the scheduler. HPA = scale blocked by maxReplicas or node capacity. Quota = scale blocked by namespace hard limits. Check both before ruling out.

**H5 vs H6:** H5 = client pool full but the backend (DB/Redis) is healthy. H6 = the dependency itself degraded — for Memorystore/Redis: failover, OOM/evictions, maxclients, or CPU saturation.

**H8 vs H6:** H8 = GCP IAM/token failure (permission denied, 403, token expired). H6 = non-GCP dependency is degraded or unreachable. Both show connection errors; distinguish by error message type and whether the target is a GCP service.

**H9 vs H6:** H9 = `no such host` appears across multiple unrelated pods/services simultaneously. H6 = connection errors limited to one downstream service.

**H10 vs H1:** H10 = CPU limit_utilization near 1.0, memory flat, no exit 137, probes time out intermittently. H1 = memory spikes, exit 137 present.

**H11 vs H4:** H11 = cloud-provider stockout — autoscaler *decides* to scale up, GCE rejects the VM with `ZONE_RESOURCE_POOL_EXHAUSTED`, quota has headroom. H4 = Kubernetes-level block — HPA at `maxReplicas` or namespace `ResourceQuota` hit; no VM create even attempted. If quota is the ceiling (`QUOTA_EXCEEDED`), that is H4 (quota), not H11.

**H11 vs H16 (two faces of "pods Pending"):** H11 = nodes **cannot** be created — GCE returns `ZONE_RESOURCE_POOL_EXHAUSTED`; CRITICAL the instant it appears and it will not self-resolve. H16 = nodes **can** be created but haven't yet — pods are Pending while the autoscaler provisions. That is normal for the first few minutes, so H16 is CRITICAL **only** once the oldest Pending pod has waited ≥ `$PENDING_GRACE_MIN` minutes (default 10) **and** there is no stockout error. If a stockout is present, the Pending is H11, not H16. If the autoscaler logged `NotTriggerScaleUp` (max-nodes reached / pod doesn't fit), that is H4, not H16. Check H11's stockout scan first, then H16's Pending-age verdict.

**H12 vs H9 vs H6:** H12 = infrastructure layer (VPC/firewall/route/NAT/subnet) — broad blast radius, pods and CoreDNS healthy, correlates with a network change or NAT/IP exhaustion. H9 = DNS resolution specifically, with CoreDNS itself degraded (restarts/SERVFAIL/CPU). H6 = one specific downstream dependency degraded. Cluster-wide `no such host` with *healthy* CoreDNS points upstream (H12 NAT/forwarder), not H9.

**B1/H13/H14/H15 family vs H3 vs H11:** the family = nodes **reclaimed** — they vanish from the node list entirely (a deleted node is *not* `NotReady`, it is gone). B1 (CRITICAL) = the root cause: a disabled billing account (`BILLING_DISABLED` / billing account change). H15 = the node-side symptom: count drops below the pool `minNodeCount`, or the fleet is mass-recreated (creation-age reset). H14 = the MIG delete burst by `cloudservices` SA that reclaims them. H13 = the `REPAIR_CLUSTER`/`UPGRADE_*` op (operations API only) that rebuilds them. H3 = nodes still present but `Evicted`/`NotReady` under memory/disk pressure. H11 = new nodes can't be *created* (`ZONE_RESOURCE_POOL_EXHAUSTED`), pods stuck `Pending`. Single-zone pools make H15 count-loss look like a total outage — one zone's reclamation removes the whole pool. Note: if a total billing outage stops the cluster's own control-plane/logging, the *absence* of expected node/app logs during the window is itself evidence for B1.

---

## Phase 3 — Deep-Dive (Highest Score First)

Stop at ≥2 independent signals confirming causal chain.

### H1 — OOMKill

See `===== H1 (OOMKill) — OS-level OOMKill =====` and `===== H1 (OOMKill) — Container names,
previous logs, memory limits, VPA =====` in the script output (auto-discovers `POD_NAME`; falls
back to a note if no pod was found — set `$POD_NAME` manually and re-run in that case).

Memory utilization is not CLI-queryable — run this manually in Cloud Console Metrics Explorer
(MQL); the script also prints this as a `[MANUAL: ...]` reminder:
```
fetch k8s_container
| metric 'kubernetes.io/container/memory/limit_utilization'
| filter resource.cluster_name == 'CLUSTER'
     && resource.namespace_name == 'NAMESPACE'
     && resource.pod_name =~ 'SERVICE.*'
| within(30m, d'INCIDENT_TIME_UTC') | every 1m
```
Values >0.85 in 5min before crash = strong H1 confirmation.

**Confirmed if**: oom_kill_process in node syslog + exit 137 + memory utilization >85% in 5min before crash
**Ruled out if**: no oom_kill_process, exit codes not 137, memory flat

---

### H2 — Probe Failure

**Step 1 — Unhealthy events**

See `===== H2 (Probe Failure) — Unhealthy events =====` in the script output.

**Step 2 — Probe configs**

See `===== H2 (Probe Failure) — Probe configs =====` in the script output.

**Step 3 — Check restart count to distinguish sub-variant**

See `===== H2 (Probe Failure) — Restart count / sub-variant + endpoint oscillation + app warnings
=====` in the script output.

- Restarts HIGH + pod never reached Ready → **startup** probe killing slow-starting app
- Restarts HIGH + pod was Ready before → **liveness** (exit 0/143/137 all possible — check for `Unhealthy/Liveness` event)
- Restarts LOW or zero → **readiness** excluded pod from endpoints, pod still running

**Step 4 — Endpoint oscillation (readiness sub-variant)**

Same script section as Step 3 above (endpoint mutation query runs alongside the restart-count query).

**Step 5 — App logs around probe failure timestamps**

Same script section as Step 3 above (app-log warning query runs last in that block).

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

See `===== H3 (Node Eviction) — Evicted / pressure / FailedScheduling / node syslog / preemption /
node state =====` in the script output. Covers, in order: eviction events, node condition events,
FailedScheduling, node syslog (auto-discovered `NODE_INSTANCE_ID` — falls back to a note if
discovery failed; set `$NODE_INSTANCE_ID` manually via `kubectl describe pod $POD_NAME -n
$NAMESPACE | grep Node:` and re-run in that case), GCE preemption/migration events, and current
node conditions summary.

**Confirmed if**: Evicted events + node condition (MemoryPressure/DiskPressure) fires before evictions + FailedScheduling if pods can't reschedule
**Ruled out if**: no Evicted events, nodes all Ready, pods distributed across multiple healthy nodes

---

### H4 — HPA / Quota Maxed

See `===== H4 (HPA/Quota) — HPA state, scale events, autoscaler, FailedScheduling, top pods, quota
=====` in the script output. Covers, in order: current HPA state (is it at `maxReplicas`?), HPA
scale events, cluster autoscaler activity, FailedScheduling events, pod CPU/memory utilization, and
namespace ResourceQuota (hard limits on cpu/memory/pods hit → scheduler rejects new pods → HPA
can't scale even with node headroom).

**503 vs 504**: H4 produces 504s (connection accepted, upstream timed out) not 503s (no endpoint). Pure 503s → H4 unlikely. Mixed → H2+H4 may both be active.

**Confirmed if**: HPA at maxReplicas + CPU/memory high on pods + FailedScheduling or autoscaler blocked + 504 pattern dominant
**Ruled out if**: HPA has headroom, pod count scaled up, errors pure 503

---

### H5 — Pool Exhausted

See `===== H5 (Pool Exhausted) — App logs, DB logs, pool config =====` in the script output.
Covers: app-log pool-exhaustion signatures, Cloud SQL logs (active connections / errors), and
deployment env vars for pool-size config (`DB_POOL_SIZE`, `HIKARI_MAX_POOL_SIZE`, `PG_POOL_MAX`,
etc. — unset means the app is on an ORM default, often 10, easy to exhaust under load). Cross-
reference pool-error timestamps against H2's Unhealthy-event timestamps manually — pool errors
must predate probe failures to be causal.

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

### H6 — Dependency Failure (Memorystore / Redis focus)

Primary downstream dependency is **Memorystore for Redis**. Confirm the app's Redis errors, then correlate with the instance's own health — a Redis failover, OOM, or maxclients ceiling looks identical to app-side connection failure until you check the instance. (For a non-Redis dependency, swap the signatures in step 1 and the instance checks in steps 2–3.)

See `===== H6 (Dependency/Redis) — App error signatures, instance state, blast radius,
connectivity =====` in the script output. Covers: app-log Redis client error signatures,
Memorystore instance state + maintenance/failover audit (`FailoverInstance`/maintenance/restart →
primary flips, briefly returns READONLY/errors), blast radius across other pods on the same
instance, and the pod's node/subnet (for the connectivity-path check below).

Memorystore health is not CLI-queryable — run this manually in Cloud Console Metrics Explorer
(MQL); the script also prints this as a `[MANUAL: ...]` reminder:
```
fetch redis_instance
| metric 'redis.googleapis.com/stats/memory/usage_ratio'   # >0.9 → evictions, writes get OOM-rejected
    -- also: clients/connected, clients/blocked,
    --       stats/reject_connections_count (maxclients hit),
    --       stats/evicted_keys, stats/cpu_utilization,
    --       replication/master_slave_lag (failover/replica lag)
| filter resource.instance_id =~ '.*' | within(30m, d'INCIDENT_TIME_UTC') | every 1m
```

**Redis signal → cause:**
| App log | Instance-side signal | Cause |
|---------|----------------------|-------|
| `READONLY` / role flip | replication role change / `FailoverInstance` | Memorystore failover (transient) |
| `OOM command not allowed`, evictions | `memory/usage_ratio` ≈1.0, `evicted_keys` rising | maxmemory reached |
| `max number of clients` / rejects | `reject_connections_count` > 0, `clients/connected` at max | connection ceiling (akin to H5) |
| `LOADING` | instance restarting/restoring | instance restart |
| `connection refused/timeout to :6379` | instance `state=READY`, metrics normal | network path (→ H12), not H6 |

**Causal direction check**: Redis error logs must predate readiness probe failures. If probe failures came first → H6 is downstream, not root cause.

**Confirmed if**: Redis client errors predate probe failures + a Memorystore-side signal (failover / OOM / maxclients / CPU) or maintenance event + other consumers of the same instance also degraded
**Ruled out if**: no Redis errors in app logs; instance `READY` with normal memory/clients/CPU and no failover; errors are pure `refused/timeout to :6379` with a healthy instance (→ H12); or app shows pool-exhaustion while Redis is healthy (→ H5)

---

### H7 — Bad Deploy

**Gate already run in Phase 1e.** No deploy found → stop here. Deploy found → set `DEPLOY_TIME` and continue:

See `===== H7 (Bad Deploy) — New pod status, failure events, missing refs, rollout history =====`
in the script output. Covers, in order: new-pod status (stuck in a bad state?), image pull/config/
mount failure events, a check for missing secrets/configmaps referenced by the deployment, and
rollout history (what image/config changed).

**Confirmed if**: deploy timestamp precedes first error + new pods in ImagePullBackOff/CrashLoopBackOff/CreateContainerConfigError/Pending + endpoint count dropped as old pods terminated
**Ruled out if**: no deploy changes in [T-2h, T_END] — stop after gate query

**Common H7 sub-causes**:
- `ImagePullBackOff` → wrong image tag, registry auth failed, image doesn't exist
- `CreateContainerConfigError` → missing secret/configmap key, invalid env var reference
- `FailedMount` → PVC not bound, secret/configmap doesn't exist
- `CrashLoopBackOff` → app crashes on startup (bad config, missing dep, code bug)

---

### H8 — IAM / Workload Identity Failure

**Gate:** Only investigate if app logs contain `permission denied`, `403`, `PERMISSION_DENIED`, `token expired`, or `invalid_grant` errors pointing at a GCP API.

See `===== H8 (IAM/WI) — App auth errors, WI annotations, IAM changes (critical window), IAM
policy, SA keys =====` in the script output. Covers, in order: app-log IAM/auth error signatures,
Workload Identity annotation presence per ServiceAccount, IAM policy changes in the audit log
(critical window T−6h — a key/policy change can predate the failure by hours, until cached tokens
expire), the project IAM policy filtered to WI-bound members, and service-account key list (if not
using WI; auto-discovers the deployment's `serviceAccountName`).

**Confirmed if**: `permission denied` / `403` / `token expired` in app logs pointing at GCP API + IAM policy change or key expiry in audit log predating errors, OR WI annotation present but GCP SA binding missing
**Ruled out if**: no auth/permission errors in app logs, IAM policy unchanged in T-2h window

**H8 vs H6 distinction:**
| Signal | H8 (IAM failure) | H6 (dep failure) |
|--------|-----------------|-----------------|
| Error message | `permission denied`, `403`, `token expired`, `PERMISSION_DENIED` | `connection refused`, `timeout`, `ECONNREFUSED` |
| Target | GCP API (Cloud SQL, GCS, Pub/Sub, Secret Manager) | Internal service or non-GCP dep |
| Other pods | Same if they share the SA | May be isolated to this service |
| IAM audit log | Policy change or key deletion present | No IAM events |

---

### H9 — DNS / CoreDNS Degradation

**Gate:** Only investigate if `no such host` or DNS-related errors appear across **multiple unrelated pods or services** simultaneously, OR if a single service shows persistent DNS failures without a network topology change.

See `===== H9 (DNS/CoreDNS) — Cluster-wide DNS errors, CoreDNS state/logs/resources/config =====`
in the script output. Covers, in order: cluster-wide DNS error signatures, CoreDNS pod state,
CoreDNS logs, CoreDNS CPU/memory + OOMKill/Unhealthy/BackOff events in `kube-system`, and the
CoreDNS ConfigMap (upstream forwarder / rewrite rule changed?).

**Confirmed if**: `no such host` / `SERVFAIL` errors across multiple pods + CoreDNS pod restarts or CPU spike in the window
**Ruled out if**: DNS errors limited to one pod/service (likely H6), CoreDNS pods healthy with no restarts, errors persist after CoreDNS recovery

**H9 vs H6:**
| Signal | H9 (DNS degraded) | H6 (dep failure) |
|--------|------------------|-----------------|
| Scope | Multiple pods and services fail DNS | Single downstream service unreachable |
| CoreDNS | Restarts, CPU throttling, or SERVFAIL logs | Healthy |
| Error type | `no such host`, `SERVFAIL`, `NXDOMAIN` | `connection refused`, `timeout` after successful DNS |

---

### H10 — CPU Throttling

**Gate:** Only investigate if memory is flat (no OOMKill), exit codes are not 137, and probe timeouts are intermittent rather than consistent. CPU throttling causes slow responses that fail `timeoutSeconds`-tight probes without killing the pod.

See `===== H10 (CPU Throttling) — CPU limits, probe timeoutSeconds, Unhealthy events, node CPU
=====` in the script output. Covers: configured CPU requests/limits, probe `timeoutSeconds`/
`periodSeconds` (timeoutSeconds=1 default + CPU throttled → probe times out → pod killed/
excluded), Unhealthy events (present same as H2 but distinguish via no OOMKill + memory flat), and
node CPU pressure/`kubectl top nodes`.

CPU utilization is not CLI-queryable — run this manually in Cloud Console Metrics Explorer (MQL);
the script also prints this as a `[MANUAL: ...]` reminder:
```
fetch k8s_container
| metric 'kubernetes.io/container/cpu/limit_utilization'
| filter resource.cluster_name == 'CLUSTER'
     && resource.namespace_name == 'NAMESPACE'
     && resource.pod_name =~ 'SERVICE.*'
| within(30m, d'INCIDENT_TIME_UTC') | every 1m
```
Values >0.8 sustained = strong H10 signal.

**Confirmed if**: CPU `limit_utilization` >0.8 sustained before probe failures + probe `timeoutSeconds` ≤ 1 + no OOMKill, memory flat + Unhealthy events present
**Ruled out if**: CPU headroom available, timeoutSeconds generous (≥5), exit codes are 137 (→ H1 instead)

**H10 vs H1:**
| Signal | H10 (CPU throttle) | H1 (OOMKill) |
|--------|--------------------|--------------|
| Exit code | 0, 1, 143 (probe kill) | 137 |
| Memory | Flat | Spike to limit |
| OOMKilling event | Absent | Present |
| CPU limit_utilization | >0.8 sustained | Variable |
| Probe timeout | Yes, tight timeoutSeconds | Not primary |

---

### H11 — Cloud Capacity Stockout

**Gate:** Only investigate if pods are stuck `Pending`/`FailedScheduling` AND the autoscaler tried to add nodes. H11 is specifically the case where the nodes **cannot** be created. If quota is the ceiling (`QUOTA_EXCEEDED`) or the block is HPA/ResourceQuota, that is H4 — not H11. If nodes *can* be created but simply haven't arrived yet, that is **H16** (scale-up latency), not H11.

See `===== H11 (Capacity Stockout) — Pending pods, stockout errors, quota, topology =====` in the
script output. Covers, in order: pending pods + FailedScheduling reasons, GCE stockout errors on
instance creation (the smoking gun), an explicit **H11 FIRES (CRITICAL)** / does-not-fire verdict,
quota headroom (rules out H4-quota), and node pool topology (single-zone = no fallback, contributing
factor).

**Confirmed if**: pods `Pending` + `ZONE_RESOURCE_POOL_EXHAUSTED`/`RESOURCE_POOL_EXHAUSTED` on `instances.insert` + quota under limit — fires CRITICAL immediately, will not self-resolve
**Ruled out if**: no stockout errors (create fails with `QUOTA_EXCEEDED` → H4-quota; no create attempted → H4-HPA/ResourceQuota; created but slow → H16), or nodes provisioned fine

**Contributing factors to note**: single-zone node pool `locations` (no multi-zone fallback), no alternate machine-family pool with autoscaling enabled, no capacity reservation for baseline footprint.

---

### H16 — Scale-up Pending Latency

**Gate:** Investigate when pods are `Pending`/`Unschedulable` and the autoscaler **did** trigger a scale-up (`TriggeredScaleUp`) but the nodes have not become Ready yet, **and H11's stockout scan came back clean**. This is normal for the first few minutes of provisioning, so H16 is an incident **only** once the wait exceeds the grace period.

See `===== H16 (Scale-up Pending Latency) — pods Pending awaiting new nodes past grace =====` in the
script output. It reports the unschedulable-pod count, the **oldest Pending age in seconds** vs the
grace (`$PENDING_GRACE_MIN`m, default 10), whether a stockout is present, the `TriggeredScaleUp` /
`NotTriggerScaleUp` autoscaler events, and an explicit verdict:

- **H16 FIRES (CRITICAL)** — oldest Pending age ≥ grace, no stockout, **and** a `TriggeredScaleUp` in the window: the autoscaler asked for nodes but they aren't arriving. Check 1g.4 quota, IP space (H12), or node boot failures.
- **NOT H16 → H4** — age ≥ grace but the autoscaler logged `NotTriggerScaleUp` (max-nodes reached / pod fits no pool): pods stay Pending until replicas/quota/pool-max change. Score under H4.
- **H16 LIKELY** — age ≥ grace, no stockout, but no scale-up decision logged in the window: confirm a scale-up was attempted (1g.1) before scoring H16 vs H4.
- **H16 EXPECTED (not yet an incident)** — Pending within grace: autoscaler provisioning in progress; re-check after `$PENDING_GRACE_MIN`m.
- **does not fire** — no unschedulable pods, or the Pending is explained by an H11 stockout (fix capacity, not latency).

> The Pending-age verdict is a **live** `kubectl` snapshot; the `TriggeredScaleUp`/`FailedScheduling` evidence is windowed to `T_START..T_END`. For a past/recovered incident, trust the windowed events over a live "does not fire".

**Confirmed if**: unschedulable pods with `TriggeredScaleUp` + oldest Pending age ≥ `$PENDING_GRACE_MIN`m + **no** `ZONE_RESOURCE_POOL_EXHAUSTED`
**Ruled out if**: Pending within grace (expected), a stockout is present (→ H11), the autoscaler logged `NotTriggerScaleUp`/max-nodes (→ H4), or no pods are Pending

**Tuning:** lower `PENDING_GRACE_MIN` to flag slow scale-ups sooner (risks firing on normal-but-slow provisioning — large images, NAP node creation, cold MIG); raise it to reduce false positives at the cost of slower detection.

---

### H12 — Network Infrastructure / VPC

**Gate:** Only investigate if connectivity is broadly broken (multiple services, cross-node, or LB→backend) while pods and CoreDNS look healthy, OR a VPC/firewall/route/NAT/subnet change lands in [T-2h, T_END].

Steps 1-5 are identical to the 1h queries already run in the broad sweep — see `=====
1h.1-1h.5 =====` in the script output. Step 6 (confirm pods/CoreDNS are healthy, proving the
failure is infra not app/DNS) is under `===== H12 (Network/VPC) — Confirm pods/CoreDNS healthy
(deep-dive queries already run in 1h) =====`.

**Confirmed if**: network infra change (or NAT/IP-space exhaustion, or CNI failures) in window + broad connectivity loss across services/nodes + pods and CoreDNS healthy + (LB backends UNHEALTHY while k8s readiness passes, if LB-fronted)
**Ruled out if**: connectivity failures isolated to one dependency (→ H6), CoreDNS itself degraded (→ H9), no network change and NAT/subnet have headroom

**Contributing factors to note**: overly broad firewall/route edits, Cloud NAT undersized (min ports per VM), small pod/subnet secondary ranges near exhaustion, single NAT gateway with no redundancy.

---

### B1 / H13 / H14 / H15 — Billing & Node Reclamation

Deep-dive for the four family rules (B1 billing-disabled, H13 repair/upgrade op, H14 delete burst,
H15 node count-loss/NotReady/age-reset). The 1i fingerprint already reports which rules fired; this
step bounds the outage and proves the causal chain between them.

**Gate:** Only investigate if node count dropped below the pool `minNodeCount` / whole pools
disappeared, nodes are all younger than the incident window (fleet recreated), a `BILLING_DISABLED`
log or billing account change appears, or a `REPAIR_CLUSTER`/`UPGRADE_*` op is present. Ran the fingerprint in 1i.

See `===== B1/H13/H14/H15 (Billing & Node Reclamation) — outage span + REPAIR_CLUSTER op detail
=====` in the script output. Covers, in order: billing disable/enable timeline (critical window
T−6h), first/last `BILLING_DISABLED`/"requires billing to be enabled" occurrence (bounds the
outage — T−6h so the FIRST occurrence isn't clipped when the disable predates the node loss),
node VM delete burst per-minute count + actor confirmation (user-agent "GCE Managed Instance Group
for GKE", principal `cloudservices` SA), and `REPAIR_CLUSTER`/upgrade/resize ops via the
operations API (NOT Cloud Logging — `statusMessage`/`error`/`detail` are empty; GKE does not
expose the trigger reason, so correlate `startTime` with the billing re-enable manually to
establish causation).

**Per-rule verdict:**
- **B1 (CRITICAL) confirmed if** ≥1 in-window billing-disabled entry OR a billing account disable/re-assign; **ruled out if** `billingEnabled=True` throughout with no account change and no in-window billing-disabled logs.
- **H13 (WARNING) confirmed if** an in-window `REPAIR_CLUSTER`/`UPGRADE_*` op is present; **ruled out if** none in `$T_START..$T_END`.
- **H14 (WARNING) confirmed if** in-window MIG deletes ≥ `$NODE_DELETE_BURST` by the `cloudservices` SA; **ruled out if** below burst or deletes are human/CI.
- **H15 confirmed if** count < summed `minNodeCount` (CRITICAL) / NotReady ≥ `$NOTREADY_MAX` (WARNING) / young fraction ≥ `$AGE_RESET_FRAC` (WARNING) past its guard; **ruled out if** node count matches pool config, NotReady below threshold, and no mass age reset.

**Full-outage confirmed if**: B1 fires + H15 count-loss + H14 delete burst + (usually) H13 `REPAIR_CLUSTER` starting right after billing is restored.

**Causal order:** B1 billing disabled → compute reclaimed (H14 delete burst → H15 nodes vanish, workloads 503) → billing
restored → H13 `REPAIR_CLUSTER` → MIG recreates fleet → H15 creation-age reset, nodes rejoin. The billing event must
**predate** the node loss; an H13 `REPAIR_CLUSTER` with no preceding B1/pressure signal is a
routine repair, not this family.

**Contributing factors to note**: single-zone node pools (one zone's reclamation removes the
whole pool), no Cloud Billing budget/`billingEnabled` alert to page before nodes are reclaimed,
payment method expiry / billing account closure, spending cap hit.

---

## Phase 4 — Cross-Correlation (6 Checks)

Complete all before RCA.

| # | Check | Rule |
|---|-------|------|
| 1 | Timestamp order | Root cause < all downstream. Out-of-order = invalid |
| 2 | Two signals | Each confirmed H needs ≥2 independent signals. Examples — H1: oom_kill + exit 137. H2: Unhealthy + endpoint flap. H3: Evicted + node pressure. H4: HPA at max + FailedScheduling. H5: pool error + DB conn at max. H6: Redis error + instance-side signal (failover/OOM/maxclients). H7: deploy event + new-pod failure state. H8: permission-denied + IAM/key change. H9: cluster-wide DNS errors + CoreDNS restarts. H10: CPU>0.8 + tight probe timeout. H11: `ZONE_RESOURCE_POOL_EXHAUSTED` + autoscaler target>count gap (quota clear). H16: pods Pending ≥ `$PENDING_GRACE_MIN`m + `TriggeredScaleUp` with no stockout (quota/IP clear). H12: network change or NAT/IP exhaustion + broad connectivity loss with healthy pods. B1/H13/H14/H15 family: B1 `BILLING_DISABLED`/billing account change + H15 node count below pool minimum + H14 MIG delete burst + H13 `REPAIR_CLUSTER`/`UPGRADE_*` op (B1 alone is enough to confirm the critical root cause). |
| 3 | Parsimony | One H explains all signals? Don't force-fit a second |
| 4 | Required signal | H1: 137. H2: Unhealthy. H3: Evicted. H4: HPA max or quota hit. H5: pool msg. H6: Redis error + instance-side signal. H7: deploy event. H8: permission-denied in logs. H9: no-such-host cluster-wide. H10: CPU throttle >0.8 + tight probe timeout. H11: `ZONE_RESOURCE_POOL_EXHAUSTED` in GCE audit. H16: oldest Pending age ≥ `$PENDING_GRACE_MIN`m with `TriggeredScaleUp` and no stockout. H12: network infra change OR NAT/`IP_SPACE_EXHAUSTED`/CNI failure. B1: in-window billing-disabled log (CRITICAL). H13: in-window `REPAIR_CLUSTER`/`UPGRADE_*` op. H14: MIG delete burst ≥ `$NODE_DELETE_BURST`. H15: node count below minimum / mass creation-age reset |
| 5 | User match | Data ≠ reported time? Real incident started earlier |
| 6 | Traffic direction | A) spike < k8s event → traffic caused (H4/H1). B) k8s event < spike → retry storm. C) flat → pod-only |

---

## Phase 5 — RCA Report

```
## GKE Incident Report

Cluster:     <name> / <region>
Namespace:   <namespace>
Services:    <service names>
Query window: <T_START UTC> → <T_END UTC>   # range used to pull logs/metrics
Impact:      <T_first_symptom UTC> → <T_fully_recovered UTC>   # actual user-visible window
MTTD:        <first symptom → first alert/detection>
MTTM:        <first alert → service fully restored>

---

### Affected Scope

**Pods**
| Pod | Container | Restarts | Exit Code | Down From | Recovered At |
|-----|-----------|----------|-----------|-----------|--------------|
| <pod-name> | <container> | <n> | <code> | <time UTC> | <time UTC> |

**Replicas**
| State | Count |
|-------|-------|
| Desired | <n> |
| Healthy during incident (min) | <n> |
| Unhealthy / restarting (peak) | <n> |

**Endpoints**
| Service | Addresses (normal) | Addresses (min during incident) | NotReady (peak) |
|---------|--------------------|---------------------------------|-----------------|
| <service> | <n> | <n> | <n> |

**Error Volume**
| Metric | Value |
|--------|-------|
| Total 5xx errors in window | <n> |
| Peak error rate (per min) | <n> |
| Dominant status code | 503 / 504 / 502 |
| User-visible impact | Partial / Full outage |

**Nodes affected** — `<node names or "none">` (eviction / preemption / pressure)

**Blast radius** — Other services or namespaces degraded: `<list or "none detected">`

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
| #   | Hypothesis                          | Verdict   | Key Evidence                                       |
|-----|-------------------------------------|-----------|----------------------------------------------------|
| B1  | Billing disabled (CRITICAL)         | RULED OUT | billing enabled throughout, no in-window billing-disabled logs |
| H1  | OOMKill → restart cascade           | CONFIRMED | exit 137 + oom_kill_process + mem spike            |
| H2  | Probe failure (liveness/readiness)  | RULED OUT | no Unhealthy events                                |
| H3  | Node pressure → eviction            | RULED OUT | no Evicted events, nodes all Ready                 |
| H4  | HPA / quota maxed                   | RULED OUT | HPA had headroom, quota under hard limit           |
| H5  | DB connection pool exhausted        | RULED OUT | no pool exhaustion messages in app logs            |
| H6  | Dependency failure (Memorystore/Redis) | RULED OUT | no Redis errors; instance READY, no failover/OOM   |
| H7  | Bad deploy → pods never Ready       | RULED OUT | no deploy changes in -2h window                    |
| H8  | IAM / Workload Identity failure     | RULED OUT | no permission-denied errors, IAM policy unchanged  |
| H9  | DNS / CoreDNS degradation           | RULED OUT | CoreDNS pods healthy, no SERVFAIL logs             |
| H10 | CPU throttling → probe timeout      | RULED OUT | CPU headroom available, exit codes not probe-kill  |
| H11 | Cloud capacity stockout             | RULED OUT | no ZONE_RESOURCE_POOL_EXHAUSTED, nodes provisioned  |
| H12 | Network infra / VPC                  | RULED OUT | no network change, NAT/subnet headroom, pods healthy|
| H13 | Repair/upgrade op (WARNING)         | RULED OUT | no in-window REPAIR_CLUSTER/UPGRADE_* op |
| H14 | Node VM delete burst (WARNING)      | RULED OUT | in-window MIG deletes below $NODE_DELETE_BURST |
| H15 | Node count loss / NotReady / age reset | RULED OUT | node count matches pool config, NotReady below threshold, no mass age reset |

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

**Allowed:** `kubectl get/describe/logs/top/rollout history`, `gcloud logging read`, `gcloud monitoring metrics list`, `gcloud compute/container describe`, `gcloud container operations list`, `gcloud container node-pools list`, `gcloud billing projects describe`, `gcloud auth list`, `gcloud config get-value`, `gcloud container clusters get-credentials` after confirmation

**Never:** `kubectl apply/delete/edit/patch/exec/cp/port-forward`, `gcloud create/delete/update/set/patch`. Redact secrets.

`scripts/gke-collect.sh` is the canonical way to run the Phase 1/3 read-only sweep — every command
inside it stays within the Allowed list above, and the only state-mutating step
(`get-credentials`, kubeconfig only) is gated behind an explicit `--get-credentials` flag.

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
| Codes | 503 vs 504 | 503 = no healthy/reachable backend (H1/H2/H3/H7/H8/H9/H11/H12/B1+H15). 504 = timeout (H4/H5/H6/H10) |
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
| H8 | WI looks like H6 | Check error message: `403`/`permission denied` = H8, `ECONNREFUSED` = H6 |
| H9 | DNS isolated to one pod misread as H6 | H9 requires multi-pod/multi-service scope; single-pod = H6 |
| H10 | Throttle looks like H2 | H10: CPU >80% + tight timeout. H2: CPU normal, app logic slow |
| H10 | No CPU limit = no throttle | Throttling only occurs when `.resources.limits.cpu` is set |
| H11 | Stockout misread as quota | `ZONE_RESOURCE_POOL_EXHAUSTED` = H11 (capacity). `QUOTA_EXCEEDED` = H4-quota. Check region quota usage vs limit |
| H11 | Autoscaler "works" but no nodes | Scale-up *decision* ≠ node created; watch `autoscaledNodesTarget` > `autoscaledNodesCount` gap and create/delete churn by `container-engine-robot` |
| H11 | Single-zone pool hides fallback | A zone stockout fully blocks a single-zone pool; multi-zone or NAP would have fallback |
| H16 | Pending ≠ instant incident | Pods Pending during a scale-up is EXPECTED for the first few minutes; only CRITICAL once oldest Pending age ≥ `$PENDING_GRACE_MIN`m AND no stockout (else H11). `NotTriggerScaleUp`/max-nodes = H4, not H16 |
| H12 | Network infra looks like H6/H9 | H12 = broad blast radius + healthy pods/CoreDNS + network change/NAT/IP exhaustion. H6 = one dep. H9 = CoreDNS itself degraded |
| H12 | Healthy pods but LB UNHEALTHY | Firewall change blocking GKE health-check ranges (35.191.0.0/16, 130.211.0.0/22) flips backends down while k8s readiness passes |
| H12 | `IP_SPACE_EXHAUSTED` ≠ capacity | Subnet/pod-CIDR exhaustion is a network (H12) problem, not a machine stockout (H11) |
| H15 | Nodes gone read as eviction | A reclaimed node vanishes from `kubectl get nodes` — it is NOT `NotReady`. Count below pool `minNodeCount` = H15 count-loss, not H3 |
| H13 | `REPAIR_CLUSTER`/`UPGRADE_*` invisible in logs | They only appear in `gcloud container operations list` (operations API), never in Cloud Logging |
| H14 | MIG deletes missed by 1f filter | The MIG deletes VMs as `<projnum>@cloudservices.gserviceaccount.com` (UA "GCE Managed Instance Group for GKE") — not `system:/gke-/container-engine`; match it explicitly |
| B1 | `BILLING_DISABLED` global search empty | The real payload is "…requires billing to be enabled…", not the token `BILLING_DISABLED`; field-scope `textPayload:"requires billing to be enabled"` (a bare `"BILLING_DISABLED"` search misses it) |
| B1 | Monitor silent during outage | If billing kills the project, the monitor/logging in-project may not run — absence of expected logs is itself a B1 signal; page via an external billing budget alert |
