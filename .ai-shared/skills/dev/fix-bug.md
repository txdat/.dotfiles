# /fix-bug — Diagnose and Route a Fix

Use `fix-bug <symptom>` for read-only diagnosis and routing; this skill edits nothing. A requested fix follows the route at the end.

Read [CODING.md](../../CODING.md) and project configuration. Establish expected behavior, actual behavior, reproduction, and any tracking issue. For planless comparisons, use [PROCESS.md](../../PROCESS.md)'s diagnostic base rule.

Rank plausible causes and test the strongest with focused, read-only evidence. Report the supported failure mechanism, affected paths, and proposed regression scenario. If reproduction or causality remains uncertain, name the next discriminating check rather than inventing a fix.

Route a requested fix: an existing approved fix plan goes to [execute-feature.md](execute-feature.md); a requested plan-backed fix starts at [design-feature.md](design-feature.md) with `Type: fix`; any other fix is a direct edit under [AGENTS.md — Work](../../AGENTS.md#work).
