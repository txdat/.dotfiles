# /design-infra — Infrastructure Change Planning

Warn if active infra plan exists. Filename: `docs/plans/<basename>_<date>_infra_<slug>.md`.

Read project AI config files. No apply. Read-only OK (`terraform show`, `kubectl get`).

**Drift detection**: compare live vs config. If drift → add sync step first.

## Draft

Clarify: scope, environments, dependencies, re-run safety, rollback, downtime. Up to 3 rounds.

```
# Task: <name>
Status: planning | Type: infra | Env: <dev|staging|prod|all> | Issue: | Worktree: | Main Plan Fingerprint:

## Requirement
<change and why>

## Scope
In: <items>
Out: <items>

## Design Decisions
| Decision | Options | Chosen | Reason |

## Risk Flags
- [ ] <risk>: <mitigation>

## Pre-flight
- [ ] `<cmd>` — confirms <state>

## Implementation Steps
- [ ] Step 1: <action> — `<cmd>`

## PR Pattern (provisional)
Type: single
| # | Branch | Steps | Summary |
|---|--------|-------|---------|
| 1 | infra/<slug> | 1–N | <summary> |

## Verification Steps
- [ ] Verify 1: `<cmd>` — expected: <result>

## Rollback
Trigger: <condition>
- [ ] `<undo cmd>`

## Out of Scope
- <item>: <why>
```

Rules: 5–15 Implementation Steps, dependency-ordered. >15 → split. Destructive → dry-run inline. `Issue:` is required before execution; create or link one before handoff. Infrastructure plans contain infrastructure config and their runbook only; application-code changes require a separate design-feature plan. Infrastructure plans use one reviewable PR unless the plan is split into independent plans.

**Gate**: pre-flight non-empty, each impl has verify, rollback has step.

## Self-Check (BLOCKING — do NOT emit completion until every item is ✅)

Run this audit before the final output. If ANY item is unchecked → STOP, fix, re-check.

- [ ] **Requirement** (`## Requirement`): measurable, scope explicit.
- [ ] **Pre-flight non-empty** (`**Gate**`): ≥1 pre-flight command confirming state. Count: __.
- [ ] **Implementation Steps** (Rules): 5–15, dependency-ordered. Count: __.
- [ ] **Each impl has verify** (`**Gate**`): every Implementation Step has a Verification Step.
- [ ] **Rollback** (`**Gate**`): trigger defined + ≥1 rollback step. Missing: __.
- [ ] **Destructive gates** (Rules): every destructive step has dry-run + rollback. Destructive: __.
- [ ] **Drift sync** (`**Drift detection**`): live vs config compared; drift → sync step first.
- [ ] **Design Decisions** (`## Design Decisions`): alternatives considered.
- [ ] **Issue** (Rules): `Issue:` contains a valid `#<number>`. Value: __.
- [ ] **PR Pattern** (`## PR Pattern`): provisional pattern is present, Type is `single`, and all Implementation Steps are assigned. Missing: __.

After drafting, ask "Changes?" then create/link the required issue **before** running the Self-Check. If ALL checked → save, show counts, and hand off for review.

## Review

Checks: requirement measurable, scope explicit, alternatives considered, risks actionable, dry-runs for destructive.

**Gate**: destructive → dry-run, rollback → trigger. Flag: undefined env, missing rollback, no drift sync.

Show: Verdict, Blocking N, Suggestions N. Apply approved plan corrections if requested. On READY, leave `Status: planning` and print: "Plan READY — approve it manually (set `Status: approved`), then run the execute-infra skill." Never set `approved` without the direct human approval record required by README.
