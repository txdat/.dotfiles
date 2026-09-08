# /fix-bug — Diagnose and Route a Fix

Use `fix-bug <symptom>` for read-only diagnosis and routing. Implementation belongs to `execute-feature <plan-path>`.

Read [CODING.md](../../CODING.md) and project configuration. Establish expected behavior, actual behavior, reproduction, and the tracking issue. For planless comparisons, use [PROCESS.md](../../PROCESS.md)'s diagnostic base rule.

Rank plausible causes and test the strongest with focused, read-only evidence. Report the supported failure mechanism, affected paths, and proposed regression scenario. If reproduction or causality remains uncertain, name the next discriminating check rather than inventing a fix.

When a fix is requested, use [design-feature.md](design-feature.md) with `Type: fix`, then follow the delivery process. An existing approved fix plan goes to [execute-feature.md](execute-feature.md).
