# Artifact IDs

Owns the identifiers written into application plans (`docs/plans/`), infrastructure runbooks (`docs/runbooks/`), and architecture documents (`docs/architecture/`). Each artifact's design skill owns its other content. [gate-check](../../bin/gate-check) parses IDs exactly as defined here: in the named plan at review-feature and review-code, and in a named runbook or architecture document at review-infra and review-system.

## Format

- An ID is `<PREFIX>-<n>`: a two-letter prefix from the registry below, a hyphen, and a positive integer without leading zeros, such as `AC-1`, `ST-12`, `PH-3`.
- IDs are unique per prefix within one artifact. Number new items after the highest ID that prefix has ever used in the artifact; never renumber or reuse a retired ID.
- Cite every ID explicitly. Ranges such as `TC-1 to TC-4` or `AC-1–AC-3` are invalid; write `TC-1, TC-2, TC-3, TC-4`.
- An application plan cites only its own IDs. It cites a contract or other artifact by path without its IDs, and restates a fact another artifact establishes as a `PC-n` precondition ([related plans — Order](reference/related-plans.md#order)). A runbook or architecture document may cite another artifact's ID path-qualified, such as `docs/architecture/<file>.md#CT-1`. A `#`-qualified ID is not checked against the citing artifact.
- Old forms are invalid where the ID now lives: `Step 1`, `Slice 1`, or `Precondition:` in `## Implementation Steps` or `## PR Pattern`, `Phase 1` in `## Phases` or `## Migration`, and numbered PR or Publication Inventory rows. Elsewhere, "step 1 of the wizard" is prose.

## Declaration and reference

An ID is **declared** by a line in its owning section (below) that begins with the ID, after optional indentation and one optional list marker (`-`, `*`), heading marker (`#`…), or table-cell opener (`|`). Every other occurrence is a **reference**. A section is matched by its `##` heading, ignoring a trailing parenthetical such as `(intent)` or `(provisional)`.

Text inside fenced code blocks (```` ``` ```` or `~~~`) is neither a declaration nor a reference, so keep declaring lines such as `### PH-1 — <outcome>` outside fences and fence only commands and data. Skill templates are fenced for display; write their lines unfenced in the artifact.

Every unqualified reference must name an ID declared in the same artifact, except inside a runbook's `## Execution Record`, which may mention retired IDs and quote old ranges.

A plan's IDs must also close as a graph, whose rules [design-feature.md — ID graph](design-feature.md#id-graph) owns.

The gate checks the rules above and the graph's shape only; it detects a cross-reference by its `<path>#ID` form, so an unqualified ID borrowed from another plan, like renumbering or reuse of a retired ID, remains review judgment.

## Registry

The ID line shows where an ID is declared and which IDs it must cite; `…` is content its owner defines.

### Application plan

| Prefix | Item | Owning section | Content owner | ID line |
|---|---|---|---|---|
| `AC` | Acceptance criterion | `## Acceptance Criteria` | design-feature | `AC-1 — …` |
| `TC` | Test case | `## Test Cases` | design-feature | `TC-1 — …`; `Proves:` names one AC; `Fixture:` may name an FX |
| `FX` | Shared test fixture | `## Test Fixtures` | design-feature | `FX-1 — …` |
| `ST` | Implementation step | `## Implementation Steps` | design-feature | `ST-1 — … — satisfies TC-1` |
| `PC` | Step precondition | `## Implementation Steps`, indented under its step | design-feature; execute-feature records its result | `PC-1 — …` |
| `PR` | PR slice | `## PR Pattern` table, first column | design-feature; review-code finalizes | `\| PR-1 \| … \| ST-1, ST-2 \| … \|`, steps in the `Steps` column |
| `DD` | Design decision | `## Design Decisions` | design-feature, frame-goal | `DD-1 — …` |
| `RK` | Open risk | `## Open Risks` | design-feature | `RK-1 — … — TC-2` |
| `DS` | Discovered scope | `## Discovered Scope` | execute-feature, under [plan.md — Changes](plan.md#changes) | `DS-1 — …` |
| `CG` | Coverage gap | `## Coverage Gaps` | verification | `CG-1 — …` |

Records that cite a slice use its PR ID: [plan.md](plan.md#worktree-operations)'s Publication Inventory and [review-code.md](review-code.md#finalize-during-authorized-delivery)'s green records own their line forms.

### Infrastructure runbook

| Prefix | Item | Owning section | Content owner | ID line |
|---|---|---|---|---|
| `SC` | Success criterion | `## Success Criteria` | design-infra | `SC-1 — …` |
| `CL` | Live-state claim and its evidence | `## Evidence` | design-infra | `CL-1 — …` |
| `RS` | Affected resource or workload | `## Resources` | design-infra | `RS-1 — …` |
| `PH` | Phase | `## Phases` | design-infra | `### PH-1 — …` |
| `OQ` | Open question | `## Open Questions` | design-infra | `OQ-1 — … — blocks PH-2` |
| `EX` | Execution record entry | `## Execution Record` | review-infra (post) | `EX-1 — …`, citing the `PH-n` that ran |

### Architecture document

| Prefix | Item | Owning section | Content owner | ID line |
|---|---|---|---|---|
| `SC` | Measurable success criterion | `## Goal and Constraints` | design-system | `SC-1 — …`, citing the `PH-n` that establishes a missing baseline |
| `OP` | Option | `## Options` | design-system | `OP-1 — …`; the recommendation cites one |
| `CT` | Changed contract | `## Contracts` | design-system | `CT-1 — …` |
| `PH` | Migration phase | `## Migration` | design-system | `### PH-1 — …` |
| `DC` | Decomposition entry | `## Decomposition` | design-system | `DC-1 — … — CT-1 — …` |

Prefixes outside an artifact's table are not parsed there; cite another artifact's IDs only as [Format](#format) allows. Items not listed here, such as header fields and prose sections, carry no ID.
