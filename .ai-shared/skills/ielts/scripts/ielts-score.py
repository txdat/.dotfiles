#!/usr/bin/env python3
"""Calculate IELTS bands with exact Decimal arithmetic."""
import argparse
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP, localcontext


def score(value):
    if value == "null":
        return None
    try:
        number = Decimal(value)
    except InvalidOperation:
        raise argparse.ArgumentTypeError("score must be a decimal number or null")
    if not number.is_finite() or not Decimal("0") <= number <= Decimal("9"):
        raise argparse.ArgumentTypeError("score must be finite and between 0 and 9")
    return number


def component(value):
    number = score(value)
    if number is not None and number not in {Decimal(n) / 2 for n in range(19)}:
        raise argparse.ArgumentTypeError("component scores must use half-band steps")
    return number


def half_band(value):
    # Retain every supplied digit before resolving values close to quarter ties.
    with localcontext() as context:
        context.prec = max(28, len(value.as_tuple().digits) + 2)
        return (value * 2).quantize(Decimal("1"), rounding=ROUND_HALF_UP) / 2


parser = argparse.ArgumentParser(
    description="Calculate IELTS bands with exact Decimal arithmetic; print only the result. "
    "Requires python3. No network access or learner records are written."
)
commands = parser.add_subparsers(dest="command", required=True)
half = commands.add_parser("half-band", help="round a score to a half band; quarter ties go up")
half.add_argument("value", type=score, help="decimal score from 0 to 9, or null")
overall = commands.add_parser("overall", help="calculate an overall from L R W S")
overall.add_argument(
    "components", nargs=4, type=component, metavar="SCORE",
    help="exactly four scores in L R W S order, from 0 to 9 in half-band steps; null if missing",
)
args = parser.parse_args()
if args.command == "half-band":
    value = args.value
else:
    value = None if any(value is None for value in args.components) else sum(args.components) / Decimal("4")
print("null" if value is None else format(half_band(value), ".1f"))
