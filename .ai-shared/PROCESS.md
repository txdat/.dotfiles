# Development Process

Main-session policy for plan-backed feature, fix, and refactor work. Read [CODING.md](CODING.md) and project configuration.

## Scope

The application delivery sequence applies when the user asks for plan-backed work or invokes `ship-feature` or one of its phases: `design-feature`, `review-feature`, `execute-feature`, `review-code`, or `create-pr`. Other dev skills follow their own scope and routing; invoking diagnosis, exploration, goal framing, or issue capture alone does not enter this sequence. Application changes outside plan-backed delivery use [AGENTS.md — Work](AGENTS.md#work)'s direct-edit path.

Within the workflow, the phases below govern application code: executable logic or its tests, including behavior-preserving refactors and developer tooling. Classify by the changed content, not the filename: changing a shell function inside a configuration file is executable work. Documentation, agent/skill instructions, and declarative settings take the direct-edit path even inside plan-backed work; mixed changes follow this process for their executable scope. Project instructions may override these defaults for named areas. If the boundary is unclear, state the proposed classification and its reason before implementation.

## Delivery

The required sequence is **design-feature → review-feature → spec approval → execute-feature → review-code → create-pr**. Exploration and goal framing are optional when the request is already clear.

A phase advances when its owning skill's completion conditions hold. Mechanical gates check artifact shape and Git history; they do not establish correctness or user consent. Correct a failed prerequisite before dependent work. Continue independent authorized work.

Delegated design tasks follow [CODING.md — Ownership](CODING.md#ownership) and the selected design skill. The subagent returns draft content and unresolved decisions; the main agent writes the artifact and handles approval. Drafting subagents do not implement, mutate infrastructure, or delegate further.

## Repository conventions

Application plans and architecture documents describe outcomes, contracts, invariants, and decisions using stable symbols and language-neutral notation. Use pseudocode when the algorithm or protocol is itself the decision; leave implementation bodies to execution. Existing source may be quoted as evidence. Notation alone does not block a sound design. Infrastructure runbooks instead require runnable commands under [design-infra.md](skills/dev/design-infra.md).

Use the configured Git identity and active `gh` account. Do not invent authors, switch accounts, or inject tokens. Missing required identity or authentication blocks the affected Git operation.

Plan-bound commands use the plan's concrete `Base:` and each PR row's explicit `Parent`. For diagnosis without a plan, [dev-utils.sh](bin/dev-utils.sh) `diagnostic-base` resolves a read-only comparison base. If resolution fails, ask for the base; never pass an empty ref to Git.

Load each phase through the platform's skill mechanism or its documented gated path; without a mechanical gate, read the phase file and verify its prerequisites before acting. Reading a phase file for an audit is not invocation and advances no workflow state.
