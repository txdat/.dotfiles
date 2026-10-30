/**
 * dev-stack.ts — Pi port of the Claude Code dev-stack plugin
 * (.claude/marketplace/plugins/dev-stack): /dev-stack-* commands over
 * .ai-shared/bin/dev-stack.sh for a stack of plans (skills/dev/plan.md).
 *
 * `next`, `stack`, and `check` only read. `review`, `stop`, and `resume` record
 * a decision of the user's, so each waits for the turn to end before it runs: a
 * running turn reads the plan and the stack's stops.log. Pi treats a submitted
 * command as the user's own, so the Claude plugin's origin check has no
 * equivalent here; only an extension that dispatches these commands itself
 * (sendUserMessage with expandPromptTemplates) can bypass that intent.
 */

import * as os from "node:os";
import * as path from "node:path";
import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";

const HOME = os.homedir();
const STACK = path.join(HOME, ".dotfiles", ".ai-shared", "bin", "dev-stack.sh");

type Sub = "next" | "stack" | "check" | "review" | "stop" | "resume";

type Parsed = { argv: [sub: Sub, plan: string, ...rest: string[]] } | { usage: true };

type Command = {
  name: string;
  description: string;
  argumentHint: string;
  parse: (text: string) => Parsed;
  // Set for a write: what the model reads after it succeeds, so a later
  // run-stack turn knows of the user's decision.
  write?: { note: (argv: string[]) => string };
};

// Every plan path ends in .spec.md, so anything else, such as an unknown
// trailing flag, is a usage error. A plan path with spaces stays whole.
const isPlan = (text: string) => /\.spec\.md$/.test(text);
const PLAN_THEN_REST = /^(.*?\.spec\.md)(?:\s+(.*))?$/s;

const escapeRegExp = (text: string) => text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

const plansRoot = () =>
  (process.env["AI_PLANS_ROOT"] || path.join(HOME, "work", "plans")).replace(/\/+$/, "");

// The output shows plan paths relative to the plans root, so one typed as shown
// is read back from there. A leading @ is the prompt's file mention, not part of the path.
const absolute = (text: string, root: string) => {
  const file = text.replace(/^@/, "");
  return /^[/~]/.test(file) ? file : `${root}/${file}`;
};

const planOnly =
  (sub: Sub) =>
  (text: string): Parsed =>
    isPlan(text) ? { argv: [sub, text] } : { usage: true };

const COMMANDS: Command[] = [
  {
    name: "dev-stack-next",
    description: "Show each plan's next action in a stack (dev-stack.sh next)",
    argumentHint: "<root spec file> [--tab|--tree|--md]",
    parse: (text) => {
      // A trailing view flag; dev-stack.sh defaults to --tab, its tab-separated rows.
      const VIEW = /(?:^|\s)(--tab|--tree|--md)$/;
      const view = text.match(VIEW)?.[1];
      const spec = text.replace(VIEW, "").trim();
      if (!isPlan(spec)) return { usage: true };
      return { argv: view ? ["next", spec, view] : ["next", spec] };
    },
  },
  {
    name: "dev-stack-list",
    description: "List a stack's plans, parents first (dev-stack.sh stack)",
    argumentHint: "<root spec file>",
    parse: planOnly("stack"),
  },
  {
    name: "dev-stack-check",
    description:
      "Run the review-feature gate on every plan in a stack, minus the parent check (dev-stack.sh check)",
    argumentHint: "<root spec file>",
    parse: planOnly("check"),
  },
  {
    name: "dev-stack-review",
    description: "Record a review-feature verdict on a plan (dev-stack.sh review)",
    argumentHint: "<spec file> ready|needs-changes",
    parse: (text) => {
      const [, plan, verdict] = text.match(/^(.*\S)\s+(ready|needs-changes)$/s) ?? [];
      return plan && verdict && isPlan(plan) ? { argv: ["review", plan, verdict] } : { usage: true };
    },
    write: {
      note: ([, plan, verdict]) =>
        `The user recorded the review-feature verdict ${verdict} on ${plan} with dev-stack.sh review.`,
    },
  },
  {
    name: "dev-stack-stop",
    description: "Record why a plan stopped in its stack's stops.log (dev-stack.sh stop)",
    argumentHint: "<spec file> <reason>",
    parse: (text) => {
      const [, plan, reason] = text.match(PLAN_THEN_REST) ?? [];
      return plan && reason?.trim() ? { argv: ["stop", plan, reason.trim()] } : { usage: true };
    },
    write: {
      note: ([, plan, reason]) => `The user stopped ${plan} with dev-stack.sh stop: ${reason}`,
    },
  },
  {
    name: "dev-stack-resume",
    description: "Clear a plan's stop so run-stack continues it (dev-stack.sh resume; only the user runs it)",
    argumentHint: "<spec file>",
    parse: planOnly("resume"),
    write: {
      note: ([, plan]) =>
        `The user cleared the stop on ${plan} with dev-stack.sh resume; for a "Failed fixes: 3/3" stop this grants three more attempts.`,
    },
  },
];

/**
 * Plan paths show relative to the plans root, as dev-plan-lib.sh resolves it.
 * The format hint in "Plan must be ~/work/plans/<repo>/<issue>_..." keeps its
 * prefix: it names the repository or <repo>, never a plan, so a path followed
 * by <issue> is left whole.
 */
function shorten(text: string, root: string): string {
  const prefix = new RegExp(`(?:${escapeRegExp(root)}|~/work/plans)/(?![^\\s]*<issue>)`, "g");
  return text.replace(prefix, "");
}

type Outcome = { text: string; note?: string };

async function run(
  pi: ExtensionAPI,
  command: Command,
  args: string,
  ctx: ExtensionCommandContext,
): Promise<Outcome> {
  const usage = `Usage: /${command.name} ${command.argumentHint}`;
  const parsed = command.parse(args);
  if ("usage" in parsed) return { text: usage };
  const root = plansRoot();

  // A write records the user's decision; the running turn must finish first.
  if (command.write) await ctx.waitForIdle();

  // A plan typed as the output shows it is read back from the plans root.
  const [sub, plan, ...rest] = parsed.argv;
  const argv = [sub, absolute(plan, root), ...rest];

  try {
    // dev-stack.sh runs in the session's directory, which must be in the plan's repository.
    const ran = await pi.exec("bash", [STACK, ...argv], { cwd: ctx.cwd });
    const out = ran.stdout.trimEnd();
    if (ran.code === 0) {
      const note = command.write?.note(argv);
      return { text: shorten(out, root) || "(no output)", ...(note ? { note } : {}) };
    }
    if (ran.code === 2) return { text: usage };

    // check prints its PASS/BLOCK report on stdout and exits 1; other failures use stderr.
    const err = [out, ran.stderr.trimEnd()].filter(Boolean).join("\n");
    // dev-stack.sh names only the plan format or the missing repository; say what it needs from the caller.
    const hint = /Plan must be|main working-tree root|pass the stack's root/.test(err)
      ? "\nRun it from the plan's repository; next, list, and check take the root plan (lowest pr<N>)."
      : "";
    return { text: shorten(err || `dev-stack.sh exited ${ran.code}`, root) + hint };
  } catch (error) {
    return { text: "dev-stack.sh failed: " + String((error as Error)?.message ?? error) };
  }
}

export default function devStackExtension(pi: ExtensionAPI) {
  for (const command of COMMANDS) {
    pi.registerCommand(command.name, {
      description: command.description,
      handler: async (args, ctx) => {
        const { text, note } = await run(pi, command, args.trim(), ctx);
        // The output is shown in the transcript; the note only reaches the model.
        pi.sendMessage({ customType: "dev-stack", content: text, display: true }, { triggerTurn: false });
        if (note) {
          pi.sendMessage({ customType: "dev-stack-note", content: note, display: false }, { triggerTurn: false });
        }
      },
    });
  }
}
