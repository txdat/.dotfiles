# Design Feature Examples

Read these when a worked example helps apply [design-feature.md](../design-feature.md). They illustrate the rules; derive each plan's obligations from its own Goal and contracts.

### Example: partial refunds

This abbreviated illustration covers balance behavior; an actual plan derives any other obligations from its own contracts.

```text
Goal: Support partial refunds without refunding more than the captured amount.
AC-1 — a positive refund up to the remaining balance succeeds
  Source: Goal — support partial refunds
  Success: accept the refund and debit exactly its amount
  Failure: reject a valid amount or debit a different amount
AC-2 — a refund above the remaining balance is rejected without changing the ledger
  Source: Goal — never refund more than captured
  Success: reject the refund and leave the ledger unchanged
  Failure: accept the refund or make any ledger change
TC-1 — refund 30 from a remaining 50; accept and leave 20
  Proves: AC-1
  Fixture: captured = 50; prior refunds = []; remaining = 50
  Action: request refund of 30
  Expected: accepted; append one refund of 30; remaining = 20
TC-2 — refund exactly the remaining 20; accept and leave 0
  Proves: AC-1
  Fixture: captured = 50; prior refunds = [30]; remaining = 20
  Action: request refund of 20
  Expected: accepted; refunds = [30, 20]; remaining = 0
TC-3 — after refunding 30 from a captured 50, another 30 is rejected and the ledger stays unchanged
  Proves: AC-2
  Fixture: captured = 50; prior refunds = [30]; remaining = 20
  Action: request another refund of 30
  Expected: rejected; refunds = [30]; remaining = 20; no ledger mutation
```

Rejecting every request satisfies rejection-only tests but violates AC-1. Checking against the original capture instead of the remaining balance fails TC-3. Checking only TC-3's rejection result would miss an erroneous ledger mutation.

### Example: discount ranking ambiguity

“Rank by percentage” leaves open whether the ranked entity is a record, an occurrence, or a `(record, product)` pair. Percentage-only fixtures can hide this difference. Resolve the identity and discount derivation before writing ACs; do not infer them from this example.

Suppose the confirmed contract ranks eligible `(record, product)` pairs by descending `100 × discount amount / product price`, breaking ties by ascending record ID, then product ID. A distinguishing fixture has products A = 100 and B = 200 (same currency, quantity one each), fixed-discount record F = 30 per eligible product, and percentage record P = 20%, both eligible for A and B. Ranking these pairs must yield `[F/A, P/A, P/B, F/B]`, with scores `[30%, 20%, 20%, 15%]`. This fixture exposes reusing one percentage for F across products; a fixture containing only P would not. It does not distinguish pair identity from occurrence identity; if repeated occurrences are relevant, derive a separate fixture for that distinction.
