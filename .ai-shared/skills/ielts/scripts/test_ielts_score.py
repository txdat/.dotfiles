#!/usr/bin/env python3
"""Offline CLI regression tests for the IELTS score utility."""

from pathlib import Path
import subprocess
import sys
import unittest


SCORE = Path(__file__).with_name("ielts-score.py")


class ScoreTest(unittest.TestCase):
    def run_score(self, *args):
        return subprocess.run(
            [sys.executable, str(SCORE), *args],
            capture_output=True, text=True, timeout=10,
        )

    def test_scores(self):
        cases = [
            ("6.5", ["half-band", "6.25"]),
            ("7.0", ["half-band", "6.75"]),
            ("6.0", ["half-band", "6.125"]),
            ("0.5", ["half-band", "0.25"]),
            ("9.0", ["half-band", "8.75"]),
            ("6.0", ["half-band", "6.24999999999999999999999999999"]),
            ("6.5", ["half-band", "6.25000000000000000000000000001"]),
            ("null", ["half-band", "null"]),
            ("7.0", ["overall", "7.5", "7.5", "6.0", "6.0"]),
            ("7.5", ["overall", "8.0", "8.0", "6.5", "6.5"]),
            ("5.0", ["overall", "4.0", "4.5", "5.0", "5.5"]),
            ("0.0", ["overall", "0", "0", "0", "0"]),
            ("9.0", ["overall", "9", "9", "9", "9"]),
            ("null", ["overall", "null", "7", "7", "7"]),
            ("null", ["overall", "7", "null", "7", "7"]),
            ("null", ["overall", "7", "7", "null", "7"]),
            ("null", ["overall", "7", "7", "7", "null"]),
            ("null", ["overall", "null", "null", "null", "null"]),
        ]
        for expected, args in cases:
            with self.subTest(args=args):
                result = self.run_score(*args)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, expected + "\n")
                self.assertEqual(result.stderr, "")

    def test_invalid_inputs(self):
        cases = [
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
            ["half-band"],
            ["half-band", "6", "7"],
            ["unknown"],
            [],
        ]
        for args in cases:
            with self.subTest(args=args):
                result = self.run_score(*args)
                self.assertEqual(result.returncode, 2)
                self.assertEqual(result.stdout, "")
                self.assertIn("error:", result.stderr)

    def test_help(self):
        for args in (["--help"], ["half-band", "--help"], ["overall", "--help"]):
            with self.subTest(args=args):
                result = self.run_score(*args)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("usage:", result.stdout)
                self.assertEqual(result.stderr, "")


if __name__ == "__main__":
    unittest.main()
