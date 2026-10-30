/** Calculate IELTS bands with exact integer arithmetic; print only the result. */

type Rational = { num: bigint; den: bigint };

const PROGRAM = "ielts-score.ts";

const TOP_USAGE = `usage: ${PROGRAM} [-h] {half-band,overall} ...`;
const HALF_USAGE = `usage: ${PROGRAM} half-band [-h] value`;
const OVERALL_USAGE = `usage: ${PROGRAM} overall [-h] SCORE SCORE SCORE SCORE`;

const TOP_HELP = `${TOP_USAGE}

Calculate IELTS bands with exact arithmetic; print only the result. Requires
Node 22.18+. No network access or learner records are written.

positional arguments:
  {half-band,overall}
    half-band         round a score to a half band; quarter ties go up
    overall           calculate an overall from L R W S

options:
  -h, --help          show this help message and exit
`;

const HALF_HELP = `${HALF_USAGE}

round a score to a half band; quarter ties go up

positional arguments:
  value       decimal score from 0 to 9, or null

options:
  -h, --help  show this help message and exit
`;

const OVERALL_HELP = `${OVERALL_USAGE}

calculate an overall from L R W S

positional arguments:
  SCORE       exactly four scores in L R W S order, from 0 to 9 in half-band
              steps; null if missing

options:
  -h, --help  show this help message and exit
`;

// Decimal syntax: optional sign, digits with an optional fraction, optional exponent.
const DECIMAL = /^[+-]?\d*(?:\.\d*)?(?:[eE][+-]?\d+)?$/;
const PARTS = /^([+-]?)(\d*)(?:\.(\d*))?(?:[eE]([+-]?\d+))?$/;

// Nonzero values below 10^-TINY_DIGITS cannot affect rounding; clamping them keeps
// 10n ** shift small for exponents like 9e-1000000000 while staying nonzero.
const TINY_DIGITS = 64n;

function parseScore(raw: string): Rational | null {
  if (raw === "null") return null;
  const text = raw.trim().replaceAll("_", "");
  if (!DECIMAL.test(text) || !/\d/.test(text)) {
    throw new Error("score must be a decimal number or null");
  }
  const [, sign, whole, fraction = "", exponent = "0"] = PARTS.exec(text) as RegExpExecArray;
  const digits = BigInt(`${whole}${fraction}`);
  if (digits === 0n) return { num: 0n, den: 1n };
  const shift = BigInt(exponent) - BigInt(fraction.length);
  // The value lies in [10^(magnitude - 1), 10^magnitude); check range before any power.
  const magnitude = BigInt(digits.toString().length) + shift;
  if (sign === "-" || magnitude > 1n) {
    throw new Error("score must be finite and between 0 and 9");
  }
  if (magnitude < -TINY_DIGITS) return { num: 1n, den: 10n ** (TINY_DIGITS + 1n) };
  const num = digits * (shift > 0n ? 10n ** shift : 1n);
  const den = shift < 0n ? 10n ** -shift : 1n;
  if (num > 9n * den) {
    throw new Error("score must be finite and between 0 and 9");
  }
  return { num, den };
}

function parseComponent(raw: string): Rational | null {
  const value = parseScore(raw);
  if (value !== null && (value.num * 2n) % value.den !== 0n) {
    throw new Error("component scores must use half-band steps");
  }
  return value;
}

/** Round half a band upward at quarter ties; value is non-negative. */
function formatHalfBand(value: Rational): string {
  const halves = (4n * value.num + value.den) / (2n * value.den);
  return `${halves / 2n}.${halves % 2n === 0n ? "0" : "5"}`;
}

function formatOverall(components: (Rational | null)[]): string {
  if (components.some((value) => value === null)) return "null";
  let doubled = 0n;
  for (const value of components) {
    const component = value as Rational;
    doubled += (2n * component.num) / component.den;
  }
  return formatHalfBand({ num: doubled, den: 8n });
}

function exitWithError(usage: string, message: string): never {
  process.stderr.write(`${usage}\n${PROGRAM}: error: ${message}\n`);
  process.exit(2);
}

function messageOf(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

function printAndExit(text: string): never {
  process.stdout.write(text);
  process.exit(0);
}

const [command, ...rest] = process.argv.slice(2);

if (command === undefined) {
  exitWithError(TOP_USAGE, "the following arguments are required: command");
}
if (command === "-h" || command === "--help") printAndExit(TOP_HELP);
if (command !== "half-band" && command !== "overall") {
  exitWithError(
    TOP_USAGE,
    `argument command: invalid choice: '${command}' (choose from 'half-band', 'overall')`,
  );
}

const usage = command === "half-band" ? HALF_USAGE : OVERALL_USAGE;
const help = command === "half-band" ? HALF_HELP : OVERALL_HELP;
if (rest.includes("-h") || rest.includes("--help")) printAndExit(help);

if (command === "half-band") {
  if (rest.length === 0) {
    exitWithError(usage, "the following arguments are required: value");
  }
  if (rest.length > 1) {
    exitWithError(usage, `unrecognized arguments: ${rest.slice(1).join(" ")}`);
  }
  try {
    const value = parseScore(rest[0]);
    process.stdout.write(`${value === null ? "null" : formatHalfBand(value)}\n`);
  } catch (error) {
    exitWithError(usage, messageOf(error));
  }
} else {
  if (rest.length < 4) {
    exitWithError(usage, "the following arguments are required: components");
  }
  if (rest.length > 4) {
    exitWithError(usage, `unrecognized arguments: ${rest.slice(4).join(" ")}`);
  }
  try {
    process.stdout.write(`${formatOverall(rest.map(parseComponent))}\n`);
  } catch (error) {
    exitWithError(usage, messageOf(error));
  }
}
