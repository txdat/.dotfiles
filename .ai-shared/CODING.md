# Engineering Standards

## Changes and evidence

Follow project patterns. Keep changes within the request; avoid speculative abstractions and unrelated cleanup. Prefer root-cause fixes. Label a temporary mitigation with its limits and removal condition.

Duplication is cheaper than the wrong abstraction: extract an established shared concept, not an anticipated one.

Verify changed calls, fields, imports, and assumptions against actual definitions or focused runtime evidence. Design failure paths deliberately, preserve error causes, and comment only non-obvious reasons or invariants.

Tests should assert required observable behavior. Never special-case test inputs or replace required behavior with canned results. Distinguish inspected facts, inference, and unrun checks; report decisive file locations or command results without exposing secrets.

Start verification with affected tests and callers, plus required project checks. Broaden to the full suite when requested, required, inexpensive, or necessary to cover the impact. Report incomplete checks and their implications. Development-specific proof and coverage rules live in [verification.md](skills/dev/verification.md).

## Critical work

Before changing security, concurrency, data-integrity, or performance-critical behavior:

1. State the invariants and relevant failure modes: races, partial failure, ordering, retries, resource exhaustion, and security boundaries.
2. Inspect the affected contracts and existing pattern against those conditions. If the pattern cannot preserve the required behavior or a material decision is unresolved, stop the affected implementation and report the conflict; do not silently change the contract.
3. Implement and verify against those obligations, including failure paths. Report any residual risk or missing evidence.

## Impact

For changed contracts, inspect callers, consumers, and tests, including dependencies on errors, defaults, ordering, timing, and side effects beyond documented signatures. For shared state used as a decision input or signal, check writers and readers together: meaning, ownership, initialization, transitions, concurrency, and cleanup.

Record decisive evidence with the design or verification results. Resolve broken consumers within scope; material compatibility uncertainty or additional work needs a decision before the change is ready. Plan-backed decisions follow [approval.md](skills/dev/approval.md).

## Tools

Use the tool that answers the question: semantic navigation for definitions and callers, `rg` for text and files, source reads to verify results. Batch independent reads; keep dependent actions and mutations sequential. Reuse evidence until its inputs change.

For Sverklo, use read-only `overview`, `search`, or `lookup`; exploration does not use memory or management operations. Verify returned source belongs to the intended repository and use another navigation method when the index is stale or inconclusive.

Shared shell helpers live in `~/.dotfiles/.ai-shared/bin/`; invoke them by full path with Bash. Python helpers use Python 3. Follow the owning skill's arguments and invocation conditions.

## Ownership

Preserve unrelated work. The main agent owns Git mutations unless a task explicitly delegates them. Confirm destructive actions only when they exceed existing authorization.

Default to direct work. Delegate a substantial, independent chunk only when permitted and useful concurrent work exists. Use a platform-provided general-purpose subagent, instructed to read this file and the owning skill. Assign exclusive file ownership, required inputs, verification, and off-limits actions; tell workers they share the codebase and must preserve others' edits. The main agent integrates and verifies the result. Review isolation is owned by [independence.md](skills/dev/independence.md).

For an explicitly requested code audit without a plan, inspect the supplied scope directly under those review rules. Report located findings with failure mechanism, consequence, and verification limits; do not invent a plan or phase transition.
