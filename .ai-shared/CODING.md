# Engineering Standards

## Changes and evidence

Follow project patterns and stay within the request: no speculative abstractions or unrelated cleanup. Fix root causes; label a temporary mitigation with its limits and removal condition.

Duplication is cheaper than the wrong abstraction: extract an established shared concept, not an anticipated one. Reuse code that implements the same concept (same data meaning and contract, not merely similar steps); do not bend shared code with flags to serve a different concept.

Verify changed calls, fields, imports, and assumptions against actual definitions or runtime evidence. Design failure paths deliberately and preserve error causes. Comment only non-obvious reasons or invariants. UI work follows [frontend-design.md](skills/dev/frontend-design.md).

Tests assert required observable behavior; never special-case test inputs or replace behavior with canned results. Start with affected tests and callers plus required project checks; broaden to the full suite when requested, required, cheap, or needed to cover the impact. Plan-backed work adds [test-first proof](skills/dev/plan.md#verification).

Report inspected facts, inference, and unrun checks distinctly, with decisive file locations or command results and no secrets.

## Critical work

Before changing security, concurrency, data-integrity, or performance-critical behavior:

1. State the invariants and failure modes: races, partial failure, ordering, retries, resource exhaustion, security boundaries.
2. Check the affected contracts and existing pattern against them. If the pattern cannot preserve the required behavior or a material decision is open, stop and report the conflict; never silently change the contract.
3. Implement and verify against those obligations, including failure paths. Report residual risk and missing evidence.

## Impact

For changed contracts, inspect callers, consumers, and tests, including reliance on errors, defaults, ordering, timing, and side effects beyond the signature. For shared state used as a decision input or signal, check writers and readers together: meaning, ownership, initialization, transitions, concurrency, cleanup.

Record decisive evidence with the design or verification results. Fix broken consumers within scope; material compatibility uncertainty or extra work needs a decision first, under [plan.md — Changes](skills/dev/plan.md#changes) for plan-backed work.

## Tools

Prefer semantic navigation for definitions and callers. Reuse evidence until its inputs change.

Database MCP (mandatory): before writing any query or aggregation pipeline, read the schema and existing indexes of every target, including join targets, with the MCP's tools. Shape it to those fields, types, and indexes. If no index supports it, report that; never create indexes.

Shared shell helpers live in `~/.dotfiles/.ai-shared/bin/`; invoke them by full path with Bash, as their owning skill specifies.

## Ownership

Preserve unrelated work. The main agent owns Git mutations unless a task explicitly delegates them. Confirm destructive actions only when they exceed existing authorization. Never bypass required checks or discard unfamiliar files to get past an obstacle; fix the failure or report the blocker.

Work directly by default. Delegate only a substantial, independent chunk, when a subagent is available and concurrent work justifies it. Use the most specific agent type whose description and tools fit the chunk, else general-purpose. Tell the subagent to read this file and the owning skill; give it exclusive files, inputs, verification, and off-limits actions, and remind it that others share the codebase. The main agent integrates and verifies the result. Review isolation follows [plan.md — Review](skills/dev/plan.md#review).
