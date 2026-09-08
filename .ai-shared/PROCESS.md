# Development Process

Main-session policy for application feature, fix, and refactor work. Read [CODING.md](CODING.md) and project configuration.

## Delivery

The required sequence is **design-feature → review-feature → spec approval → execute-feature → review-code → create-pr**. Exploration and goal framing are optional when the request is already clear. Architecture and infrastructure use the separate lanes in [the skill directory](skills/dev/README.md).

A phase advances when its owning skill's completion conditions hold. Mechanical gates check artifact shape and Git history; they do not establish correctness or user consent. Correct a failed prerequisite before dependent work. Continue independent authorized work.

Delegated design tasks follow CODING.md's delegation rules and the selected design skill. The subagent returns draft content and unresolved decisions; the main agent writes the artifact and handles approval. Drafting subagents do not implement, mutate Git or infrastructure, or delegate further.

## Rule owners

| Concern | Source |
|---|---|
| Plan identity, lifecycle, worktree, archive and cleanup | [plan.md](skills/dev/plan.md) |
| Plan schema and PR slicing | [design-feature.md](skills/dev/design-feature.md) |
| Approval, amendments, deviations, new scope, abandonment | [approval.md](skills/dev/approval.md) |
| Test-first proof, coverage and verification gaps | [verification.md](skills/dev/verification.md) |
| Caller and shared-state impact | [CODING.md — Impact](CODING.md#impact) |
| Review authority, isolation, and re-review | [independence.md](skills/dev/independence.md) |

## Repository conventions

Application plans and architecture documents describe outcomes, contracts, invariants, and decisions using stable symbols and language-neutral notation. Use pseudocode when the algorithm or protocol is itself the decision; leave implementation bodies to execution. Existing source may be quoted as evidence. Notation alone does not block a sound design. Infrastructure runbooks instead require runnable commands under [design-infra.md](skills/dev/design-infra.md).

Use the configured Git identity and active `gh` account. Do not invent authors, switch accounts, or inject tokens. Missing required identity or authentication blocks the affected Git operation.

Plan-bound commands use the plan's concrete `Base:` and each PR row's explicit `Parent`. For diagnosis without a plan, [dev-utils.sh](bin/dev-utils.sh) `diagnostic-base` resolves a read-only comparison base. If resolution fails, ask for the base; never pass an empty ref to Git.

Load the current phase through the platform's skill mechanism, or read its file when no skill tool exists. [ship-feature.md](skills/dev/ship-feature.md) owns resume routing.
