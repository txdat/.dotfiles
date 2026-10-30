/** Offline collector regression tests. All cloud clients are shell-function fakes. */

import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const COLLECTOR = resolve(import.meta.dirname, "../../../bin/gke-collect.sh");

const FAKES = `
gcloud() {
  printf '%s\\n' "\${*//$'\\n'/ }" >> "$GCLOUD_CALLS"
  case "$*" in
    'container clusters list'*) printf 'asia-southeast1\\neurope-west1\\n' ;;
    'container clusters describe'*)
      case "$*" in *'value(location)'*) printf 'asia-southeast1\\n';; esac ;;
    'auth print-access-token'*) printf 'synthetic-token\\n' ;;
    'billing projects describe'*) printf 'True\\n' ;;
    'compute backend-services describe'*'value(logConfig.enable)'*)
      if [ "$SCENARIO" = lb_logging ]; then printf 'True\\n'; else printf 'False\\n'; fi ;;
    'container operations list'*)
      case "$*" in *--limit=1*) return 0;; esac
      [ "$SCENARIO" != query_failure ] ;;
    'logging read'*)
      if [ "$SCENARIO" = no_logging ]; then return 1; fi
      case "$*" in *--limit=1\\ *) return 0;; esac
      [ "$SCENARIO" != query_failure ] ;;
    'compute regions describe'*) printf 'asia-southeast1\\n' ;;
    *) return 0 ;;
  esac
}
kubectl() {
  case "\${1:-}" in --context=*) shift;; esac
  case "$*" in
    'config current-context')
      if [ "$SCENARIO" = wrong_context ]; then
        printf 'gke_other-project_europe-west1_prod\\n'
      else
        printf 'gke_test-project_asia-southeast1_prod\\n'
      fi ;;
    cluster-info*) return 0 ;;
    *)
      printf '%s\\n' "$*" >> "$KUBE_CALLS"
      if [ "$SCENARIO" = query_failure ]; then return 1; fi
      case "$*" in
        'get deployment api '*'-o json')
          printf '%s\\n' '{"spec":{"selector":{"matchLabels":{"app":"api"}},"template":{"spec":{"containers":[{"name":"api","env":[{"name":"DB_POOL_SIZE","value":"12"},{"name":"DATABASE_URL","value":"host=db password=synthetic-secret"},{"name":"DATABASE_DSN","value":"sqlserver://db;password=synthetic-secret"},{"name":"POOL_TOKEN","value":"synthetic-secret"}]}]}}}}' ;;
        'get deployment api '*jsonpath*)
          case "$*" in
            *'.env[*]'*) printf 'DB_POOL_SIZE = 12\\nDATABASE_URL = host=db password=synthetic-secret\\nDATABASE_DSN = sqlserver://db;password=synthetic-secret\\nPOOL_TOKEN = synthetic-secret\\n';;
          esac ;;
        *'-o json') printf '{"items":[]}\\n' ;;
        *) return 0 ;;
      esac ;;
  esac
}
curl() {
  case "$*" in
    *metricDescriptors*) printf '{}\\n' ;;
    *timeSeries*)
      case "$*" in
        *'/internal/'*)
          if [ "$SCENARIO" = partial_metric ]; then
            printf '{"error":{"message":"internal metric unavailable"}}\\n'
          else
            printf '{}\\n'
          fi ;;
        *)
          metric='{"timeSeries":[{"resource":{"labels":{"backend_target_name":"backend-a","forwarding_rule_name":"rule-a"}},"metric":{"labels":{"response_code":"200"}},"points":[{"interval":{"endTime":"2026-09-08T00:01:00Z"},"value":{"int64Value":"100"}}]}]'
          if [ "$SCENARIO" = truncated_metric ]; then metric="$metric,\\"nextPageToken\\":\\"more\\""; fi
          printf '%s}\\n' "$metric" ;;
      esac ;;
    *) return 1 ;;
  esac
}
export -f gcloud kubectl curl
bash "$1"
`;

type Collection = { report: string; kubeCalls: string; gcloudCalls: string };

function readText(path: string): string {
  return existsSync(path) ? readFileSync(path, "utf8") : "";
}

function collect(scenario: string): Collection {
  const directory = mkdtempSync(join(tmpdir(), "gke-collect-test-"));
  try {
    const report = join(directory, "report.txt");
    const calls = join(directory, "kubectl.txt");
    const gcloudCalls = join(directory, "gcloud.txt");
    const result = spawnSync("bash", ["-c", FAKES, "test", COLLECTOR], {
      env: {
        PATH: process.env.PATH ?? "",
        SCENARIO: scenario,
        PROJECT: "test-project",
        CLUSTER: "prod",
        REGION: "asia-southeast1",
        NAMESPACE: "app",
        SERVICES: "api",
        T_USER: "2026-09-08 07:00:00",
        T_DURATION: "10m",
        LB_BACKEND_NAME: "backend-a",
        REPORT: report,
        KUBE_CALLS: calls,
        GCLOUD_CALLS: gcloudCalls,
      },
      encoding: "utf8",
      timeout: 45_000,
    });
    assert.equal(result.status, 0, result.stderr);
    return {
      report: readText(report),
      kubeCalls: readText(calls),
      gcloudCalls: readText(gcloudCalls),
    };
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
}

function includes(report: string, text: string): void {
  assert.ok(report.includes(text), `Missing report evidence: ${text}`);
}

function excludes(report: string, text: string): void {
  assert.ok(!report.includes(text), `Unexpected report evidence: ${text}`);
}

function lines(text: string): string[] {
  return text.split("\n");
}

test("healthy sources can report clear", () => {
  const { report } = collect("healthy");
  includes(report, "CAP_K8S=1");
  includes(report, "[VERDICT: CLEAR] H14:");
  includes(report, "[VERDICT: CLEAR] G1:");
});

test("other project context cannot supply evidence", () => {
  const { report, kubeCalls } = collect("wrong_context");
  includes(report, "CAP_K8S=0");
  assert.equal(kubeCalls, "", "Resource reads reached the unrelated cluster");
});

test("query failure after preflight stays unknown", async (t) => {
  const { report } = collect("query_failure");
  for (const hypothesis of ["B1", "H13", "H14", "H15", "H11", "H16"]) {
    await t.test(hypothesis, () => {
      includes(report, `[VERDICT: UNKNOWN] ${hypothesis}:`);
      excludes(report, `[VERDICT: CLEAR] ${hypothesis}:`);
    });
  }
});

test("metric failure is not hidden by other metric", () => {
  const { report } = collect("partial_metric");
  includes(report, "internal metric unavailable");
  includes(report, "[VERDICT: UNKNOWN] G1:");
  excludes(report, "[VERDICT: CLEAR] G1:");
});

test("truncated metric cannot report clear", () => {
  const { report } = collect("truncated_metric");
  includes(report, "[VERDICT: UNKNOWN] G1:");
  excludes(report, "[VERDICT: CLEAR] G1:");
});

test("only numeric pool settings are collected", () => {
  const { report } = collect("healthy");
  excludes(report, "synthetic-secret");
  includes(report, "DB_POOL_SIZE = 12");
});

test("lb sections tagged for g1 and deduplicated", async (t) => {
  const { report, gcloudCalls } = collect("lb_logging");
  for (const prefix of ["1d.1", "1d.2m", "1d.2a", "1d.2b", "1d.3", "1d.4", "1d.5", "1h.5"]) {
    await t.test(prefix, () => {
      const matching = lines(report).filter((line) => line.startsWith(`===== ${prefix} `));
      assert.equal(matching.length, 1, "expected exactly one section");
      assert.ok(matching[0].includes("G1"), "missing G1 tag");
    });
  }
  const lbLogReads = lines(gcloudCalls).filter((line) =>
    line.includes('resource.type="http_load_balancer"'),
  );
  assert.equal(lbLogReads.length, 2, "Expected 1 5xx read and 1 sample read");
});

test("unreadable logging short circuits log queries", () => {
  const { report, gcloudCalls } = collect("no_logging");
  includes(report, "CAP_LOGGING=0");
  const logReads = lines(gcloudCalls).filter((line) => line.startsWith("logging read "));
  assert.equal(
    logReads.length,
    1,
    "Only preflight logging read should execute when CAP_LOGGING=0",
  );
});

test("cluster ops and k8s snapshots cached and scoped", () => {
  const { kubeCalls, gcloudCalls } = collect("healthy");
  const deployReads = lines(kubeCalls).filter((line) =>
    line.startsWith("get deployment api "),
  );
  assert.equal(deployReads.length, 1);
  const opsReads = lines(gcloudCalls).filter((line) =>
    line.startsWith("container operations list "),
  );
  assert.equal(opsReads.length, 2, "Expected 1 preflight and 1 cached operations read");
  const k8sClusterReads = lines(gcloudCalls).filter((line) =>
    line.includes('resource.type="k8s_cluster"'),
  );
  assert.ok(k8sClusterReads.length > 0);
  for (const line of k8sClusterReads) {
    assert.ok(line.includes('resource.labels.cluster_name="prod"'), line);
  }
});
