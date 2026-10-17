# Review Authority and Independence

A review-only request returns findings without edits. Authorized delivery or revision-and-verification includes in-scope repair and re-review; design choices go to the user. Write review prose under [language.md](language.md).

An explicitly requested code audit without a plan reviews the supplied scope and reports located findings with failure mechanism, consequence, and verification limits; it invents no plan or phase transition.

## Reviewer

If this session authored the artifact, delegate the whole review to a fresh general-purpose subagent without inherited conversation when available; invoking a review skill, or a delivery workflow that includes one, requests that subagent. This keeps the reviewer from adopting the author's reasoning. Use the reviewing skill's model and effort from [README.md — skills](../../README.md#skills) through [model mapping](../../README.md#model-mapping); a `—` model inherits the default. Where the platform cannot set effort, disclose that the reviewer ran at the default. Report the reviewer's model; a weaker model than the author's is an accepted cost, not an isolation failure. Supply only [CODING.md](../../CODING.md), the artifact path (or the audit scope), project configuration, the reviewing skill, necessary worktree/base refs, and, for a re-review, the prior findings and the items a revision changed. If isolation is unavailable, review directly and disclose it. A session that did not author the artifact reviews directly.

The reviewer applies the supplied criteria, spawns nothing, and returns findings and a verdict. It may inspect sources and Git and run local verification, but must not edit source or artifacts, mutate Git, change status, or perform external mutations; tests may create normal disposable output. The main agent owns fixes and artifact updates during authorized delivery.

## Re-review

Round 1 reviews the whole artifact in depth. A re-review is scoped to the prior findings, which the main agent supplies, or to the items a [plan revision](plan.md#changes) changed: verify each repair or revision and what it affects, and report regressions. It reopens nothing else; a blocking defect found elsewhere is still reported, naming why round 1 missed it. Reuse prior evidence only when its revision and verification inputs remain applicable; a previous verdict alone is insufficient. Findings live in the review report, not the artifact; across sessions, the open findings and the re-review count travel in a [handoff](../handoff.md).

Allow at most two re-reviews per artifact and review phase, each after a batch of repairs; rounds the user requests count too. If blocking findings remain after the second, report them without recommending another round, and offer the user's choices: narrow or split the artifact's goal, decide specific findings and revise, or grant further rounds. A confirmed split starts a new count for each resulting artifact. Stop earlier for an unresolved decision or under [AGENTS.md](../../AGENTS.md)'s failed-fix rule. Optional notes do not block readiness.
