# GKE Service — Monitoring & Alerting Metrics

Standalone reference (not part of the investigation skill). Proactive signals that would catch each `gke-service-incident` hypothesis (H1–H12) **before** a human report. Use to build Cloud Monitoring dashboards, alert policies, and SLOs — the recurring "add alerting" RCA follow-up.

## Source legend

| Tag | Source | Availability |
|-----|--------|--------------|
| **[GKE]** | GKE system metrics `kubernetes.io/...` | Always on |
| **[LB]** | Cloud Load Balancing `loadbalancing.googleapis.com/...` | On when LB logging/metrics enabled |
| **[Net]** | Compute/VPC/NAT `compute.googleapis.com/...`, `router.googleapis.com/nat/...` | Always on (NAT metrics when Cloud NAT used) |
| **[Quota]** | `serviceruntime.googleapis.com/quota/...` | Always on |
| **[Redis]** | Memorystore for Redis `redis.googleapis.com/...` | On when Memorystore used |
| **[SQL]** | Cloud SQL `cloudsql.googleapis.com/...` | Per datastore (non-Redis deps) |
| **[KSM]** | kube-state-metrics `prometheus.googleapis.com/kube_*` | **Requires** GKE Managed Prometheus + kube-state-metrics package |
| **[Log]** | Log-based metric (counter/distribution over a Cloud Logging filter) | Create per filter |

> **Prerequisite:** H2/H3/H4/H7/H11 lean on **[KSM]**. Enable Managed Prometheus (`--enable-managed-prometheus`) and the kube-state-metrics package, or substitute the closest native `kubernetes.io/...` metric where noted.

---

## Metrics per hypothesis

### H1 — OOMKill
| Metric | Source | Alert |
|--------|--------|-------|
| `kubernetes.io/container/memory/limit_utilization` | [GKE] | > 0.85 for 5m |
| `kubernetes.io/container/memory/used_bytes` vs container limit | [GKE] | approaching limit |
| `kubernetes.io/container/restart_count` (delta) | [GKE] | ≥ 2 / 10m |
| `OOMKilling` k8s event / `oom_kill_process` node syslog | [Log] | any occurrence |

### H2 — Probe failure (startup / liveness / readiness)
| Metric | Source | Alert |
|--------|--------|-------|
| `Unhealthy` probe events (by probe type) | [Log] | > N / 5m |
| `kubernetes.io/container/restart_count` (delta) | [GKE] | rising alongside Unhealthy |
| `kube_deployment_status_replicas_available` vs `..._replicas` | [KSM] | available < desired for 5m |
| LB healthy backend count (readiness flap) | [LB] | oscillating / < desired |

### H3 — Node eviction / pressure
| Metric | Source | Alert |
|--------|--------|-------|
| `kube_node_status_condition{condition="MemoryPressure\|DiskPressure\|PIDPressure"}` | [KSM] | true on any node |
| `kubernetes.io/node/ephemeral_storage/used_bytes` ÷ capacity | [GKE] | > 0.85 |
| `kubernetes.io/node/memory/allocatable_utilization` | [GKE] | > 0.9 sustained |
| `Evicted` / preemption events | [Log] | any occurrence |

### H4 — HPA / quota maxed
| Metric | Source | Alert |
|--------|--------|-------|
| `kube_horizontalpodautoscaler_status_current_replicas` vs `..._spec_max_replicas` | [KSM] | current = max for 10m |
| `kube_resourcequota{type="used"}` vs `{type="hard"}` | [KSM] | used ≥ 0.9 × hard |
| `kube_pod_status_phase{phase="Pending"}` | [KSM] | > 0 for 10m |
| `FailedScheduling` events | [Log] | sustained |

### H5 — Connection pool exhausted
| Metric | Source | Alert |
|--------|--------|-------|
| DB connections in use vs `max_connections` (`.../num_backends`, `threads_connected`) | [SQL] | > 0.9 × max |
| pool-exhaustion / acquire-timeout messages | [Log] | any occurrence |
| app pool active/idle/wait gauges (if exported) | custom | wait > 0 sustained |

### H6 — Dependency failure (Memorystore / Redis)
| Metric | Source | Alert |
|--------|--------|-------|
| `redis.googleapis.com/stats/memory/usage_ratio` | [Redis] | > 0.9 (evictions / OOM writes) |
| `redis.googleapis.com/stats/reject_connections_count` | [Redis] | > 0 (maxclients hit) |
| `redis.googleapis.com/clients/connected` vs instance max | [Redis] | approaching max |
| `redis.googleapis.com/stats/cpu_utilization` | [Redis] | > 0.9 |
| `redis.googleapis.com/replication/master_slave_lag` / role change | [Redis] | lag spike / failover |
| `redis.googleapis.com/stats/evicted_keys` | [Redis] | rising |
| Redis client errors (`READONLY`/`OOM`/`max number of clients`/timeout to :6379) | [Log] | rate spike |
| _(non-Redis deps)_ `cloudsql.googleapis.com/database/up`, CPU, connections | [SQL] | up = 0 or CPU > 0.9 |

### H7 — Bad deploy
| Metric | Source | Alert |
|--------|--------|-------|
| `kube_deployment_status_replicas_unavailable` | [KSM] | > 0 after a rollout |
| `kube_deployment_status_observed_generation` vs `..._metadata_generation` | [KSM] | lag after apply |
| `ImagePullBackOff` / `CrashLoopBackOff` / `CreateContainerConfigError` waiting reasons | [Log] | any occurrence |
| deploy audit events (`.deployments.(update\|patch)`) | [Log] | correlate with error onset |

### H8 — IAM / Workload Identity failure
| Metric | Source | Alert |
|--------|--------|-------|
| `permission denied` / `403` / `token expired` / `invalid_grant` to a GCP API | [Log] | any occurrence |
| IAM policy / SA-key change audit (`SetIamPolicy`, `DeleteServiceAccountKey`) | [Log] | any change |
| metadata-server token error rate (if surfaced) | custom / [Log] | spike |

### H9 — DNS / CoreDNS degradation
| Metric | Source | Alert |
|--------|--------|-------|
| CoreDNS `kubernetes.io/container/restart_count` (`kube-system`, `k8s-app=kube-dns`) | [GKE] | ≥ 1 restart |
| CoreDNS `cpu/limit_utilization`, `memory/limit_utilization` | [GKE] | > 0.8 |
| `coredns_dns_responses_total{rcode="SERVFAIL"}`, `coredns_forward_healthcheck_failures_total` | [KSM]/GMP | rising |
| cluster-wide `no such host` / `SERVFAIL` | [Log] | multi-service occurrence |

### H10 — CPU throttling
| Metric | Source | Alert |
|--------|--------|-------|
| `kubernetes.io/container/cpu/limit_utilization` | [GKE] | > 0.8 sustained (5m) |
| `container_cpu_cfs_throttled_periods_total` ÷ `..._cfs_periods_total` | [KSM]/cadvisor | throttle ratio > 0.25 |
| `kubernetes.io/container/cpu/core_usage_time` rate vs limit | [GKE] | pinned at limit |

### H11 — Cloud capacity stockout
| Metric | Source | Alert |
|--------|--------|-------|
| autoscaler `autoscaledNodesTarget` − `autoscaledNodesCount` gap | [Log]/visibility | gap > 0 for 10m |
| `ZONE_RESOURCE_POOL_EXHAUSTED` / `RESOURCE_POOL_EXHAUSTED` on `instances.insert` | [Log] | any occurrence |
| unschedulable / Pending pods (`kube_pod_status_unschedulable`) | [KSM] | > 0 for 10m |
| regional quota usage vs limit (`quota/allocation/usage`, `quota/exceeded`) | [Quota] | usage > 0.9 × limit **or** exceeded > 0 (→ H4-quota) |

### H12 — Network infrastructure / VPC
| Metric | Source | Alert |
|--------|--------|-------|
| Cloud NAT `router.googleapis.com/nat/dropped_sent_packets_count` | [Net] | > 0 |
| Cloud NAT `nat/port_usage` / `nat/allocated_ports` per VM | [Net] | approaching min-ports ceiling |
| subnet / pod-range IP utilization (`kube_node_status_capacity{resource="pods"}` used vs alloc; `IP_SPACE_EXHAUSTED`) | [KSM]/[Log] | > 0.9 or any exhaustion |
| LB `https/backend_request_count{response_code_class!="200"}` + backend healthy count | [LB] | 5xx class rising while pods Ready |
| firewall / route / NAT / peering change audit | [Log] | any change |

---

## Golden top-level alerts

Cheap, high-coverage — each fires for several hypotheses at once. Start here.

| Alert | Metric | Fires for |
|-------|--------|-----------|
| LB 5xx ratio | `loadbalancing.googleapis.com/https/request_count{response_code_class="500"}` ÷ total | H1/H2/H3/H7/H8/H9/H12 |
| LB backend p99 latency | `loadbalancing.googleapis.com/https/backend_latencies` | H4/H5/H6/H10 |
| Ready-vs-desired replica gap | `kube_deployment_status_replicas_available` vs `..._replicas` [KSM] | H1/H2/H3/H7 |
| Pending/unschedulable pods > 0 sustained | `kube_pod_status_phase{phase="Pending"}` / `kube_pod_status_unschedulable` [KSM] | H4 **and** H11 |
| Node NotReady count > 0 | `kube_node_status_condition{condition="Ready",status="false"}` [KSM] | H3/H11/H12 |
| Container restart rate | `kubernetes.io/container/restart_count` delta [GKE] | H1/H2/H7/H9 |

---

## Notes on building the alerts

- **Log-based metrics [Log]:** create a counter metric on the exact `gcloud logging` filter used in the matching phase of the skill (e.g., `ZONE_RESOURCE_POOL_EXHAUSTED`, `Unhealthy`, `permission denied`), then alert on `count > 0`.
- **Utilization ratios:** GKE exposes `*/limit_utilization` directly — prefer it over computing `used ÷ limit`.
- **Thresholds are starting points** — tune to each service's baseline (see the skill's T-7d baseline query). Duration/`for` windows matter more than absolute values for flappy signals (H2 readiness, H9).
- **SLO tie-in:** the two LB golden alerts (5xx ratio, backend p99) map directly to availability and latency SLOs; the rest are diagnostic drill-downs.
