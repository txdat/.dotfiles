# /review-infra — Review a Runbook

Review the exact `docs/runbooks/<file>.md` independently under [plan.md — Review](plan.md#review), against [design-infra.md](design-infra.md), using read-only checks only.

## Before execution

Validate each `CL-n` claim and `RS-n` resource against live workloads, images, network and DNS, data, IaC, and CI/CD state. Keep an evidence map:

`Claim / expected state | Live observation | Source, command, time | MATCH, MISMATCH, MISSING, EXTRA, STALE, or UNVERIFIED | Affected PH-n`

Failed collection is `UNVERIFIED`, never proof of absence. Check the phases against design-infra's ordering and gate rules, especially coexistence and duplicate processing, traffic dependencies, and whether rollback resources survive their promised window. Gates need observable pass and stop conditions: a phase's Prerequisites gate its Commands, and its Verification gates the next phase. Missing evidence that affects execution safety blocks.

Return `READY` or `NEEDS CHANGES` with findings ranked by severity and the decisive command evidence. During authorized runbook work, the main agent sets `Review: READY <date>` for a passing review; any revision clears it until re-reviewed.

## After execution

Run only when the human confirms what ran; the runbook is not proof of execution. Check each `SC-n`, remaining `RS-n`, divergence from the plan, and prerequisites of unfinished phases. For irreversible actions, determine whether their gates held beforehand; current health cannot prove that. Report what you cannot verify.

Return the content of an `EX-n` entry: phases run, gate outcomes, divergence, residue, remaining work, and whether every criterion holds with no work remaining. When authorized, the main agent appends it to `## Execution Record`, and sets `Status: executed` only when every criterion holds and no work remains. Report the human's next action; this audit never executes or remediates.
