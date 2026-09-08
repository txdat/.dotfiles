# /design-infra — Infrastructure Runbook

Use for migrations, deployments, DNS/IaC/database operations, and maintenance within established boundaries. Architecture changes use [design-system.md](design-system.md); application changes use their own feature plan.

## Lane and authority

This lane is **design → review → human execution → optional post-execution review**. It produces a runbook and uses read-only live-state checks; it does not execute infrastructure mutations. Review readiness is a handoff to the human executor. No application worktree or application-plan lifecycle applies.

Write `docs/runbooks/<date>_<slug>.md` with `Status: draft | Date: <date> | Issue: #N | Review:`. Link the supplied tracking issue or create one under [PROCESS.md](../../PROCESS.md)'s Git conventions.

## Runbook

Record the source, target, constraints, and measurable success criteria with read-only verification commands. Inspect live state relevant to the operation. For each material claim, record its value, source/command, observation time, and status: verified, assumed, or requiring revalidation before execution. Assumptions need a verification action and a gate before any phase relies on them; changing live state may invalidate earlier evidence.

Account for affected workloads and resources: move, already moved/drain only, or leave untouched. Capture exact images/digests, configuration references, probes, resources, and companion processes where applicable. Do not include secret values.

Use this compact structure for each phase; reference shared evidence and commands rather than duplicating them:

```text
Phase <N> — <outcome>
Prerequisites: <dependencies, required state and evidence>
Commands: <runnable commands with explicit targets and resolved inputs>
Verification / gate: <read-only checks, expected results, stop condition>
Rollback / recovery: <trigger, concrete commands, prerequisites and limits>
Time window: <expected duration and rollback deadline or limiting event>
```

Mark irreversible actions and their containment/recovery requirements; do not promise rollback after its prerequisites are destroyed. Order dependencies so backups/baselines precede mutation, healthy replacements precede traffic cutover and drain, and gated destruction comes last. Preserve the rollback target until cutover is verified.

For the affected paths, check source/target coexistence and duplicate processing, pinned image versions and companion processes, dependent resources, DNS/traffic mappings and propagation, IaC resource/file changes and plan review, and CI/CD workload placement. Include the relevant evidence in the phase that uses it. A destruction phase must account for dependencies, deletion protection, backups, and explicit human confirmation.

Record unresolved questions with the phases they block. Finish when the proposed operation is concrete and reviewable; hand off to [review-infra.md](review-infra.md). The main agent adds review/execution history when those events occur, preserving the evidence.
