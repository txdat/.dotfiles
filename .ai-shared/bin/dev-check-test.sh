#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CHECK="$ROOT/bin/dev-check.sh"
TMP=$(mktemp -d /tmp/dev-check-test.XXXXXX)
trap 'rm -rf "$TMP"' EXIT
git -C "$TMP" init -q -b main
git -C "$TMP" config user.email dev-check@example.test
git -C "$TMP" config user.name dev-check-test.sh
mkdir -p "$TMP/tests" "$TMP/src"
printf 'seed\n' > "$TMP/README.md"
git -C "$TMP" add . && git -C "$TMP" commit -qm seed

ok() { (cd "$TMP" && "$CHECK" "$@") >/dev/null || { printf 'FAIL %s\n' "$*"; exit 1; }; printf 'PASS %s\n' "$*"; }
bad() { if (cd "$TMP" && "$CHECK" "$@") >/dev/null 2>&1; then printf 'FAIL expected block: %s\n' "$*"; exit 1; fi; printf 'PASS blocks %s\n' "$*"; }

printf 'assert behavior\n' > "$TMP/tests/unit_test.py"
git -C "$TMP" add . && git -C "$TMP" commit -qm 'test(red): unit'
proof=$(git -C "$TMP" rev-parse HEAD)
ok proof "$proof"

git -C "$TMP" commit --allow-empty -qm 'test(red): empty'
bad proof HEAD
git -C "$TMP" reset -q --hard HEAD~1

printf 'return 1\n' > "$TMP/src/unit.py"
git -C "$TMP" add . && git -C "$TMP" commit -qm 'test(red): bad stub'
bad proof HEAD --stub src/unit.py

git -C "$TMP" reset -q --hard HEAD~1
mkdir -p "$TMP/src"
printf '#[test]\nfn behavior() {}\n' > "$TMP/src/lib.rs"
git -C "$TMP" add . && git -C "$TMP" commit -qm 'test(red): inline rust test'
ok proof HEAD --test src/lib.rs

# --test is the only way past the non-test-path block, so it must be backed by
# test code: declaring a plain implementation file as a test cannot launder it.
git -C "$TMP" reset -q --hard HEAD~1
mkdir -p "$TMP/src"
printf 'def f():\n    return 42\n' > "$TMP/src/impl.py"
git -C "$TMP" add . && git -C "$TMP" commit -qm 'test(red): smuggled impl'
bad proof HEAD --test src/impl.py
bad proof HEAD --stub src/impl.py
bad proof HEAD

git -C "$TMP" reset -q --hard HEAD~1
mkdir -p "$TMP/src"
printf '#[test]\nfn behavior() {}\n' > "$TMP/src/lib.rs"
git -C "$TMP" add . && git -C "$TMP" commit -qm 'test(red): inline rust test again'
ok proof HEAD --test src/lib.rs

# A revised plan's test(update) edits or deletes existing in-source test code.
printf '#[test]\nfn behavior() { assert_eq!(1, 2); }\n' > "$TMP/src/lib.rs"
git -C "$TMP" commit -qam 'test(update): change an inline rust test'
ok proof HEAD --test src/lib.rs
printf 'fn lib() {}\n' > "$TMP/src/lib.rs"
git -C "$TMP" commit -qam 'test(update): delete an inline rust test'
ok proof HEAD --test src/lib.rs
git -C "$TMP" reset -q --hard HEAD~2

# Files past the pipe buffer: rg -q stops reading at its first match.
{ printf '#[cfg(test)]\nmod tests {\n#[test]\nfn behavior() {}\n}\n'; for i in $(seq 2000); do printf '// padding line %d for a file past the pipe buffer\n' "$i"; done; } > "$TMP/src/big.rs"
git -C "$TMP" add . && git -C "$TMP" commit -qm 'test(red): large inline rust test'
ok proof HEAD --test src/big.rs
printf '// edited at the end\n' >> "$TMP/src/big.rs"
git -C "$TMP" commit -qam 'test(update): edit a large inline rust test'
ok proof HEAD --test src/big.rs
git -C "$TMP" reset -q --hard HEAD~2

printf 'fn stub() -> u32 { match 0 { _ => todo!("later") } }\n' > "$TMP/src/stub.rs"
printf 'int Foo() => throw new NotImplementedException();\n' > "$TMP/src/Stub.cs"
git -C "$TMP" add . && git -C "$TMP" commit -qm 'test(red): throwing stubs'
ok proof HEAD --stub src/stub.rs --stub src/Stub.cs

# A body-less stub returns None/null/zero implicitly — no `return` for the
# value-implementation scan to catch, but enough to turn a RED test green.
git -C "$TMP" reset -q --hard HEAD~1
printf 'def apply(tx):\n    pass\n' > "$TMP/src/stub.py"
git -C "$TMP" add . && git -C "$TMP" commit -qm 'test(red): pass stub'
bad proof HEAD --stub src/stub.py

git -C "$TMP" reset -q --hard HEAD~1
printf 'func Apply(tx Tx) Receipt {}\n' > "$TMP/src/stub.go"
git -C "$TMP" add . && git -C "$TMP" commit -qm 'test(red): empty block stub'
bad proof HEAD --stub src/stub.go

git -C "$TMP" reset -q --hard HEAD~1
printf 'def apply(tx):\n    return\n' > "$TMP/src/stub.py"
git -C "$TMP" add . && git -C "$TMP" commit -qm 'test(red): bare return stub'
bad proof HEAD --stub src/stub.py

git -C "$TMP" reset -q --hard HEAD~1
printf 'def apply(tx):\n    raise NotImplementedError\n' > "$TMP/src/stub.py"
git -C "$TMP" add . && git -C "$TMP" commit -qm 'test(red): raising stub'
ok proof HEAD --stub src/stub.py

git -C "$TMP" reset -q --hard "$proof"
scan_base=$(git -C "$TMP" rev-parse HEAD~1)
ok artifacts "$scan_base" HEAD

# Debug-like lines are listed for review-code to judge; they do not block.
mkdir -p "$TMP/src"
printf 'console.log("debug")\n' > "$TMP/src/unit.js"
git -C "$TMP" add . && git -C "$TMP" commit -qm debug
ok artifacts HEAD~1 HEAD
msg=$(cd "$TMP" && "$CHECK" artifacts HEAD~1 HEAD)
[[ "$msg" == *REVIEW*'console.log("debug")'* ]] || { printf 'FAIL debug-like line listed for review\n'; exit 1; }
printf 'PASS debug-like line listed for review\n'

# Conflict markers block, and the report renders newlines.
printf '<<<<<<< ours\na\n=======\nb\n>>>>>>> theirs\n' > "$TMP/src/conflict.txt"
git -C "$TMP" add . && git -C "$TMP" commit -qm conflict
bad artifacts HEAD~1 HEAD
msg=$(cd "$TMP" && "$CHECK" artifacts HEAD~1 HEAD 2>&1 || true)
[[ "$msg" != *'\n'* && "$msg" == *$'\n'*'<<<<<<<'* ]] || { printf 'FAIL block message renders newlines\n'; exit 1; }
printf 'PASS block message renders newlines\n'
git -C "$TMP" revert -n HEAD
git -C "$TMP" commit -qm 'resolve conflict'
ok artifacts HEAD~1 HEAD

# Marker-like text that is not a whole marker does not block.
printf 'Title\n==========\n>>>>>>>>> quoted\n' > "$TMP/src/notes.md"
git -C "$TMP" add . && git -C "$TMP" commit -qm 'marker-like text'
ok artifacts HEAD~1 HEAD

# An unresolvable ref must block, not scan an empty diff and pass.
bad artifacts nonexistent-ref HEAD
bad artifacts HEAD nonexistent-ref
bad artifacts '' HEAD

# `print(` inside a longer identifier is not a debug print.
printf 'pprint(x)\nbuild_blueprint(y)\n' > "$TMP/src/names.py"
git -C "$TMP" add . && git -C "$TMP" commit -qm 'identifiers containing print'
msg=$(cd "$TMP" && "$CHECK" artifacts HEAD~1 HEAD)
[[ "$msg" != *REVIEW* ]] || { printf 'FAIL identifiers containing print are not listed\n'; exit 1; }
printf 'PASS identifiers containing print are not listed\n'

# Scanned code is echoed verbatim: a `\c` must not truncate the report.
printf 'print("a\\cb")\n' > "$TMP/src/escape.py"
git -C "$TMP" add . && git -C "$TMP" commit -qm 'escape in finding'
msg=$(cd "$TMP" && "$CHECK" artifacts HEAD~1 HEAD)
[[ "$msg" == *'a\cb'* ]] || { printf 'FAIL finding printed verbatim\n'; exit 1; }
printf 'PASS finding printed verbatim\n'

# pcs: every PC's Check in one batch.
PLAN="$TMP/pr1.spec.md"
printf 'def gate():\n  pass\n' > "$TMP/src/gate.py"
cat > "$PLAN" <<'PLAN'
# PCs
Status: planning
## Implementation Steps
ST-1 — change — satisfies TC-1
  PC-1 — gate() exists — Check: `grep -q "def gate" src/gate.py` (the definition)
  PC-2 — no caller of old() — Check: ! grep -rq "old(" src
```
  PC-9 — fenced — Check: false
```
## Test Cases
PC-8 — elsewhere — Check: false
PLAN
out=$(cd "$TMP" && "$CHECK" pcs "$PLAN")
[[ "$out" == $'PASS PC-1: grep -q "def gate" src/gate.py\nPASS PC-2: ! grep -rq "old(" src' ]] || { printf 'FAIL pcs: %s\n' "$out"; exit 1; }
printf 'PASS pcs runs each PC Check under Implementation Steps, unwrapping the first backtick span\n'
sed -i '/^## Test Cases/,$d' "$PLAN"
printf '  PC-3 — a missing file — Check: test -f src/missing.py\n  PC-4 — no check\n' >> "$PLAN"
code=0; out=$(cd "$TMP" && "$CHECK" pcs "$PLAN") || code=$?
[[ "$code" == 1 && "$out" == *'FAIL PC-3 (exit 1): test -f src/missing.py'* && "$out" == *'FAIL PC-4: no Check command'* ]] || { printf 'FAIL pcs failures: %s %s\n' "$code" "$out"; exit 1; }
printf 'PASS pcs reports each failing or missing Check and exits 1\n'
out=$(cd / && "$CHECK" pcs "$PLAN" --cwd "$TMP" PC-1)
[[ "$out" == 'PASS PC-1: grep -q "def gate" src/gate.py' ]] || { printf 'FAIL pcs --cwd and filter: %s\n' "$out"; exit 1; }
printf 'PASS pcs runs in --cwd and only the PCs named\n'
bad pcs "$PLAN" PC-7
code=0; out=$(cd "$TMP" && "$CHECK" pcs "$PLAN" PC-1 PC-7) || code=$?
[[ "$code" == 1 && "$out" == *'FAIL PC-7: not in'* ]] || { printf 'FAIL pcs unknown ID: %s %s\n' "$code" "$out"; exit 1; }
printf 'PASS pcs fails a named PC that is not in the plan\n'
STDIN_PLAN="$TMP/pr2.spec.md"
printf '# S\nStatus: planning\n## Implementation Steps\n  PC-1 — reads input — Check: `cat >/dev/null`\n  PC-2 — fails — Check: false\n' > "$STDIN_PLAN"
code=0; out=$(cd "$TMP" && "$CHECK" pcs "$STDIN_PLAN") || code=$?
[[ "$code" == 1 && "$out" == *'FAIL PC-2'* ]] || { printf 'FAIL pcs stdin: %s %s\n' "$code" "$out"; exit 1; }
printf 'PASS a Check that reads its input does not swallow later PCs\n'
[[ "$("$CHECK" pcs "$TMP/README.md")" == "PASS no PCs" ]] || { printf 'FAIL pcs without PCs\n'; exit 1; }
printf 'PASS pcs passes a plan without PCs\n'
bad pcs "$TMP/README.md" PC-1
bad pcs "$PLAN" --cwd "$TMP/nowhere"

printf 'All dev-check.sh tests passed.\n'
