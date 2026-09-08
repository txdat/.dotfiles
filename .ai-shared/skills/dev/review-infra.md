# /review-infra — Review a Runbook

Read the exact `docs/runbooks/<file>.md`, [design-infra.md](design-infra.md)'s lane and runbook requirements, project configuration, and [independence.md](independence.md). Use read-only checks throughout.

## Before execution

Validate material runbook claims against current workloads, images, network/DNS, data, IaC, and CI/CD state as applicable. Keep a compact evidence map:

`Claim / expected state | Live observation | Source / command / time | Verdict | Consequence / affected phase`

Use `MATCH` for corroborated claims, `MISMATCH` for differing values, `MISSING` for an expected resource absent from live state, `EXTRA` for relevant unaccounted live resources, and `STALE` for observations requiring revalidation. Use `UNVERIFIED` when access or evidence is insufficient; failed collection does not prove absence. Include both expected and observed values, and connect discrepancies to their execution consequence.

Check the applicable resource and phase requirements in [design-infra.md — Runbook](design-infra.md#runbook) against this evidence. In particular, inspect source/target coexistence and duplicate processing, traffic dependencies, and whether rollback resources remain usable through their promised window. Check that gates have observable pass/stop conditions and precede the actions they protect, including destruction. Missing evidence that affects execution safety blocks readiness; formatting preferences do not.

Return `READY` or `NEEDS CHANGES` with severity-ranked findings and decisive command evidence. During authorized runbook delivery, the main agent appends `## Review History` and sets `Review: READY <date>` only for a passing review; revisions invalidate that marker until re-reviewed. A standalone review returns findings without editing the artifact.

## Post-execution audit

Use `post` only when the human confirms what ran. Establish executed phases from their report and available execution evidence; the runbook itself is not proof of execution.

Check each Success criterion, remaining resources, divergence, and prerequisites for unfinished phases. For irreversible actions, determine whether their gates held before execution; current health cannot prove that historical fact. Report unverifiable evidence explicitly.

Choose the first applicable verdict: `UNSAFE` for breached destructive gates or present risk; `DIVERGED` for an unplanned end state; `INCOMPLETE` for remaining work or missing verification; otherwise `COMPLETE`.

During authorized record updates, append the evidence to `## Execution Record`: what ran, gate outcomes, divergence, residue, and remaining work. Preserve earlier entries. Set `Status: executed` only for COMPLETE; otherwise leave draft, or return an outdated executed record to draft with the reason. Abandonment requires a human decision. Report the human's next action; this audit does not execute or remediate it.
