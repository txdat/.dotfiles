#!/usr/bin/env python3
"""Offline collector regression tests. All cloud clients are shell-function fakes."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


COLLECTOR = Path(__file__).resolve().parents[3] / "bin" / "gke-collect.sh"
FAKES = r'''
gcloud() {
  case "$*" in
    'container clusters list'*) printf 'asia-southeast1\neurope-west1\n' ;;
    'container clusters describe'*)
      case "$*" in *'value(location)'*) printf 'asia-southeast1\n';; esac ;;
    'auth print-access-token'*) printf 'synthetic-token\n' ;;
    'billing projects describe'*) printf 'True\n' ;;
    'container operations list'*)
      case "$*" in *--limit=1*) return 0;; esac
      [ "$SCENARIO" != query_failure ] ;;
    'logging read'*)
      case "$*" in *--limit=1\ *) return 0;; esac
      [ "$SCENARIO" != query_failure ] ;;
    'compute regions describe'*) printf 'asia-southeast1\n' ;;
    *) return 0 ;;
  esac
}
kubectl() {
  case "${1:-}" in --context=*) shift;; esac
  case "$*" in
    'config current-context')
      if [ "$SCENARIO" = wrong_context ]; then
        printf 'gke_other-project_europe-west1_prod\n'
      else
        printf 'gke_test-project_asia-southeast1_prod\n'
      fi ;;
    cluster-info*) return 0 ;;
    *)
      printf '%s\n' "$*" >> "$KUBE_CALLS"
      if [ "$SCENARIO" = query_failure ]; then return 1; fi
      case "$*" in
        'get deployment api '*'-o json')
          printf '%s\n' '{"spec":{"selector":{"matchLabels":{"app":"api"}},"template":{"spec":{"containers":[{"name":"api","env":[{"name":"DB_POOL_SIZE","value":"12"},{"name":"DATABASE_URL","value":"host=db password=synthetic-secret"},{"name":"DATABASE_DSN","value":"sqlserver://db;password=synthetic-secret"},{"name":"POOL_TOKEN","value":"synthetic-secret"}]}]}}}}' ;;
        'get deployment api '*jsonpath*)
          case "$*" in
            *'.env[*]'*) printf 'DB_POOL_SIZE = 12\nDATABASE_URL = host=db password=synthetic-secret\nDATABASE_DSN = sqlserver://db;password=synthetic-secret\nPOOL_TOKEN = synthetic-secret\n';;
          esac ;;
        *'-o json') printf '{"items":[]}\n' ;;
        *) return 0 ;;
      esac ;;
  esac
}
curl() {
  case "$*" in
    *metricDescriptors*) printf '{}\n' ;;
    *timeSeries*)
      case "$*" in
        *'/internal/'*)
          if [ "$SCENARIO" = partial_metric ]; then
            printf '{"error":{"message":"internal metric unavailable"}}\n'
          else
            printf '{}\n'
          fi ;;
        *)
          metric='{"timeSeries":[{"resource":{"labels":{"backend_target_name":"backend-a","forwarding_rule_name":"rule-a"}},"metric":{"labels":{"response_code":"200"}},"points":[{"interval":{"endTime":"2026-09-08T00:01:00Z"},"value":{"int64Value":"100"}}]}]'
          if [ "$SCENARIO" = truncated_metric ]; then metric="$metric,\"nextPageToken\":\"more\""; fi
          printf '%s}\n' "$metric" ;;
      esac ;;
    *) return 1 ;;
  esac
}
export -f gcloud kubectl curl
bash "$1"
'''


class CollectorTest(unittest.TestCase):
    def includes(self, report, text):
        self.assertTrue(text in report, f"Missing report evidence: {text}")

    def excludes(self, report, text):
        self.assertFalse(text in report, f"Unexpected report evidence: {text}")

    def collect(self, scenario):
        with tempfile.TemporaryDirectory(prefix="gke-collect-test-") as directory:
            report = Path(directory) / "report.txt"
            calls = Path(directory) / "kubectl.txt"
            env = {
                "PATH": os.environ["PATH"],
                "SCENARIO": scenario,
                "PROJECT": "test-project",
                "CLUSTER": "prod",
                "REGION": "asia-southeast1",
                "NAMESPACE": "app",
                "SERVICES": "api",
                "T_USER": "2026-09-08 07:00:00",
                "T_DURATION": "10m",
                "LB_BACKEND_NAME": "backend-a",
                "REPORT": str(report),
                "KUBE_CALLS": str(calls),
            }
            result = subprocess.run(
                ["bash", "-c", FAKES, "test", str(COLLECTOR)],
                env=env, capture_output=True, text=True, timeout=45,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            return report.read_text(), calls.read_text() if calls.exists() else ""

    def test_healthy_sources_can_report_clear(self):
        report, _ = self.collect("healthy")
        self.includes(report, "CAP_K8S=1")
        self.includes(report, "[VERDICT: CLEAR] H14:")
        self.includes(report, "[VERDICT: CLEAR] G1:")

    def test_other_project_context_cannot_supply_evidence(self):
        report, calls = self.collect("wrong_context")
        self.includes(report, "CAP_K8S=0")
        self.assertEqual(calls, "", "Resource reads reached the unrelated cluster")

    def test_query_failure_after_preflight_stays_unknown(self):
        report, _ = self.collect("query_failure")
        for hypothesis in ("B1", "H13", "H14", "H15", "H11", "H16"):
            with self.subTest(hypothesis=hypothesis):
                self.includes(report, f"[VERDICT: UNKNOWN] {hypothesis}:")
                self.excludes(report, f"[VERDICT: CLEAR] {hypothesis}:")

    def test_metric_failure_is_not_hidden_by_other_metric(self):
        report, _ = self.collect("partial_metric")
        self.includes(report, "internal metric unavailable")
        self.includes(report, "[VERDICT: UNKNOWN] G1:")
        self.excludes(report, "[VERDICT: CLEAR] G1:")

    def test_truncated_metric_cannot_report_clear(self):
        report, _ = self.collect("truncated_metric")
        self.includes(report, "[VERDICT: UNKNOWN] G1:")
        self.excludes(report, "[VERDICT: CLEAR] G1:")

    def test_only_numeric_pool_settings_are_collected(self):
        report, _ = self.collect("healthy")
        self.excludes(report, "synthetic-secret")
        self.includes(report, "DB_POOL_SIZE = 12")


if __name__ == "__main__":
    unittest.main()
