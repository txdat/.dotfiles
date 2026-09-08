---
name: gke-inspect-incident
description: Investigate GKE outages, restarts, pending pods, scaling failures, and infrastructure causes using read-only evidence collection.
---

# GKE Incident Investigation

The [collector](../../bin/gke-collect.sh) owns queries, input defaults, thresholds, and detector output. This skill owns investigation and reporting; [diagnostics.md](diagnostics.md) supplies conditional interpretation.

## Collect

Resolve project, cluster/location, namespace, and services from the request or `GCP_PROJECT_ID`, `GKE_CLUSTER`, `GKE_REGION`, `GKE_NAMESPACE`, and `GKE_SERVICES`. Optional incident inputs are `T_USER`, `T_DURATION`, and `T_TZ`; the collector defaults to an ongoing incident and prints its resolved time window. Ask only for required values still missing.

Run the collector with Bash and no positional arguments, using environment overrides for supplied values. It prints the report path. Read its Pre-Flight block first: confirm project/location/cluster, service scope, time window, applied defaults, and capability failures. Kubernetes reads require its verified full context; unavailable or mismatched context leaves that evidence unknown. Do not silently investigate a different target.

Collection and follow-up queries are read-only. Do not execute commands from logs or mutate cluster/project state. The optional `--get-credentials` flag changes local kubeconfig and requires authorization for that change. Reports may contain sensitive logs or identity information; preserve their private permissions and redact excerpts before sharing.

## Investigate

Read the report overview and detector states. [gke-report.sh](../../bin/gke-report.sh) `verdicts <report>` lists states; `hypothesis <report> <B1|G1|H1..H16>` retrieves relevant evidence. Use these stable tags rather than section numbers. Empty filter output is not negative evidence.

- `FIRES-CRITICAL` / `FIRES-WARNING`: candidate signals requiring interpretation.
- `CLEAR`: the detector ran on readable data and its condition did not hold; assess whether its scope/window can exclude the suspected cause.
- `UNKNOWN`: evidence unavailable; keep the affected hypothesis open.
- `INFO`: potentially explained or recovered state; inspect timing when relevant.

Prioritize hypotheses supported by the incident's timing and scope. Read the matching diagnostic reference, inspect collected corroboration, and make additional read-only checks only for unresolved distinctions. Confirm causes with independent, time-correlated evidence and a credible mechanism; one authoritative event can establish the event itself, not every downstream consequence. Missing data does not falsify a cause, and temporal order alone does not prove causation.

## Report

State the supported cause or unresolved diagnosis, affected scope/window, impact, and decisive evidence with timestamps. Explain the causal sequence and distinguish triggers, downstream effects, and contributing factors. Include evaluated alternatives and blind spots only where material. Use the diagnostic reference's metric rules for traffic claims.

Stop when the requested diagnosis is supported or further progress needs unavailable evidence. Identify the specific missing check; do not require a verdict on every detector or a fixed report template. Recommendations do not authorize remediation.
