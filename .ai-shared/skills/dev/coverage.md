# Coverage Measurement — Single Source

Referenced by CORE gate #6 (thresholds, no-gaming, reason-governs-downward live there) and read by execute-feature/fix-bug at first scoring. Mechanics below; each names its **fallback** for when the stack can't measure what it asks.

- **Branch, not just line, for logic.** On business-logic/domain/service files the branches *are* the behavior (auth, state transitions, money math, validation, retry/idempotency); a red branch is an untested error path, i.e. a future incident. Gate on branch coverage via the table's Branch column. *Fallback where the stack can't (Go is statement-only):* gate line-% and flag each untested branch by name in the Coverage Gap.
- **Curate the denominator.** Exclude generated code, DTOs, serialization boilerplate, migrations, config, and `main`/wiring via the project's coverage config (omit/exclude globs), not by padding with hollow tests. *Fallback where editing that config is out of the step's scope:* don't exclude silently — note the boilerplate lines as excluded-by-reason in the Coverage Gap and score the rest. A meaningful 82% beats a hollow 92%.
- **Line coverage lies under mocks.** For DB/adapter/repository code, a mocked call shows green while the real query/isolation/constraint is wrong. Cover that layer with integration tests against real dependencies (testcontainers). *Fallback where real deps aren't wired into the step:* treat the mocked line-% as unverified — flag it, do not report it as ✅.

Each command reports line/statement %; the **Branch** column is how to get branch coverage for logic files (mechanics above), with its fallback where the stack can't.

| Stack | Command | Branch |
|---|---|---|
| Maven | `mvn test -pl <mod> -Dtest=<Class>` (+ JaCoCo: read `target/site/jacoco/jacoco.csv`) | `BRANCH_COVERED/(BRANCH_MISSED+BRANCH_COVERED)` per class in `jacoco.csv` |
| Go | `go test -run <TestName> -coverprofile=c.out ./<pkg>/... && go tool cover -func=c.out \| grep <changed_file>` | N/A — statement-only; flag untested branches manually |
| Python | `pytest <test_files> -q --cov=<changed_module> --cov-branch --cov-report=term-missing` | `--cov-branch` on; term-missing marks partial branches as `<line>->exit`/`-><target>` |
| JS/TS | `npm test -- <test_file> --coverage \| rg <changed_file>` — single-run via the project's `test` script, never `npx jest`/`jest` directly (bypasses project config); the matched row is `<changed_file>`'s coverage %. Watch-mode script (Vitest default) → append `run`/`--watchAll=false` so it doesn't hang. | read the **% Branch** column of the same table row |
| C++ | `cmake -DCMAKE_CXX_FLAGS=--coverage .. && ctest --test-dir build -R <test>` then `gcov -bn <changed_src>` (GCC) or `llvm-cov report <bin> --sources <changed_src>` (Clang) | GCC: `gcov -b` prints `Taken at least once: N%`; Clang: llvm-cov `Branch` column |
| Rust | `cargo llvm-cov --branch -- <TestName> \| rg <changed_file>` | `--branch` adds a branch-% column (llvm-cov ≥ recent; omit if unsupported → line-% + flag) |

## Closing a gap — behavior-first, never line-first

A red line is a symptom; the unit of testing is a behavior (input class, error path, state transition — a Given/When/Then), never a line. When a file scores ⚠️/❌:

1. Name the behavior each uncovered line/branch belongs to. Can't name one → boilerplate/unreachable: log excluded-by-reason (denominator curation above), don't test it.
2. Behavior already has a plan TC → the test is missing or misaligned: fix *that* test.
3. Behavior has no TC → discovered work, not a free test: log in `## Discovered Scope` and ask. Approved → add the TC (Given/When/Then) to the plan first, then RED→GREEN it like any other. **Tests enter through TCs only.**

**Quality bar (every test):** a test must fail when the behavior it names breaks. Smells that fail it: assert-nothing (runs code, asserts no exception), trivial asserts (not-null, type-only, blanket snapshots), asserting a mock was called instead of the outcome, copying the implementation's expression into the expectation. Such a test raises % while verifying nothing — the mirror of a fake implementation; delete it and log the gap instead.

**Touched-line (patch) coverage** — CORE #6 gates the lines *this change* touched, not the whole file. Where the run emits a coverage XML (`--cov-report=xml`, JaCoCo XML, `llvm-cov --lcov`), get patch granularity with `diff-cover coverage.xml --compare-branch=<base>`. Fallback where no XML/diff-cover: score the whole changed-file % (never the repo-global number).
