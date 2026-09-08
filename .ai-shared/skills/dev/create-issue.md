# /create-issue — Capture a Standalone Issue

For plan-linked issues, use [design-feature.md](design-feature.md).

Build a specific title and body from the supplied problem, context, and expected outcome. Ask only for missing essentials; apply requested labels and milestone.

Use [PROCESS.md](../../PROCESS.md)'s Git identity rules. Write the exact body to a temporary file, then run [dev-github.sh](../../bin/dev-github.sh) `issue-create <title> <body-file> [gh options]`. Verify the created issue and return its URL.
