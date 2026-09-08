# /review-code — Review Implemented Work

Read [plan.md](plan.md) and [independence.md](independence.md). Entry is `implemented`. Review the recorded worktree from the first PR row's Parent through the final implementation tip, excluding inherited work from an unmerged parent.

## Behavioral evidence

Derive the required outcome from the Goal and source contracts before treating the tests as an oracle. Compare each AC's Success/Failure with delivered behavior. Maintain a compact evidence map covering every approved TC:

`TC | AC obligation | Test / production entry point | Distinguishing assertion | Proof or baseline | Current result`

Reference verified existing evidence instead of duplicating output. Include revision and command references with results; inspect proof and per-test results under [verification.md — Test-first proof](verification.md#test-first-proof). Independently run TC and affected tests, reusing unchanged evidence only under the independence rules.

Trace each distinct AC obligation to reachable assertions, including required side effects and unchanged-state conditions. Confirm the test's arrangement reaches the relevant production boundary: a helper test below authorization, routing, or transaction handling cannot prove that omitted behavior. Inspect whether copied implementation expressions, mock-call checks, or broad no-error assertions could pass for a wrong result; apply [verification.md](verification.md)'s assertion-quality requirements.

For each AC, challenge plausible incorrect behavior against the actual assertions. Record material gaps or non-obvious defeating evidence. Conclude whether each AC and the Goal hold; passing tests cannot override a violated obligation. Implementation defects require repair; uncertain or conflicting intended behavior follows [approval.md](approval.md).

## Affected-path review

- **Contracts and data:** inspect applicable security, data-integrity, concurrency, compatibility, and failure paths under [CODING.md — Impact](../../CODING.md#impact). Check mechanism invariants and non-functional commitments against the actual code and dependencies.
- **Scope and verification:** compare changes with the steps and required Design Decisions; inspect deviations and spec amendments under [approval.md](approval.md). Verify Open Risks are resolved through their approved TCs and check [verification.md — Coverage](verification.md#coverage). An absent deviation record does not prove alignment. Apply [frontend-design.md](frontend-design.md) for UI work.
- **Efficiency and maintainability:** inspect affected paths for unnecessary queries, repeated computation, unbounded work or allocations, unsuitable structures, and complexity that obscures required behavior. Report concrete impact or maintenance risk; preferences alone do not block.

Inspect secrets and debug/conflict artifacts, then run `~/.dotfiles/.ai-shared/bin/dev-check artifacts <first-slice-parent> HEAD`. Read the diff as well; the helper does not cover every artifact or exposure.

Report the Goal/AC conclusions, decisive test/proof evidence, and located findings with failure mechanism and consequence. Use `REWORK REQUIRED` for correctness, security, scope, or required-verification defects; `PASS WITH NOTES` for non-blocking material concerns; otherwise `PASS`. Avoid repeated findings and empty report sections.

## Finalize during authorized delivery

The main agent handles repairs and re-review under [independence.md](independence.md). Implementation defects leave status `implemented`; spec amendments follow [approval.md](approval.md).

On a passing review, reconcile actual slices with [design-feature.md](design-feature.md)'s PR Pattern. Changed parents or TC/slice ownership require a revised pattern and approval. Remove `(provisional)` only when it matches the verified work.

For every slice, record `Slice N (<branch>): green at <sha>` in the finalized pattern. Verify lint, build, and that slice's tests at its own tip; reuse results only when the tip and verification inputs are unchanged. The main agent performs required checkouts in a clean worktree. A final green tip does not prove earlier slices.

Record review evidence and disposition of notes, set `reviewed`, and hand off to [create-pr.md](create-pr.md). A standalone review returns the report without changing artifacts.
