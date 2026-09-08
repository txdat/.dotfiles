# GKE Diagnostic Reference

Read the sections relevant to signals returned by [inspect-incident.md](inspect-incident.md). Hypothesis IDs are the collector's lookup keys, not a requirement to investigate every cause.

## Scope and history

Verify Service/Deployment ownership with selectors when names overlap. Multi-service log queries cover the expanded service set, but primary-service endpoint/NEG checks may need repeating per service. Inspect internal and external load balancers and Gateway as well as Ingress resources.

Current pod/node health does not reconstruct an outage. Kubernetes events and previous-container logs have limited retention; use historical logs/metrics for earlier failures. Record source lag and missing intervals. A successful capability probe does not guarantee that a later query succeeded.

Container operations are location-scoped: verify the target cluster when `targetLink` is missing. An operation on a sibling cluster cannot explain this cluster's symptoms or mask node-loss evidence.

## Traffic and load balancers — G1

Use the collector's metric-derived window, peak-minute, worst-backend, and sibling summaries for request/error counts and ratios. Log sampling, limits, or exclusion filters can omit both successes and failures; sampled logs supply examples and `statusDetails`, not an exact outage rate.

Scope metrics to the affected backends. A shared load balancer or health/polling traffic can dilute a window ratio; compare per-minute and per-backend impact before claiming a partial or full outage. State a logs-only estimate's limits when metrics are unavailable.

Metric buckets are labeled by interval end, while logs record request time. Recent metric buckets can lag; a falling trailing edge in an ongoing incident is not proof of recovery. Inspect sample spans and query windows before comparing sources.

A 5xx spike establishes impact, not cause. Relate `statusDetails`, backend health, pod readiness, endpoints, and historical events. Load-balancer health checks and Kubernetes probes differ. Traffic preceding failures may indicate load pressure; traffic after failures may include retries. Corroborate either mechanism rather than inferring it from order alone.

## Application and dependency signals

| ID | Candidate | Discriminating evidence |
|---|---|---|
| H1 | OOM termination | Correlate termination reason/node OOM evidence and memory history. Exit 137 alone does not establish OOM. |
| H2 | Probe failure | Inspect the failed probe and timing: startup before initial readiness, liveness triggering restarts, readiness removing endpoints while containers may stay running. |
| H3 | Eviction | Match pod eviction with preceding node pressure and subsequent scheduling impact; distinguish existing pressured nodes from disappeared nodes (H15). |
| H4 | Scaling/quota limit | Check HPA limits, namespace quotas, node limits, scheduling and autoscaler reasons. Distinguish a blocked decision from a VM creation attempted and rejected (H11). |
| H5 | Client pool exhaustion | Pool errors should precede probe failures; compare configured limits, use, and backend health. A healthy backend distinguishes it from H6. |
| H6 | Dependency degradation | Correlate client failures with instance-side failover, resource limits, errors, or affected peer consumers. An instance's current READY status alone cannot exclude earlier degradation. |
| H7 | Deploy regression | Match deployment timing, changed images/configuration, pod startup failures, and endpoint loss. Without a relevant deploy, do not pursue a deployment story by default. |
| H8 | IAM/identity failure | Establish the failing API/identity and permission/token error, then correlate policy, account, key, or token events. Generic connection failures are insufficient. |
| H9 | DNS failure | Compare resolution across services and inspect CoreDNS. If CoreDNS is healthy, investigate upstream network/DNS reachability under H12. |
| H10 | CPU-related degradation | Inspect CPU/throttling evidence and latency against limits and probe timeouts. High utilization alone does not prove throttling caused failure. |

For H5/H6, inspect the dependency before attributing probe errors to probe configuration. For H6/H9/H12, establish radius, DNS health, and connectivity in that order when it helps distinguish service-specific degradation from broad network failure.

## Capacity and node-loss signals

| ID | Candidate | Discriminating evidence |
|---|---|---|
| H11 | Provider stockout | VM creation rejected for zone/resource pool capacity; distinguish quota and IP-space errors. Correlate with the autoscaler request and pending workload. |
| H12 | Network/VPC failure | Relevant firewall/route/NAT changes or CNI/IP-space exhaustion, matched to connectivity impact. Healthy dependency instances with client timeouts can point here. |
| H13 | Repair/upgrade | In-window cluster operation matched to its target and affected nodes; routine maintenance alone is not an outage cause. |
| H14 | VM deletion burst | Historical GCE deletions, including `cloudservices` actors, matched to instance identities. Determine whether maintenance or scaling explains them. |
| H15 | Node loss/NotReady/reset | Compare historical counts, node identity/age, readiness and planned operations. Removed nodes may leave no live NotReady object. |
| H16 | Delayed scale-up | Pending age and scale-up-trigger evidence, with provider stockout excluded. A current recovery does not erase historical pending latency. Max-node or no-trigger cases require H4 analysis. |
| B1 | Billing/project suspension | Correlate authoritative billing events with project/node impact. Current enabled status cannot exclude earlier suspension, and missing project logs alone cannot prove it. |

Node-creation failure (H11) and node removal (H14/H15) are different directions and may coexist. Billing, deletion, loss, repair, and pending signals can form one causal chain; verify each link instead of treating their presence as automatic confirmation. Logs inside a suspended project may be unavailable, so preserve that blind spot.

For late-reported incidents, compare the collector's symptom, change, and critical windows. Widen the relevant query when a plausible initiating event predates the collected window. Collector thresholds identify candidates; they do not replace historical reconstruction.
