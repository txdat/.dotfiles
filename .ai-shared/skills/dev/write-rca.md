# /write-rca - RCA / Incident Report

Modes: `<issue/pr/sha...>` writes a draft from GitHub/code evidence; `from-notes <title>` writes from pasted notes; `revise <path>` tightens an existing RCA. If no primary source is provided, ask for one issue, PR, commit, or notes blob.

Purpose: produce an evidence-backed incident report from issues and PRs. Do not fix code. Do not mutate GitHub. Local file writes only.

## Source Intake

Normalize inputs into a source ledger:
```
S1 issue #123 "title" <url>
S2 pr #456 "title" <url>
S3 commit abc1234 "summary"
S4 notes "pasted incident notes"
```

Fetch what is available:
```bash
gh issue view <id-or-url> --comments --json number,title,state,author,body,comments,labels,createdAt,closedAt,url
gh pr view <id-or-url> --comments --json number,title,state,author,body,comments,reviews,commits,files,createdAt,mergedAt,url
git show --stat --oneline <sha>
git show --name-only <sha>
```

Discover bounded related sources: scan fetched bodies/comments/reviews/commit messages for issue numbers, PR numbers, URLs, and commit SHAs that appear to be part of the incident, mitigation, or fix. Fetch those too. Do not expand into unrelated cleanup, follow-up feature work, or broad repository history.

If a source cannot be fetched, keep it in the ledger as `UNREADABLE` with the command error. If sources are pasted, treat the pasted text as the source of record. Use `rg -n "<error|service|ticket|symbol>" .` only when source text points to specific local code or logs worth verifying.

## Evidence Discipline

Classify every important claim:
- `FACT`: directly supported by a cited source.
- `INFERENCE`: derived from facts; include the reasoning.
- `UNKNOWN`: required for a complete RCA but absent.

Root cause can be `Confirmed` only when all are present:
- Failure mode: what broke.
- Impact link: how the failure affected users, systems, jobs, or data.
- Causal mechanism: the specific code/config/data/process condition that produced the failure.
- Fix or mitigation link: evidence that mitigation or the fix addressed that mechanism.

Otherwise write `Root cause: Not confirmed` and list missing evidence. PR descriptions can explain the fix, but they do not prove customer impact, incident timing, or detection path by themselves.

Never invent severity, start/end time, customer impact, owners, due dates, alert names, or exact causality. Prefer `UNKNOWN` over polished speculation.

## Procedure

1. Read sources and assign stable `S#` IDs. Preserve source URLs or commit SHAs.
2. Extract candidate facts into four buckets: impact, timeline, cause/fix, actions.
3. Build the timeline from source timestamps: issue/comment creation, PR creation/merge, commits, CI, alerts, pasted log times. Convert relative dates to absolute dates when the source timestamp allows it; otherwise keep `UNKNOWN timezone`.
4. Reconstruct the failure chain:
   ```
   trigger -> faulty condition -> observed failure -> impact -> mitigation -> permanent fix
   ```
5. Decide confidence: `Confirmed`, `Partial`, or `Insufficient Evidence`.
6. Write a draft report under `docs/incidents/<yyyy-mm-dd>_<slug>.md`. Use incident start date when known; otherwise use current local date.
7. If revising an existing RCA, preserve useful facts and source IDs, remove unsupported certainty, and add missing `UNKNOWN` items instead of deleting gaps silently.

## Report Template

```md
# RCA: <incident title>

Status: Draft
Confidence: <Confirmed|Partial|Insufficient Evidence>
Severity: <value or UNKNOWN>
Incident window: <start> to <end> (<timezone>) or UNKNOWN

## Sources
| ID | Type | Reference | Notes |
|---|---|---|---|
| S1 | Issue | #123 <url> | <why relevant> |

## Executive Summary
<2-4 short paragraphs. State what happened, impact, cause confidence, and current fix status. Mark unsupported material as UNKNOWN.>

## Impact
- <FACT|INFERENCE|UNKNOWN>: <affected users/systems/jobs/data, duration, scale, business effect> (<S#>)

## Timeline
| Time | Type | Event | Source |
|---|---|---|---|
| <timestamp> | FACT | <event> | <S#> |

## Root Cause
Root cause: <confirmed cause, or "Not confirmed">
Confidence: <Confirmed|Partial|Insufficient Evidence>

Evidence:
- <FACT>: <supporting evidence> (<S#>)

Missing evidence:
- <UNKNOWN>: <what is needed to confirm or reject the cause>

## Contributing Factors
- <FACT|INFERENCE>: <factor> (<S# or rationale>)

## Detection and Response
- Detection: <FACT|UNKNOWN>: <how it was detected> (<S#>)
- Mitigation: <FACT|UNKNOWN>: <what restored service> (<S#>)
- Resolution: <FACT|UNKNOWN>: <permanent fix or remaining state> (<S#>)

## Corrective Actions
| Action | Owner | Due | Source |
|---|---|---|---|
| <specific action> | <owner or UNKNOWN> | <date or UNKNOWN> | <S# or UNKNOWN> |

## Open Questions
- <UNKNOWN>: <question> - why it matters
```

## Quality Bar

- Cite every factual timeline, impact, cause, and action item with `S#`.
- Separate trigger, root cause, contributing factors, and fix.
- Use neutral language: systems and decisions failed, not people.
- Keep the executive summary readable for non-implementers.
- Keep the timeline factual, timestamped, and ordered.
- Include PR fix details, but do not let the fix description replace incident analysis.
- End with useful gaps: what evidence would turn `UNKNOWN` or `Partial` into `Confirmed`.

Print: report path, sources read/unreadable, confidence, `UNKNOWN` count, action item count.
