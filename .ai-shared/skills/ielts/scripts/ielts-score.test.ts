/** Offline CLI regression tests for the IELTS score utility. */

import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { resolve } from "node:path";

const SCORE = resolve(import.meta.dirname, "ielts-score.ts");

function runScore(...args: string[]) {
  return spawnSync(process.execPath, [SCORE, ...args], { encoding: "utf8", timeout: 10_000 });
}

test("scores round and combine exactly", async (t) => {
  const cases: [string, string[]][] = [
    ["6.5", ["half-band", "6.25"]],
    ["7.0", ["half-band", "6.75"]],
    ["6.0", ["half-band", "6.125"]],
    ["0.5", ["half-band", "0.25"]],
    ["9.0", ["half-band", "8.75"]],
    ["6.0", ["half-band", "6.24999999999999999999999999999"]],
    ["6.5", ["half-band", "6.25000000000000000000000000001"]],
    ["null", ["half-band", "null"]],
    ["0.0", ["half-band", "9e-1000000000"]],
    ["0.0", ["half-band", "0e1000000000"]],
    ["0.0", ["half-band", "-0e-1000000000"]],
    ["7.0", ["overall", "7.5", "7.5", "6.0", "6.0"]],
    ["7.5", ["overall", "8.0", "8.0", "6.5", "6.5"]],
    ["5.0", ["overall", "4.0", "4.5", "5.0", "5.5"]],
    ["0.0", ["overall", "0", "0", "0", "0"]],
    ["9.0", ["overall", "9", "9", "9", "9"]],
    ["null", ["overall", "null", "7", "7", "7"]],
    ["null", ["overall", "7", "null", "7", "7"]],
    ["null", ["overall", "7", "7", "null", "7"]],
    ["null", ["overall", "7", "7", "7", "null"]],
    ["null", ["overall", "null", "null", "null", "null"]],
  ];
  for (const [expected, args] of cases) {
    await t.test(args.join(" "), () => {
      const result = runScore(...args);
      assert.equal(result.status, 0, result.stderr);
      assert.equal(result.stdout, `${expected}\n`);
      assert.equal(result.stderr, "");
    });
  }
});

test("invalid inputs fail without output", async (t) => {
  const cases = [
    ["overall", "7", "7", "7"],
    ["overall", "7", "7", "7", "7", "7"],
    ["overall", "7", "7", "7", "6.25"],
    ["overall", "null", "7", "7", "invalid"],
    ["overall", "7", "7", "7", "-0.5"],
    ["overall", "7", "7", "7", "9.5"],
    ["half-band", "NaN"],
    ["half-band", "Infinity"],
    ["half-band", "invalid"],
    ["half-band", ""],
    ["half-band", "-1"],
    ["half-band", "9.1"],
    ["half-band", "1e1000000000"],
    ["half-band", "-1e1000000000"],
    ["half-band", "-1e-1000000000"],
    ["overall", "7", "7", "7", "1e-1000000000"],
    ["half-band"],
    ["half-band", "6", "7"],
    ["unknown"],
    [],
  ];
  for (const args of cases) {
    await t.test(JSON.stringify(args), () => {
      const result = runScore(...args);
      assert.equal(result.status, 2);
      assert.equal(result.stdout, "");
      assert.match(result.stderr, /error:/);
    });
  }
});

test("help documents every command", async (t) => {
  for (const args of [["--help"], ["half-band", "--help"], ["overall", "--help"]]) {
    await t.test(args.join(" "), () => {
      const result = runScore(...args);
      assert.equal(result.status, 0, result.stderr);
      assert.match(result.stdout, /usage:/);
      assert.equal(result.stderr, "");
    });
  }
});
