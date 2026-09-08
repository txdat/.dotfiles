# IELTS Shared Rules

These coaching skills target IELTS Academic. Flag material from another module before scoring or saving; do not silently relabel it. Match the requested depth using evidence → effect → a manageable next action. Focused questions do not require full reviews.

## Evidence

Use these tags at score/table/record level, with the source reference:

| Tag | Basis |
|---|---|
| `source_of_truth` | Inspected official descriptor, key, or score report |
| `confirmed_decision` | Learner-reported result or identified human review |
| `model_inference` | AI assessment, proposed answer, approximation, or self-estimate |
| `case_file_claim` | Statement in supplied material, not an official answer |
| `open_verification` | Unresolved or conflicting evidence |

Historical `private_working_note` and `team_shared_record` tags may be retained for drafts and identified shared study records. An official rubric never makes an AI assessment official. Preserve conflicting supplied scores and their assessors rather than averaging away disagreements; criterion differences of 0.5 or more belong in `open_verifications`.

Keep diagnosis certainty separate: `observed` requires a located mismatch; `possible-cause` needs a proposed discriminating check; `confirmed-by-learner` records what the learner says they heard, understood, or did. A wrong answer alone does not establish its mental cause or a lasting weakness. Use precise evidence-supported error tags, leaving an unsupported tag `null` and hypotheses out of confirmed totals.

## Scoring

[IELTS scoring reference](https://ielts.org/take-a-test/your-results/ielts-scoring-in-detail), previously checked 2026-09-05. Use [rubric.md](rubric.md) for Writing/Speaking assessment and target-band guidance.

Use [ielts-score.py](scripts/ielts-score.py) for arithmetic (`--help` lists commands). Exam overall is calculated only from four known L/R/W/S components: `overall <L> <R> <W> <S>`, with literal `null` for missing values. Bands are 0–9 in half steps; zero is not missing. Retain the Decimal mean until final half-band rounding, with quarter ties upward. Preserve reported overall separately if it differs.

Writing tasks have equally weighted criteria; combine both task means with Task 2 weighted twice. A single essay yields only an estimated task band, not a complete Writing component. Rubric.md owns evidence limits for incomplete tasks and transcripts. AI rewrites are demonstrations, not learner performance gains.

Reading/Listening parts yield raw correct/total counts, not bands. Missing keys or unresolved marking make counts provisional. For a complete test, prefer its verified conversion table. The official approximate anchors below vary by test version; do not interpolate half-band cutoffs or overrule an official report with them.

| Band | Listening /40 | Academic Reading /40 |
|---|---|---|
| 5 | 16 | 15 |
| 6 | 23 | 23 |
| 7 | 30 | 30 |
| 8 | 35 | 35 |

## Saving

Explicit Writing review, Speaking transcript review, Listening analysis, and Mock recording authorize a new archive unless the learner says not to save. Reading analysis, generated materials, and drills save only on request. Casual questions and planning stay in conversation. Reviewing these skill files does not authorize learner records.

When saving, load [archive.md](archive.md) for all paths, schemas, and write rules. Otherwise no archive template is needed.
