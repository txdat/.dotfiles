# /design-feature — Write a Plan

Write a plan another agent can implement test-first without inventing behavior. Follow [plan.md](plan.md) for the schema and shared rules. Use [design-system.md](design-system.md) when system boundaries change and [frontend-design.md](frontend-design.md) for UI work.

## 1. Understand

Inspect the relevant code, contracts, and conventions, and pick the Base branch: the default branch unless the user names one, or the parent's for a stacked plan. Name the plan's own Branch after the project's convention. When the goal needs several PRs, propose the stack in the brief and write its plans root first under [plan.md — Stacks](plan.md#stacks).

Resolve what the requirement means before writing:

- Define every term, value, and derivation the outcome depends on. "Rank by percentage" must say what is ranked and what the numerator and denominator are.
- Existing code shows current behavior, not necessarily intended behavior.
- Treat a fix or mechanism the request proposes as a hypothesis unless the user states it as a constraint; design for the outcome it protects.
- Never write a plan around TBDs or assumptions. If ambiguity appears later, stop, resolve it, and revise everything it affects.

## 2. Brief the user

Before creating the plan file, send one brief and wait for the answer:

```text
Goal: <intended outcome>
Scope: in <…>; out <…>
Outcomes:
1. <one observable outcome per future AC>
Decisions:
| # | Choice | Options | Tradeoffs | Recommendation |
Stack: <prN — branch — parent — outcome, root first; omit for one PR>
```

Decisions that affect behavior, scope, contracts, the data model, dependencies, or cost belong to the user; list each with options and one recommendation. Other technical choices are yours; record the non-obvious ones as DDs with their rationale. Dropping or narrowing anything the user asked for also needs the user's decision. Record every decision as a `DD-n` and cite it rather than repeating it.

## 3. Write the spec

**ACs.** Write ACs before TCs. Each states one observable outcome, its source, and Success and Failure results decidable without reading a TC. Describe behavior, not mechanism, unless a mechanism is a stated constraint. Make subjective requirements decidable with a measure or a concrete scenario. Then ask: could every AC pass while the Goal still fails? Fix the gap before writing TCs.

**TCs.** Give each TC a concrete fixture, action, and expected result:

- The fixture holds enough data to derive the expected result. Use exact values; express allowed variability as a set, tolerance, or invariant.
- Compute the expected result from the contract, not from the planned implementation; show the calculation when it decides the outcome.
- Cover a case only when a requirement demands it or a reachable input, state, or failure could violate an obligation. Do not invent capabilities, impossible states, or limits, and do not assume a guard exists — inspect it.
- Keep the set focused: one scenario per materially different behavior or failure mechanism, no category matrix. Optional hardening is a follow-up suggestion, not an AC.
- Challenge the set: name plausible wrong implementations, and make sure some TC fails each one.

**Steps.** Order steps by dependency. For new state, record its invariant and initialization in the DD that introduces it. Turn performance, security, and other non-functional commitments into measurable ACs.

Do not write facts that unrelated merges can falsify: line numbers, counts, "the only caller", current config values. When the design depends on a fact about current code, record it as a `PC-n` under the first step that relies on it, with a Check that fails when the fact is false. A rule over a class of entities or states depends on finding every site that reads or writes that class: make that search a Check. Before removing an existing guard or behavior, find out why it exists.

## 4. Keep it simple

Reuse code that implements the same concept, per [CODING.md](../../CODING.md#changes-and-evidence), and handle cases the contract treats alike through one path. For each decision that adds abstraction, state, a dependency, or coordination, its DD names the failure that would occur without it and why a narrower variant would not do; drop the decision otherwise. Count every place that must separately enforce a new rule as a cost. Name the code the change deletes or consolidates.

## 5. Split PRs

Use one plan and one PR unless review needs separable parts; judge by distinct behaviors, contracts, and migration risks, not line count. Each further PR is a plan stacked on the one it needs, correct and safe to merge after its parent alone, with incomplete behavior unexposed. The stack is dependency order and merge order. Propose the stack in the brief; the user chooses.

## 6. Finish

Link the issue the user supplied, or record `Issue: none` and `0` in the directory name. Before handoff, run every PC Check against the inspected branch (the PR target, or Base while that branch does not exist): a Check may fail only when an earlier step or a plan below it in the stack establishes its fact. Save the plan at its [plan.md — Artifact](plan.md#artifact) path with `Status: planning` and hand it to [review-feature.md](review-feature.md).

## 7. Revise after review

On NEEDS CHANGES, correct each blocking finding within the recorded DDs and the user's answers, rerun the PC Checks the change touches, and re-review under [plan.md — Review](plan.md#review). A finding that needs a new or changed decision goes to the user with options and a recommendation.
