import type { Register } from 'claude-code'

const STACK = '/.dotfiles/.ai-shared/bin/dev-stack.sh'

type Sub = 'next' | 'stack' | 'check' | 'review' | 'stop' | 'resume'

type Parsed = { argv: [sub: Sub, plan: string, ...rest: string[]] } | { usage: true }

type Command = {
  name: string
  description: string
  argumentHint: string
  parse: (text: string) => Parsed
  // A write changes the plan or the stack's stops.log. It runs only from the user's own input, and
  // tells the model with `note`, so a later run-stack turn knows of it. It waits for the turn to end,
  // since a running turn reads those files; a read runs mid-turn, to show progress while run-stack
  // works.
  write?: { note: (argv: string[]) => string }
}

// The person at the terminal or through Remote Control; plugins, the SDK, and agents are refused,
// since run-stack lets only the user resume a plan.
const USER_ORIGINS = new Set(['composer', 'bridge'])

// The plugin shows plan paths relative to the plans root (`short` below), so one without a leading
// / or ~ is read back from there.
const absolute = (text: string, root: string) => (/^[/~]/.test(text) ? text : `${root}/${text}`)

// Every plan path ends in .spec.md, so anything else, such as an unknown trailing flag, is a usage
// error; matching up to it keeps a path with spaces whole.
const isPlan = (text: string) => /\.spec\.md$/.test(text)
const PLAN_THEN_REST = /^(.*?\.spec\.md)(?:\s+(.*))?$/s

const escapeRegExp = (text: string) => text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')

const planOnly =
  (sub: Sub) =>
  (text: string): Parsed =>
    isPlan(text) ? { argv: [sub, text] } : { usage: true }

const COMMANDS: Command[] = [
  {
    name: 'dev-stack-next',
    description: "Show each plan's next action in a stack (dev-stack.sh next)",
    argumentHint: '<root spec file> [--tab|--tree|--md]',
    parse: text => {
      // A trailing view flag; dev-stack.sh defaults to --tab, its tab-separated rows.
      const VIEW = /(?:^|\s)(--tab|--tree|--md)$/
      const view = text.match(VIEW)?.[1]
      const spec = text.replace(VIEW, '').trim()
      if (!isPlan(spec)) return { usage: true }
      return { argv: view ? ['next', spec, view] : ['next', spec] }
    },
  },
  {
    name: 'dev-stack-list',
    description: "List a stack's plans, parents first (dev-stack.sh stack)",
    argumentHint: '<root spec file>',
    parse: planOnly('stack'),
  },
  {
    name: 'dev-stack-check',
    description:
      'Run the review-feature gate on every plan in a stack, minus the parent check (dev-stack.sh check)',
    argumentHint: '<root spec file>',
    parse: planOnly('check'),
  },
  {
    name: 'dev-stack-review',
    description: 'Record a review-feature verdict on a plan (dev-stack.sh review)',
    argumentHint: '<spec file> ready|needs-changes',
    parse: text => {
      const [, plan, verdict] = text.match(/^(.*\S)\s+(ready|needs-changes)$/s) ?? []
      return plan && verdict && isPlan(plan) ? { argv: ['review', plan, verdict] } : { usage: true }
    },
    write: {
      note: ([, plan, verdict]) =>
        `The user recorded the review-feature verdict ${verdict} on ${plan} with dev-stack.sh review.`,
    },
  },
  {
    name: 'dev-stack-stop',
    description: "Record why a plan stopped in its stack's stops.log (dev-stack.sh stop)",
    argumentHint: '<spec file> <reason>',
    parse: text => {
      const [, plan, reason] = text.match(PLAN_THEN_REST) ?? []
      return plan && reason?.trim() ? { argv: ['stop', plan, reason.trim()] } : { usage: true }
    },
    write: { note: ([, plan, reason]) => `The user stopped ${plan} with dev-stack.sh stop: ${reason}` },
  },
  {
    name: 'dev-stack-resume',
    description: "Clear a plan's stop so run-stack continues it (dev-stack.sh resume; only the user runs it)",
    argumentHint: '<spec file>',
    parse: planOnly('resume'),
    write: {
      note: ([, plan]) =>
        `The user cleared the stop on ${plan} with dev-stack.sh resume; for a "Failed fixes: 3/3" stop this grants three more attempts.`,
    },
  },
]

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    for (const c of COMMANDS) {
      await $.command.register({
        name: c.name,
        description: c.description,
        argumentHint: c.argumentHint,
        ...(c.write ? {} : { immediate: true as const }),
      })
    }
    return next(e)
  })

  // dev-stack.sh runs in the session's directory, which must be in the plan's repository.
  for (const c of COMMANDS) {
    on('command.run', { command: c.name }, async ($, e) => {
      const usage = `Usage: /${c.name} ${c.argumentHint}`
      const parsed = c.parse(e.args.trim())
      if ('usage' in parsed) return { text: usage }
      if (c.write && !USER_ORIGINS.has(e.origin.kind)) {
        return { text: `/${c.name} changes the plan stack and runs only from the user's own input.` }
      }

      const home = await $.env.get('HOME')
      if (!home) return { text: `${c.name}: HOME is not set.` }
      // Plan paths show relative to the plans root, as dev-plan-lib.sh resolves it. The format
      // hint in "Plan must be ~/work/plans/<repo>/..." keeps its prefix.
      const root = ((await $.env.get('AI_PLANS_ROOT')) || home + '/work/plans').replace(/\/+$/, '')
      const prefix = new RegExp(`(?:${escapeRegExp(root)}|~/work/plans)/(?!<)`, 'g')
      const short = (text: string) => text.replace(prefix, '')
      try {
        const [sub, plan, ...rest] = parsed.argv
        const argv = [sub, absolute(plan, root), ...rest]
        const ran = await $.process.run(['bash', home + STACK, ...argv])
        const out = ran.stdout.trimEnd()
        if (ran.exitCode === 0) {
          return { text: short(out) || '(no output)', ...(c.write ? { context: [c.write.note(argv)] } : {}) }
        }
        if (ran.exitCode === 2) return { text: usage }

        // check prints its PASS/BLOCK report on stdout and exits 1; other failures use stderr.
        const err = [out, ran.stderr.trimEnd()].filter(Boolean).join('\n')
        // dev-stack.sh names only the plan format or the missing repository; say what it needs from the caller.
        const hint = /Plan must be|main working-tree root|pass the stack's root/.test(err)
          ? "\nRun it from the plan's repository; next, list, and check take the root plan (lowest pr<N>)."
          : ''
        return { text: short(err || `dev-stack.sh exited ${ran.exitCode}`) + hint }
      } catch (error) {
        return { text: 'dev-stack.sh failed: ' + String((error as Error)?.message ?? error) }
      }
    })
  }
}
