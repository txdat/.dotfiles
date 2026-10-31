# ai-shared

Shared agent rules, workflow skills, and helper scripts for every harness on this machine. Platform-specific skill and agent wrappers are generated locally and point at the markdown files here.

Reviews under [plan.md — Review](skills/dev/plan.md#review) run in the [dev-reviewer](#agents) agent where installed; other delegation uses platform-provided subagents with the owning skill.

Paths below assume the dotfiles checkout is at `~/.dotfiles`.

| Harness | Rules file | Skills |
| ------- | ---------- | ------ |
| Claude Code | `~/.claude/CLAUDE.md` | `~/.claude/skills/<name>/SKILL.md` |
| Codex | `~/.codex/CODEX.md` | `~/.codex/skills/<name>/SKILL.md` |
| Antigravity | `~/.gemini/config/GEMINI.md` | `~/.gemini/config/skills/<name>/SKILL.md`, or a path in `skills.json` |
| Pi | `~/.pi/agent/AGENTS.md` | reuses `~/.claude/skills` |
| dsh | `~/.dsh/AGENTS.md` | `~/.dsh/skills/<name>/SKILL.md` |

## Claude Code

Symlink `~/.claude/CLAUDE.md` → `~/.dotfiles/.ai-shared/AGENTS.md`.

**skills** — create `~/.claude/skills/<name>/SKILL.md` from the [Claude template](#claude-template), taking name, description, effort, and model from [references](#references).

**agents** — create `~/.claude/agents/<name>.md` from the [Claude agent template](#claude-agent-template), taking name, description, tools, and md file from [agents](#agents).

**hooks** — in `~/.claude/settings.json`, register `~/.dotfiles/.ai-shared/bin/gate-check.sh` for `PreToolUse` with matcher `Skill` (model-invoked skills) and for `UserPromptSubmit` (user-typed `/dev-*` commands, which bypass the Skill tool).

**marketplace** — add the local marketplace at `~/.dotfiles/.claude/marketplace/` with `claude plugin marketplace add <path>`, then install plugins via `/plugin`.

## Codex

Symlink `~/.codex/CODEX.md` → `~/.dotfiles/.ai-shared/AGENTS.md`.

`CODEX.md` is the only setup-managed symlink. Do not remove or modify other symlinks in `~/.codex`: Codex creates them for its runtime under `packages/` and `tmp/`.

**skills** — create `~/.codex/skills/<name>/SKILL.md` from the [Codex template](#codex-template), taking name, description, and effort from [references](#references) and the model through [model mapping](#model-mapping).

**agents** — create `~/.codex/agents/<name>.toml` from the [Codex agent template](#codex-agent-template), taking name, description, and md file from [agents](#agents).

## Antigravity

Symlink `~/.gemini/config/GEMINI.md` → `~/.dotfiles/.ai-shared/AGENTS.md`, and `~/.gemini/GEMINI.md` → the same file.

**skills** — create `~/.gemini/config/skills/<name>/SKILL.md` from the [Antigravity template](#antigravity-template), or register its path in `~/.gemini/config/skills.json`, taking name, description, and effort from [references](#references) and the model through [model mapping](#model-mapping).

**agents** — create `~/.gemini/config/agents/<name>/agent.md` from the [Antigravity agent template](#antigravity-agent-template), or register its path in `~/.gemini/config/agents.json`, taking name, description, and md file from [agents](#agents).

**hooks** — register lifecycle hooks in `~/.gemini/config/hooks.json`, for example the `gate-check.sh` command as a `PreToolUse` hook.

## Pi

Symlink:

- `~/.pi/agent/AGENTS.md` → `~/.dotfiles/.ai-shared/AGENTS.md`
- `~/.pi/agent/extensions` → `~/.dotfiles/.pi/agent/extensions`
- `~/.pi/agent/themes` → `~/.dotfiles/.pi/agent/themes`

**skills** — Pi reuses the Claude skills; set `"skills": ["~/.claude/skills"]` in `settings.json`.

**mcp** — Pi reuses Claude MCP servers; set `"imports": ["claude-code"]` in `mcp-adapter.json`.

**phase loading and gates** — to enter a development phase, use Pi's `read` tool on the phase's Claude `SKILL.md` wrapper or on the shared `.ai-shared/skills/dev/<phase>.md` instructions.

The [gate extension](../.pi/agent/extensions/gate-check.ts) checks that read against its phase arguments: the text of the assistant message that issued it when that text names a plan, and otherwise the latest user message. Where the phase requires it, those arguments must give the exact plan path.

The extension gates recognized reads, not phase execution. It cannot distinguish an audit read from invocation, and shell reads or previously loaded instructions are outside its interception. Documentation-only inspection may therefore read source without invoking a phase, which grants no authority to execute it. It also permits reads on timeout, process failure, or invalid output. Treat it as a workflow aid rather than comprehensive enforcement: agents must still establish the phase prerequisites under [skills/dev/plan.md](skills/dev/plan.md). Stronger enforcement would require a separate phase-entry operation.

**dev-stack** — the [extension](../.pi/agent/extensions/dev-stack.ts) ports the Claude `dev-stack` plugin's `/dev-stack-*` commands over the same `dev-stack.sh`. Pi runs a command even mid-turn, so a write (`review`, `stop`, `resume`) waits for the turn to end before it changes a plan or its stack's `stops.log`. Pi commands are user-initiated, so the Claude plugin's refusal of plugin-, SDK-, and agent-issued writes has no Pi equivalent.

**types** — the extensions are TypeScript 7 under [tsconfig.json](../.pi/agent/extensions/tsconfig.json). `bash ~/.dotfiles/.pi/agent/extensions/typecheck.sh` checks them against the installed Pi release, whose API types they import.

## dsh

Symlink `~/.dsh/AGENTS.md` → `~/.dotfiles/.ai-shared/AGENTS.md`.

**skills** — create `~/.dsh/skills/<name>/SKILL.md` from the [dsh template](#dsh-template); the harness scans the user root `~/.dsh/skills`. Take name and description from [references](#references). The dsh frontmatter parser keeps `name`, `description`, `whenToUse`, `metadata`, `disable-model-invocation`, and `user-invocable`, and silently discards any other key.

## Wrapper templates

Each skill wrapper names one skill and delegates to its markdown file. Keep the body to that single instruction.

### Claude template

```
---
name: <name>
description: <description>
model: <Claude Code model>
effort: <effort>
---

Read <md file> and follow all instructions exactly.
```

### Codex template

```
---
name: <name>
description: <description>
model: <Codex model>
effort: <effort>
---

Read <md file> and follow all instructions exactly.
```

### Antigravity template

```
---
name: <name>
description: <description>
model: <Antigravity model>
effort: <effort>
---

Read <md file> and follow all instructions exactly.
```

### dsh template

```
---
name: <name>
description: "<description>"
user-invocable: true
---

Read <md file> and follow all instructions exactly.
```

### Agent templates

One agent serves skills with different models, so agents carry no model or effort; the caller passes the skill's. Only Claude Code takes `tools`; elsewhere the md file's rules restrict the agent.

#### Claude agent template

```
---
name: <name>
description: <description>
tools: <tools>
---

Read <md file> and follow all instructions exactly.
```

#### Codex agent template

```toml
name = "<name>"
description = "<description>"

developer_instructions = """
Read <md file> and follow all instructions exactly.
"""
```

#### Antigravity agent template

```
---
name: <name>
description: <description>
---

Read <md file> and follow all instructions exactly.
```

## References

### Model mapping

| Claude Code | Codex | Antigravity |
| ----------- | ----- | ----------- |
| haiku | gpt-6-luna | flash |
| sonnet | gpt-6.1-terra | flash |
| opus | gpt-6.1-sol | pro |
| fable | gpt-6-astra | pro |

### Skills

Where a row leaves effort or model blank, the wrapper installs without that field and the harness default applies.

#### swe

| skill | description | md file | effort | model |
| ----- | ----------- | ------- | ------ | ----- |
| dev-create-issue | Create a GitHub issue with a specific problem, expected outcome, and requested metadata, standalone or for a plan to link. | skills/dev/create-issue.md | medium | haiku |
| dev-create-pr | Publish a reviewed plan, with every plan stacked on it, as draft or ready pull requests, one per plan, mark the plans published, and clean up their worktrees and branches. | skills/dev/create-pr.md | medium | haiku |
| dev-design-feature | Design a feature, fix, or refactor plan before implementation: decisions, acceptance criteria, concrete test cases, ordered steps, and a stack of plans when the work needs several PRs. | skills/dev/design-feature.md | medium | opus |
| dev-design-infra | Design a runnable infrastructure operations plan from live-state evidence, verification gates, and rollback requirements. | skills/dev/design-infra.md | high | haiku |
| dev-design-system | Design cross-cutting architecture changes such as new communication patterns, service boundaries, or integrations, with options, contracts, migration, rollback, and decomposition. | skills/dev/design-system.md | medium | opus |
| dev-execute-feature | Implement an approved plan with test-first commits and verification at its branch tip. | skills/dev/execute-feature.md | high | haiku |
| dev-explore | Read-only exploration of a codebase area to identify entry points, key files, data flow, established patterns, gotchas, and planning questions. | skills/dev/explore.md | medium | haiku |
| dev-fix-bug | Diagnose a bug from evidence, propose fix options and follow-ups, and route a requested fix: plan-backed delivery when asked, otherwise a direct edit. | skills/dev/fix-bug.md | medium | opus |
| dev-review-code | Independently review an implemented plan for TDD proof, test results, correctness, security, scope, and hygiene, then record the reviewed tip. | skills/dev/review-code.md | xhigh | haiku |
| dev-review-feature | Independently review a planning-stage plan for missing obligations, untraced decisions, weak test cases, delivery order, and simpler designs before human approval. | skills/dev/review-feature.md | medium | opus |
| dev-review-infra | Review an infra/devops runbook against live state with read-only commands: phase ordering, rollback safety, DNS/traffic cutover sequencing, IaC completeness, and CI/CD coverage. | skills/dev/review-infra.md | high | haiku |
| dev-review-system | Review an architecture design for measurable outcomes, viable alternatives, boundary contracts, failure modes, migration and rollback safety, and dependency-ordered decomposition. | skills/dev/review-system.md | medium | opus |
| dev-run-stack | Drive a stack of plans, or one plan, through the design loop (review-feature and revise until ready), the execute loop (execute-feature, review-code, and repair until reviewed), and create-pr in dependency order, then report the PRs and what needs the user. | skills/dev/run-stack.md | medium | haiku |
| dev-recap | Session lessons and workflow improvement proposals from a plan-based session. | skills/dev/recap.md | medium | haiku |

#### sre

| skill | description | md file | effort | model |
| ----- | ----------- | ------- | ------ | ----- |
| gke-inspect-incident | Investigate GKE incidents with read-only collection and targeted diagnostic evidence. | skills/gke/inspect-incident.md | high | haiku |

#### ielts

| skill | description | md file | effort | model |
| ----- | ----------- | ------- | ------ | ----- |
| ielts-listening | Analyze IELTS listening answers against scripts and available evidence. Guide replay and focused drills; distinguish supported diagnoses from hypotheses. | skills/ielts/listening.md | — | — |
| ielts-mock | Record full or partial IELTS practice and exam results, preserve each score's provenance, calculate an overall only from four known components, and archive safely. | skills/ielts/mock.md | — | — |
| ielts-reading | Diagnose IELTS reading errors: locate passage evidence, extract synonym pairs, show correct reasoning chain. Covers T/F/NG, Matching Headings, and guided practice. | skills/ielts/reading.md | — | — |
| ielts-speaking | Prepare IELTS speaking topics and review transcript language. Transcript-only feedback cannot establish pronunciation, full fluency, or an overall Speaking band. | skills/ielts/speaking.md | — | — |
| ielts-writing | Plan IELTS Academic Task 1/2 responses with question breakdowns, required coverage, target-band guidance, and errors to avoid; review drafts or generate practice tasks. | skills/ielts/writing.md | — | — |

#### misc

| skill | description | md file | effort | model |
| ----- | ----------- | ------- | ------ | ----- |
| handoff | Write or read a session handoff snapshot (Goal, Current State, Current Plan, Blockers, Remaining Work) so a fresh session can continue without the old conversation. | skills/handoff.md | — | — |

### Agents

| agent | description | md file | tools |
| ----- | ----------- | ------- | ----- |
| dev-reviewer | Review one artifact in a fresh context through review-feature, review-code, review-system, or review-infra, editing only where plan.md — Review allows, and return the verdict and findings. | agents/dev-reviewer.md | Read, Grep, Glob, Bash, Skill, Edit, Write |
