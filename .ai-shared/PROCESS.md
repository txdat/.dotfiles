# Development Process

Main-session policy for plan-backed feature, fix, and refactor work. Read [CODING.md](CODING.md) and project configuration.

## Scope

This process applies only when a dev skill is invoked or the user asks for plan-backed work. Everything else, including application code, uses [AGENTS.md — Work](AGENTS.md#work)'s direct-edit path.

Within the workflow, the phases below govern application code: executable logic or its tests, including behavior-preserving refactors and developer tooling. Classify by the changed content, not the filename: changing a shell function inside a configuration file is executable work. Documentation, agent/skill instructions, and declarative settings take the direct-edit path even inside plan-backed work; mixed changes follow this process for their executable scope. Project instructions may override these defaults for named areas. If the boundary is unclear, state the proposed classification and its reason before implementation.

## Delivery

The required sequence is **design-feature → review-feature → spec approval → execute-feature → review-code → create-pr**. Exploration and goal framing are optional when the request is already clear. A documentation-only API-contract sub-plan stops at spec approval and ships with its consumer's publication ([design-feature.md — Split scope](skills/dev/design-feature.md#split-scope-before-splitting-work)). Architecture and infrastructure use the separate lanes in [the skill directory](skills/dev/README.md).

A phase advances when its owning skill's completion conditions hold. Mechanical gates check artifact shape and Git history; they do not establish correctness or user consent. Correct a failed prerequisite before dependent work. Continue independent authorized work.

Delegated design tasks follow [CODING.md — Ownership](CODING.md#ownership) and the selected design skill. The subagent returns draft content and unresolved decisions; the main agent writes the artifact and handles approval. Drafting subagents do not implement, mutate Git or infrastructure, or delegate further.

## Rule owners

| Concern | Source |
|---|---|
| Workflow entry, application-code boundary, and delivery sequence | [Scope](#scope) and [Delivery](#delivery) |
| Plan identity, lifecycle, worktree, archive and cleanup | [plan.md](skills/dev/plan.md) |
| Plan schema and PR slicing | [design-feature.md](skills/dev/design-feature.md) |
| Plan/PR and review-output language | [language.md](skills/dev/language.md) |
| Approval, amendments, deviations, new scope, abandonment | [approval.md](skills/dev/approval.md) |
| Test-first proof and commit conventions, coverage and verification gaps | [verification.md](skills/dev/verification.md) |
| Archive and live-plan cleanup commit conventions | [plan.md — Archive and cleanup](skills/dev/plan.md#archive-and-cleanup) |
| CI boundary after any commit push | [AGENTS.md — Work](AGENTS.md#work) |
| Publication completion | [create-pr.md — Complete](skills/dev/create-pr.md#complete) |
| Caller and shared-state impact | [CODING.md — Impact](CODING.md#impact) |
| Failed-fix budget and no-progress rule | [AGENTS.md — Work](AGENTS.md#work) |
| Review authority, isolation, repair/re-review budget and renewal | [independence.md](skills/dev/independence.md) |

## Repository conventions

Application plans and architecture documents describe outcomes, contracts, invariants, and decisions using stable symbols and language-neutral notation. Use pseudocode when the algorithm or protocol is itself the decision; leave implementation bodies to execution. Existing source may be quoted as evidence. Notation alone does not block a sound design. Infrastructure runbooks instead require runnable commands under [design-infra.md](skills/dev/design-infra.md).

Use the configured Git identity and active `gh` account. Do not invent authors, switch accounts, or inject tokens. Missing required identity or authentication blocks the affected Git operation.

Plan-bound commands use the plan's concrete `Base:` and each PR row's explicit `Parent`. For diagnosis without a plan, [dev-utils.sh](bin/dev-utils.sh) `diagnostic-base` resolves a read-only comparison base. If resolution fails, ask for the base; never pass an empty ref to Git.

Load the current phase through the platform's skill mechanism, or its documented gated load path when no skill tool exists; platform setup owns that path and its enforcement limits. Where no mechanical gate is available, read the phase file and verify its prerequisites explicitly before acting. Reading instructions for an audit is documentation inspection, not phase invocation, and does not advance workflow state. A read alone never establishes readiness or authorization. [ship-feature.md](skills/dev/ship-feature.md) owns resume routing.
