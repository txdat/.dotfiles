# AGENTS.md

This file provides guidance to Claude Code (claude.ai/code) and other AI agents when working with code in this repository.

## What this directory is

`.ai-shared` holds the rules, skills, agents, and helper scripts shared by every agent harness on this machine. The Git root is `~/.dotfiles`, one level up. [CORE.md](CORE.md) is the global rules file: Claude Code, Codex, Antigravity, Pi, dsh, and OpenCode all load it through a symlink, so it is already in your context. Don't restate it here or in other files. [README.md](README.md) lists the harnesses, [skills/README.md](skills/README.md) indexes the skills, and [agents/README.md](agents/README.md) indexes the agents. One file per harness — [claude.md](references/claude.md), [codex.md](references/codex.md), [antigravity.md](references/antigravity.md), [pi.md](references/pi.md), [dsh.md](references/dsh.md), [opencode.md](references/opencode.md) — wires them up.

Edits to this directory are direct edits, not plan-backed work. See [plan.md — Scope](skills/dev/plan.md#scope).

## Writing rules

- **Each policy has one owner.** Each file owns the policy it states. Other files link to it as `[file — Section](path#anchor)` instead of paraphrasing it. A copied rule drifts from its source. Before adding a rule, find the file that already owns that topic and edit it there.
- **Links resolve from the source file's directory, following symlinks.** `CORE.md` is read through harness symlinks such as `~/.claude/CLAUDE.md`, so its relative links must work from `.ai-shared/`.
- **Headings and paths are load-bearing.** Before renaming a heading, a file, or a `bin/` script, grep all three places that refer to them:
  - links in `.ai-shared` (agents cite anchors such as `CORE.md#work`)
  - `gate-check.sh` block messages (they cite anchors such as `skills/dev/plan.md#schema`)
  - external consumers that hard-code `bin/` paths: `../.pi/agent/extensions/*.ts`, `../.claude/marketplace/plugins/dev-stack/hooks/register.ts` and `register.test.ts`, and the hook registrations the harness files describe, such as `~/.claude/settings.json` and `~/.gemini/config/hooks.json`
- **Rules must be harness-neutral.** Six harnesses read these files. Phrase tool-specific steps the way existing files do: "where installed", "Without a Skill tool, read … with the file-read tool".
- **Style:** terse, declarative, and imperative, without filler or rigid templates. Word choice follows [Wording](#wording).
- **Skill files** start with `# /<name> — <summary>` and stay short. Load-time metadata (description, effort, model) lives in the [skills/README.md](skills/README.md) table, not in the skill file.

## Wording

Pick words for what they commit the reader to. The existing rules use this vocabulary consistently; keep to it.

| Intent | Write | Example |
|---|---|---|
| Required action | A bare imperative | "Run the TC tests and affected tests yourself at the final tip." |
| Fact the reader relies on, or a mechanism | Present tense | "A gate blocks each phase until its entry status holds." |
| Required property of a result or artifact | `must` | "Assertions must tell the required result from a plausible wrong one." |
| Prohibition | `never`, followed by the alternative or the consequence | "Never invent authors…; missing identity or auth blocks the operation." |
| Who may act, or how far a rule reaches | `only`, with the actor named | "`approved` — the user only, from `ready`" |
| Permission that is otherwise withheld | `may` | "The reviewer may read, run tests, and inspect Git." |
| Consequence | A defined verb: `blocks`, `stops`, `never blocks`, `report` | "A failure stops that step and everything depending on it under …" |
| Example | `such as` | "Execution decides only details that are not design choices, such as names and internal structure." |

- Avoid soft or hedged words: `should`, `consider`, `try to`, `ideally`, `as needed`, `appropriate`, `if relevant`. Each leaves the reader to guess whether the rule applies. State the condition instead: "when X, do Y". The rule prose uses none of these, and `always` appears only once.
- Don't use emphasis to add force. The rules contain no `MUST`, `IMPORTANT`, or emphatic bold; bold marks list labels only. A rule that needs emphasis needs a clearer condition or consequence.
- Name the actor whenever more than one could act: "the user", "the main agent", "the reviewer", "autopilot". The passive voice hides who owns a step.
- Use one term per concept. Reuse the defined terms exactly: status names, `AC`/`TC`/`ST`/`PC`/`DD`, Base, Branch, PR target, worktree, scratch. Never use a synonym for variety; a reader takes a new word to mean a new thing.
- Be concrete. Give limits as numbers ("after two re-reviews", "three failed fix-and-verify attempts"). Write fields, statuses, paths, and commands in backticks, exactly as a script or gate reads them.
- Scope each rule by its trigger, not by an adjective. Write "before changing security, concurrency, … behavior", not "for important changes".

## Changing rules

Write rules in English only, whatever language the request uses.

1. **Tighten once.** After drafting, the main agent tightens the change once. It cuts hedges, filler, and restated policy without changing what the rule requires.
2. **Review.** A fresh agent that has not seen the conversation reviews the tightened change against this file. It returns findings marked as blocking or as notes.
3. **Fix and re-review.** The main agent fixes each blocking finding and does not tighten again. A fresh agent then re-reviews the fixes. Stop when no blocking finding remains or after the third review, counting the first, and report any blocking findings still open.

## Adding or renaming a skill or agent

Update every place below:

1. The row in [skills/README.md](skills/README.md) (name, description, md file, effort, and model) or [agents/README.md](agents/README.md) (name, description, md file, and tools). Codex and Antigravity models come from the model mappings in [codex.md](references/codex.md#model-mapping) and [antigravity.md](references/antigravity.md#model-mapping).
2. Each harness's wrapper, built from the templates in its harness file. Wrappers live outside this repo, such as `~/.claude/skills/<name>/SKILL.md`, and must use an absolute md path, with no `~` or `$HOME`. Agents carry no model or effort, and only the [Claude agent template](references/claude.md#claude-agent-template) takes `tools`.
3. For dev skills, the table in [skills/dev/README.md](skills/dev/README.md).
4. For a dev phase the gate must recognize, `DEV_SKILL_SLUG_RE` in `bin/gate-check.sh` and its cases in `bin/gate-check-test.sh`.

## Adding a hook script

A hook script in `bin/`, such as `gate-check.sh` or `test-serial-check.sh`, reads each harness's hook JSON on stdin and prints that harness's verdict. Update every place below:

1. The script and its `bin/<name>-test.sh`, with cases for the Claude Code input (`tool_name`, `tool_input`) and the Antigravity input (`toolCall.name`, `toolCall.args`).
2. The verdict shape each harness reads per event, asserted by the tests:
   - Claude Code: a pass prints nothing. A PreToolUse deny carries `hookSpecificOutput` with `hookEventName: "PreToolUse"` and `permissionDecision: "deny"`. A top-level `decision` must be `approve` or `block`; any other value makes Claude Code drop the whole output. Only a PreToolUse deny carries `hookSpecificOutput`; a UserPromptSubmit or PostToolUse block uses top-level `decision: "block"`.
   - Antigravity: a PreToolUse pass prints nothing, because every `decision` value, `allow` included, changes Antigravity's permission flow. A PreToolUse deny is `{"decision":"deny","reason":…}` with no Claude Code fields. PostToolUse prints `{}`, or `{"overwriteResult":…}` to report to the agent, on every path.
3. The hooks entry in [claude.md](references/claude.md) and [antigravity.md](references/antigravity.md): event, matcher, and what the script refuses.
4. For Pi, an extension in `../.pi/agent/extensions/` that sends the script the Claude-shaped JSON and blocks on its verdict, its entry in [pi.md](references/pi.md), and a passing `typecheck.sh`.

## Plan schema and scripts

The gate reads plan header fields and IDs, never prose. A change to the plan schema, statuses, or stack rules in [plan.md](skills/dev/plan.md) therefore needs matching changes to `bin/gate-check.sh`, `bin/dev-stack.sh`, `bin/dev-publish.sh`, `bin/dev-plan-lib.sh`, and their `-test.sh` files.

Script conventions:

- Start with `#!/bin/bash` and `set -euo pipefail`. A sourced library such as `dev-plan-lib.sh` has no shebang or `set` line; it runs under its caller's options. `gke-collect.sh` omits `-e` so one failed query never aborts the sweep. `gate-check.sh` and `test-serial-check.sh` also set `LC_ALL=C`, because a multibyte locale once crashed `awk` and the hook read the crash as a pass.
- Begin with a header comment that links the owning md section.
- Callers invoke scripts by full path, `~/.dotfiles/.ai-shared/bin/<script>`.
- Tests live in `bin/<name>-test.sh`. Tests that need a repository build scratch Git repos under `/tmp`, whose `docs/plans` hold their plans, ignore those through each repo's `.git/info/exclude` with `GIT_CONFIG_GLOBAL=/dev/null`, and set `AI_WORKTREES_ROOT` so they never touch `~/work/wt`.

## Commands

The test files take no filter argument, so the smallest unit is one test file.

```bash
bash bin/gate-check-test.sh                              # one shell test file
for t in bin/*-test.sh; do bash "$t" || echo "FAIL $t"; done   # all shell tests
node --test skills/ielts/scripts/ielts-score.test.ts     # TS tests; need Node 22.18+
node --test skills/gke/scripts/gke-collect-test.ts
bash ~/.dotfiles/.pi/agent/extensions/typecheck.sh       # Pi extensions that call bin/ scripts
```
