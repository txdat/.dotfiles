# Skills

Where a row leaves effort or model blank, the wrapper installs without that field and the harness default applies. The model column names a Claude Code model. For a harness with its own models, such as Codex or Antigravity, the main agent takes a skill's model from the [Codex](../references/codex.md#model-mapping) or [Antigravity](../references/antigravity.md#model-mapping) model mapping for the Claude Code model. The md file column gives paths from `.ai-shared`.

## SWE

| skill | description | md file | effort | model |
| ----- | ----------- | ------- | ------ | ----- |
| dev-autopilot | Drive an issue or requirement through the whole dev flow with auto-approval: triage, fix-bug, create-issue, a direct edit or plan-backed stack, draft PRs marked ready for one code-review round, stopping where a decision needs the user. | skills/dev/autopilot.md | medium | opus |
| dev-create-issue | Create a GitHub issue with a specific problem, expected outcome, and requested metadata, standalone or for a plan to link. | skills/dev/create-issue.md | medium | haiku |
| dev-create-pr | Publish a reviewed plan, with every plan stacked on it, as draft or ready pull requests, one per plan, mark the plans published, and clean up their worktrees and branches. | skills/dev/create-pr.md | medium | haiku |
| dev-design-feature | Design a feature, fix, or refactor plan before implementation: decisions, acceptance criteria, concrete test cases, ordered steps, and a stack of plans when the work needs several PRs. | skills/dev/design-feature.md | medium | opus |
| dev-design-infra | Design a runnable infrastructure operations plan from live-state evidence, verification gates, and rollback requirements. | skills/dev/design-infra.md | high | haiku |
| dev-design-system | Design cross-cutting architecture changes such as new communication patterns, service boundaries, or integrations, with options, contracts, migration, rollback, and decomposition. | skills/dev/design-system.md | medium | opus |
| dev-execute-feature | Implement an approved or auto-approved plan with test-first commits and verification at its branch tip. | skills/dev/execute-feature.md | high | haiku |
| dev-explore | Read-only exploration of a codebase area to identify entry points, key files, data flow, established patterns, gotchas, and planning questions. | skills/dev/explore.md | medium | haiku |
| dev-fix-bug | Diagnose a bug from evidence, propose fix options and follow-ups, and route a requested fix: plan-backed delivery when asked, otherwise a direct edit. | skills/dev/fix-bug.md | medium | opus |
| dev-review-code | Independently review an implemented plan for TDD proof, test results, correctness, security, scope, and hygiene, and return the verdict the main agent records. | skills/dev/review-code.md | high | haiku |
| dev-review-feature | Independently review a planning-stage plan for missing obligations, untraced decisions, weak test cases, delivery order, and simpler designs before human approval. | skills/dev/review-feature.md | medium | opus |
| dev-review-infra | Review an infra/devops runbook against live state with read-only commands: phase ordering, rollback safety, DNS/traffic cutover sequencing, IaC completeness, and CI/CD coverage. | skills/dev/review-infra.md | high | haiku |
| dev-review-system | Review an architecture design for measurable outcomes, viable alternatives, boundary contracts, failure modes, migration and rollback safety, and dependency-ordered decomposition. | skills/dev/review-system.md | medium | opus |
| dev-run-stack | Drive a stack of plans, or one plan, through the design loop (review-feature and revise until ready), the execute loop (execute-feature, review-code, and repair until reviewed), and create-pr in dependency order, then report the PRs and what needs the user. | skills/dev/run-stack.md | medium | haiku |
| dev-split-pr-atomic | On explicit request only, split one open PR into a stack of atomic PRs that together carry exactly its diff, then close the original with a link to them. | skills/dev/split-pr-atomic.md | medium | opus |
| dev-recap | Session lessons and workflow improvement proposals from a plan-based session. | skills/dev/recap.md | medium | haiku |

## SRE

| skill | description | md file | effort | model |
| ----- | ----------- | ------- | ------ | ----- |
| gke-inspect-incident | Investigate GKE incidents with read-only collection and targeted diagnostic evidence. | skills/gke/inspect-incident.md | high | haiku |

## IELTS

| skill | description | md file | effort | model |
| ----- | ----------- | ------- | ------ | ----- |
| ielts-listening | Analyze IELTS listening answers against scripts and available evidence. Guide replay and focused drills; distinguish supported diagnoses from hypotheses. | skills/ielts/listening.md | — | — |
| ielts-mock | Record full or partial IELTS practice and exam results, preserve each score's provenance, calculate an overall only from four known components, and archive safely. | skills/ielts/mock.md | — | — |
| ielts-reading | Diagnose IELTS reading errors: locate passage evidence, extract synonym pairs, show correct reasoning chain. Covers T/F/NG, Matching Headings, and guided practice. | skills/ielts/reading.md | — | — |
| ielts-speaking | Prepare IELTS speaking topics and review transcript language. Transcript-only feedback cannot establish pronunciation, full fluency, or an overall Speaking band. | skills/ielts/speaking.md | — | — |
| ielts-writing | Plan IELTS Academic Task 1/2 responses with question breakdowns, required coverage, target-band guidance, and errors to avoid; review drafts or generate practice tasks. | skills/ielts/writing.md | — | — |

## Misc

| skill | description | md file | effort | model |
| ----- | ----------- | ------- | ------ | ----- |
| handoff | Write or read a session handoff snapshot (Goal, Current State, Current Plan, Blockers, Remaining Work) so a fresh session can continue without the old conversation. | skills/handoff.md | — | — |
