# AI — Engineering Core

Universal engineering rules. Loaded by the main session (via `GUIDELINES.md`) and by every subagent (via its role doc). Role/communication/workflow rules live in `GUIDELINES.md` and apply to the main session only.

## Code
**Match before inventing.** Mirror existing patterns and style.

**Minimal footprint.** Every change traces to the request. No adjacent fixes or abstractions. Refactor only when explicitly asked. Remove only what you introduce; leave existing dead code alone. Spotted cleanup → note it (in your report/insights), do not apply.

**Root causes only.** Never patch or mask symptoms.

**Verify symbol membership.** Before calling a method, accessing a field, or importing a name: resolve the receiver's concrete type from annotations, declarations, or return types; confirm the symbol is declared on that type (or a base it inherits) or exported from that module by searching the defining file, not the whole repo. Existence elsewhere does not count. Not a member → STOP, report `❌ <receiver_type>.<symbol> — not a member`, ask, wait for response.

**Confirm destructive actions.** No exceptions.

## Evidence
Cite file contents, output, or test results. Never memory. If not found, say so.

**Raw output.** For diagnostic/state commands (`git status`, `ls`, log reads, `pip list`, env checks) before any consequential action: quote verbatim. Never substitute a summary where exact state matters.

**Code review suggestions.** Every non-blocking/suggestion finding needs concrete backing: file path + line numbers, quoted code, and the mechanism by which it manifests or the gain is measurable. No backing → omit or escalate to a question.

## Tooling
**File I/O:** Prefer platform-native file read/edit tools over shell equivalents (`cat`, `sed`, `head`, `tail`, `echo`) when available.

**Search/process:** `rg` over `grep` for repo search, `fd` over `find`, `jq` for JSON. Standard Unix filters fine in shell pipelines.

**Minimize tool calls.** Pipelines over sequences. Avoid redundant calls.

**Subagent context:** Write to `/tmp/ai-ctx/<slug>.md` before spawning. Prompt: "Read `/tmp/ai-ctx/<slug>.md` first, then…"

## Conventions
**Git credentials.** All git/GitHub actions run under the personal token from `gh auth login` (account `txdat`). Route GitHub ops through `gh`; rely on its stored credential. Never hardcode a token, inject `GITHUB_TOKEN`/`GH_TOKEN`, or use any other account. `gh auth status` not showing `txdat` active → STOP, report, wait.

**Base branch (`<base>`):** `BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|.*/||' || echo main)`. Skill docs use `<base>` to refer to this.
