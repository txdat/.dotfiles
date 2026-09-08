#!/usr/bin/env bash
# Print the manual MQL templates; no query is executed by this helper.
set -euo pipefail

if [[ $# != 1 ]]; then
  printf 'gke-metrics-query.sh: expected container, redis, or --help\n' >&2
  exit 2
fi
case "$1" in
  --help)
    printf '%s\n' \
      'Usage: bash gke-metrics-query.sh container|redis|--help' \
      'Print an MQL template for manual use in Cloud Console Metrics Explorer.' \
      'Replace CLUSTER, NAMESPACE, SERVICE, and INCIDENT_TIME_UTC where present.' \
      'No cloud requests or local file writes are performed.'
    ;;
  container)
    cat <<'MQL'
fetch k8s_container
| metric 'kubernetes.io/container/memory/limit_utilization'   # H1: >0.85 in the 5min before crash
    -- H10: swap for 'kubernetes.io/container/cpu/limit_utilization', >0.8 sustained
| filter resource.cluster_name == 'CLUSTER' && resource.namespace_name == 'NAMESPACE'
     && resource.pod_name =~ 'SERVICE.*'
| within(30m, d'INCIDENT_TIME_UTC') | every 1m
MQL
    ;;
  redis)
    cat <<'MQL'
fetch redis_instance                                          # H6
| metric 'redis.googleapis.com/stats/memory/usage_ratio'      # >0.9 → evictions, writes OOM-rejected
    -- also: clients/connected, clients/blocked, stats/reject_connections_count (maxclients),
    --       stats/evicted_keys, stats/cpu_utilization, replication/master_slave_lag
| filter resource.instance_id =~ '.*' | within(30m, d'INCIDENT_TIME_UTC') | every 1m
MQL
    ;;
  *)
    printf 'gke-metrics-query.sh: unknown template: %s\n' "$1" >&2
    exit 2
    ;;
esac
