# Review Authority and Independence

A review-only request returns findings without edits. Authorized delivery or revision-and-verification includes in-scope repair and re-review; material decisions follow [approval.md](approval.md). Write review prose under [language.md](language.md).

An explicitly requested code audit without a plan reviews the supplied scope and reports located findings with failure mechanism, consequence, and verification limits; it invents no plan or phase transition.

## Reviewer

If this session authored the artifact, delegate the whole review to a fresh general-purpose subagent without inherited conversation when available; invoking a review skill, or a delivery workflow that includes one, requests that subagent. This keeps the reviewer from adopting the author's reasoning. Use the reviewing skill's model and effort from [README.md — skills](../../README.md#skills) through [model mapping](../../README.md#model-mapping); a `—` model inherits the default. Where the platform cannot set effort, disclose that the reviewer ran at the default. Report the reviewer's model; a weaker model than the author's is an accepted cost, not an isolation failure. Supply only [CODING.md](../../CODING.md), the artifact path (or the audit scope), project configuration, the reviewing skill, and necessary worktree/base refs. If isolation is unavailable, review directly and disclose it. A session that did not author the artifact reviews directly.

The reviewer applies the supplied criteria, spawns nothing, and returns findings and a verdict. It may inspect sources and Git and run local verification, but must not edit source or artifacts, mutate Git, change status, or perform external mutations; tests may create normal disposable output. The main agent owns fixes and artifact updates during authorized delivery.

## Re-review

Verify changed behavior and affected dependencies, and check the revised artifact for inconsistencies. Reuse prior evidence only when its revision and verification inputs remain applicable; a previous verdict alone is insufficient. Preserve material findings, their disposition, and pass counts in `## Review History` when the artifact supports it and updates are authorized; otherwise use the review report.

Allow at most two automatic repair/re-review passes per artifact and lifecycle review phase; each pass is a batch of repairs followed by independent review, excluding the initial review. For ad-hoc work, the named review scope is the artifact and its unresolved review is one phase. Record `Repair pass: 1/2` or `2/2` with changes and verification, preserving the count through finding changes, amendments, reviewer changes, and handoffs while the review remains unresolved. After pass 2, proceed if readiness criteria hold; otherwise report blocking findings and pause further repairs until the user grants two further passes, retaining earlier history.

Stop earlier for an unresolved decision or under [AGENTS.md](../../AGENTS.md)'s failed-fix and no-progress rules. The failed-fix counter is independent of this repair counter: both apply during review loops, stop when either is exhausted, and renewing one does not renew the other unless the user's direction covers both. Optional notes do not block readiness, and exhaustion never means a pass.
