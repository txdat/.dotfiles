# /frame-goal — Clarify the Goal

Use when a requirement is ambiguous or bundles independently useful outcomes. A clear, coherent request goes directly to its design lane.

Preserve the user's intended outcome and explicit constraints. Inspect relevant context, identify material competing interpretations, and propose a split only when the outcomes can be accepted and delivered separately. Large scope alone is not a split boundary.

Look for candidate boundaries in user capabilities, independently deployable outcomes, isolated failure domains, or uncertain feasibility. For each proposed goal, name its useful outcome, acceptance evidence, and dependencies. A team, file, or architectural layer alone does not justify a separate goal; keep parts together when they only deliver value jointly.

Present proposed goals and dependencies. Obtain confirmation for a split, material rewrite, or unresolved outcome; this is scope clarification, not spec approval.

When feasibility blocks a decision, propose a bounded investigation: the question, time or effort limit, evidence to collect, and the decision that evidence will support. On completion, state whether to proceed, revise the approach, or seek a decision to stop. Work on already-actionable goals while preserving real dependencies; do not treat unresolved feasibility as proven or silently abandon the dependent goal.

For multiple confirmed goals, use the supplied parent issue or create one to track the requirement. Record deferred goals as `- [ ] <goal> — depends on <goal>` and preserve existing entries. Separate issues are optional when requested. Each design lane receives its exact goal and issue; a single goal's issue is resolved by its design skill.

Route changed system boundaries to [design-system.md](design-system.md), live infrastructure operations to [design-infra.md](design-infra.md), and application work to [design-feature.md](design-feature.md). Mixed work keeps separate artifacts with explicit dependencies. Begin the first actionable goal; do not silently discard deferred work.
