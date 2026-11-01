# /design-system — Architecture Design

Use for changed service boundaries, communication patterns, or cross-system integrations; ordinary features use [design-feature.md](design-feature.md). Assess impact under [CODING.md — Impact](../../CODING.md#impact).

Write `docs/architecture/<issue>_<slug>.html` with `Status: draft`, in the language [plan.md — Artifact](plan.md#artifact) prescribes, with these sections:

- **`Goal and Constraints`:** current pain, affected boundaries, and each measurable success criterion as `SC-n`, with its baseline or the `PH-n` that establishes it.
- **`Options`:** each viable choice as `OP-n`, compared against the same constraints, including a simpler starting system. Cite the recommended one and justify its complexity by current needs. Diagram the current system's components as a `flowchart` before `OP-1`, and the recommended option's under it.
- **`Contracts`:** each changed contract as `CT-n`: owner, data and call flow, compatibility, delivery and failure semantics. Account for actual consumers. Give each contract with calls or messages a `sequenceDiagram`, including its failure paths.
- **`Migration`** (when needed): ordered `PH-n — <outcome>` phases, each with its change, verification gate, rollback and its limits. Cover synchronization, cutover, and reconciliation where relevant; mark irreversible steps.
- **`Decomposition`:** `DC-n — <future plan> — CT-n — <obligation> — stacks on DC-k|root` entries assigning every changed contract to a future application plan, with the observable obligation and how its TCs will verify it. Where a contract crosses plans, list the producer plan first; the consumer stacks on it. Diagram exactly those `stacks on` edges as a `flowchart` of `DC-n` nodes, producer `-->` consumer.

## Format

Write one HTML file, optionally with inline `<style>`, loading nothing but the Mermaid import shown; diagrams need network access to render:

```html
<!doctype html>
<html lang="{language code}"><head><meta charset="utf-8"><title>{title}</title></head><body>
<h1>{title}</h1>
<p>Status: draft</p>
<h2>Contracts</h2>
<h3 id="CT-1">CT-1 — {contract}</h3>
<pre class="mermaid">sequenceDiagram
  Client->>Orders: POST /orders</pre>
<script type="module">import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@latest/dist/mermaid.esm.min.mjs";</script>
</body></html>
```

- Each section is an `<h2>` named as above; `Status: <status>` is the whole text of its own `<p>`.
- `OP-n`, `CT-n`, and `PH-n` start their own `<h3>`; `SC-n` and `DC-n` start their own `<li>`. Each element carries its ID as `id`; cite another artifact's as `<a href="<path>#ID">`.
- A diagram shows only what its text states. Open each with exactly `<pre class="mermaid">`. In its source, write `<` as `#lt;` and `&` as `#amp;`, never as raw characters or HTML entities.
- Render each diagram, numbered from 1 in document order, by piping its source unchanged to `mmdc -i - -o /tmp/<slug>-<n>.svg`; a nonzero exit is a rejection. Fix every rejected diagram.

Finish when the recommendation meets the constraints, every contract has an owner, and migration and decomposition can deliver the measured outcome. Hand off to [review-system.md](review-system.md). Feature plans start only after the user sets `Status: approved`. An approved document is frozen: a needed change goes to the user with options and a recommendation, then back to `draft`, review, and approval.
