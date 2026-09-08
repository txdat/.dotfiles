# Review Authority and Independence

A review-only request returns findings without edits. Authorized delivery or revision-and-verification includes in-scope repair and re-review; material decisions follow [approval.md](approval.md).

## Reviewer

If this session authored the artifact, delegate one whole review to a fresh general-purpose subagent without inherited conversation when available. Supply only [CODING.md](../../CODING.md), the artifact path, project configuration, reviewing skill, and necessary worktree/base refs. For an ad-hoc audit, supply the requested scope instead of a plan or phase skill. If isolation is unavailable, review directly from artifacts and disclose that limitation. A session that did not author the artifact reviews directly.

The reviewer applies the supplied review criteria, spawns nothing, and returns findings and a verdict. It may inspect sources and Git and run local verification, but must not edit source/artifacts, mutate Git, change status, or perform external mutations. Tests may create normal disposable output. The main agent owns fixes and artifact updates during authorized delivery; a standalone review leaves artifacts unchanged.

## Re-review

Verify changed behavior and affected dependencies, and check the revised artifact for inconsistencies. Reuse prior evidence only when its revision and verification inputs remain applicable; a previous verdict alone is insufficient. Preserve material findings, their disposition, and pass counts in `## Review History` when the artifact supports it and updates are authorized; otherwise use the review report.

Allow at most two automatic repair/re-review passes per artifact and lifecycle review phase; each pass is a batch of repairs followed by independent review, excluding the initial review. For ad-hoc work, the named review scope is the artifact and its unresolved review is one phase. Record `Repair pass: 1/2` or `2/2` with changes and verification, preserving the count through finding changes, amendments, reviewer changes, and handoffs while the review remains unresolved. After pass 2, proceed if readiness criteria hold; otherwise report blocking findings and pause further repairs until explicit user direction grants two further passes (unless otherwise specified), retaining earlier history.

Stop earlier for an unresolved decision or under [AGENTS.md](../../AGENTS.md)'s failed-fix and no-progress rules; renewing one budget does not renew the other unless the user's direction covers both. Optional notes do not block readiness, and exhaustion never means a pass.
