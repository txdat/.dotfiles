# /frame-goal — Clarify the Goal

Use when a requirement is ambiguous or bundles independently useful outcomes, including when design or review finds that an existing plan bundles goals. A clear, coherent request goes directly to its design lane.

Frame each goal as the smallest coherent useful outcome. Inspect relevant context, identify material competing interpretations, and propose a split only when outcomes can be accepted and delivered separately; the set of goals must preserve every required behavior and explicit constraint. Candidate boundaries are user capabilities or independently useful operational outcomes. Large scope, a team, a file, or an architectural layer alone is not a boundary; keep parts together when they only deliver value jointly. Review burden is not a boundary either; [design-feature.md — PR slicing](design-feature.md#pr-slicing) divides a whole goal's review across PRs. Parts that are each useful and acceptable on their own are separate goals even when they share a layer, files, or a prerequisite.

For each goal, name its useful outcome, outcome-level acceptance evidence, and dependencies; design derives the ACs and TCs. Obtain confirmation for a split, material rewrite, or unresolved outcome; this is scope clarification, not spec approval.

When feasibility blocks a decision, propose a bounded investigation: the question, effort limit, evidence to collect, and the decision it will support. Continue already-actionable goals meanwhile, and revisit the dependent goal once the investigation concludes.

For multiple confirmed goals, use the supplied parent issue or create one. Record deferred goals as `- [ ] <goal> — depends on <goal or none>`, preserving existing entries. A single goal's issue is left to its design skill.

When re-entered for a `planning` plan, frame from its Goal and the reported boundary rather than its current slices. After the user confirms a split, the main agent narrows that plan to the first actionable goal, records the narrowing and confirmation as a `DD-n` entry in `## Design Decisions`, records the remaining goals as deferred in the parent issue as above, and returns the plan to design to reconcile its ACs, TCs, steps, and slices before a new review. If the user keeps the goal whole, record that decision and the coupling that justifies it as a `DD-n` entry; the same boundary is not reported again.

Route changed system boundaries to [design-system.md](design-system.md), live infrastructure operations to [design-infra.md](design-infra.md), and application work to [design-feature.md](design-feature.md); mixed work keeps separate artifacts with explicit dependencies. Pass each design lane its exact goal and issue, and begin the first actionable goal.
