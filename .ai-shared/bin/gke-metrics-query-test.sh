#!/usr/bin/env bash
# Offline smoke tests for template output and argument validation.
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
helper="$script_dir/gke-metrics-query.sh"
test_dir=$(mktemp -d -t gke-metrics-query-test.XXXXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
mkdir "$test_dir/bin"
ln -s "$(command -v cat)" "$test_dir/bin/cat"
bash_path=$(command -v bash)

run_helper() {
  PATH="$test_dir/bin" "$bash_path" "$helper" "$@"
}

container=$(run_helper container)
redis=$(run_helper redis)
[[ "$container" == 'fetch k8s_container'* ]]
[[ "$container" == *"resource.cluster_name == 'CLUSTER'"* ]]
[[ "$container" == *"resource.namespace_name == 'NAMESPACE'"* ]]
[[ "$container" == *"resource.pod_name =~ 'SERVICE.*'"* ]]
[[ "$container" == *'memory/limit_utilization'* && "$container" == *'cpu/limit_utilization'* ]]
[[ "$container" == *'>0.85 in the 5min before crash'* && "$container" == *'>0.8 sustained'* ]]
[[ "$redis" == 'fetch redis_instance'* ]]
[[ "$redis" == *'redis.googleapis.com/stats/memory/usage_ratio'* ]]
[[ "$redis" == *'>0.9'* && "$redis" == *'stats/reject_connections_count'* ]]
[[ "$redis" == *"resource.instance_id =~ '.*'"* ]]
for template in "$container" "$redis"; do
  [[ "$template" == *"within(30m, d'INCIDENT_TIME_UTC') | every 1m" ]]
done
run_helper --help > "$test_dir/help"
[[ -s "$test_dir/help" ]]
for mode in missing unknown extra; do
  args=()
  case "$mode" in unknown) args=(unknown);; extra) args=(container extra);; esac
  status=0
  run_helper "${args[@]}" > "$test_dir/out" 2> "$test_dir/err" || status=$?
  [[ "$status" == 2 && ! -s "$test_dir/out" && -s "$test_dir/err" ]]
done
printf 'PASS: manual MQL templates, validation, and offline execution\n'
