# /frame-goal — Clarify the Goal

Use when a requirement is ambiguous or bundles independently useful outcomes. A clear, coherent request goes directly to its design lane.

Frame each goal as the smallest coherent useful outcome. Inspect relevant context, identify material competing interpretations, and propose a split only when outcomes can be accepted and delivered separately; the set of goals must preserve every required behavior and explicit constraint. Candidate boundaries are user capabilities or independently useful operational outcomes. Large scope, a team, a file, or an architectural layer alone is not a boundary; keep parts together when they only deliver value jointly. A goal may need several PRs: carry a hard-to-review goal into [design-feature.md — PR slicing](design-feature.md#pr-slicing) rather than splitting it here.

For each goal, name its useful outcome, outcome-level acceptance evidence, and dependencies; design derives the ACs and TCs. Obtain confirmation for a split, material rewrite, or unresolved outcome; this is scope clarification, not spec approval.

When feasibility blocks a decision, propose a bounded investigation: the question, effort limit, evidence to collect, and the decision it will support. Continue already-actionable goals meanwhile, and revisit the dependent goal once the investigation concludes.

For multiple confirmed goals, use the supplied parent issue or create one. Record deferred goals as `- [ ] <goal> — depends on <goal or none>`, preserving existing entries. A single goal's issue is left to its design skill.

Route changed system boundaries to [design-system.md](design-system.md), live infrastructure operations to [design-infra.md](design-infra.md), and application work to [design-feature.md](design-feature.md); mixed work keeps separate artifacts with explicit dependencies. Pass each design lane its exact goal and issue, and begin the first actionable goal.
