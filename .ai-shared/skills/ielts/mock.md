# /ielts-mock — Record Results

Read [README.md](README.md) for source tags, scoring, and saving. Record supplied full or partial results without inferring proficiency or missing component scores.

Identify exam/practice/partial entry, date (today if absent), source/test, available L/R/W/S scores and their sources, plus supplied raw counts, reported overall, conditions, and notes. Validate component bands using the shared scoring rules and full-test raw counts as integers 0–40. Ask about invalid entries without clipping values.

Distinguish an inspected official report from learner-reported scores, human review, AI assessment, and self-estimate. A single essay or text-only speaking assessment is not a complete component result.

Run the shared score helper with four components, using `null` for missing values. Its calculated overall inherits the least certain input: unresolved conflict, then inference, then human confirmation, then inspected official evidence. Missing components leave it null. Preserve reported overall separately and flag disagreement.

Retain raw counts and reported bands when a test-specific conversion is unavailable; generic anchors cannot invalidate an official report. Show the component/source table, calculated result or why it is unavailable, and pending verification. Save under the shared archive rules. Recording can finish with uncertainty preserved; scores alone do not justify error diagnoses or weak-topic claims.
