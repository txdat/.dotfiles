import type { On } from 'claude-code'
import { expect, test } from 'claude-code/testing'

const SH = '/home/u/.dotfiles/.ai-shared/bin/dev-stack.sh'
// A plans root with a space; the plan's own name allows none.
const PLAN = '/tmp/my plans/repo/12_s/pr1.spec.md'

type Ran = { exitCode: number; stdout: string; stderr: string }

// Records each dev-stack.sh argv and answers it with `ran`; nothing sits beneath, so these hooks
// stand for the engine.
function engine(on: On, ran: Ran = { exitCode: 0, stdout: 'ok\n', stderr: '' }) {
  const calls: string[][] = []
  on('env.get', (_, e) => ({ value: e.name === 'HOME' ? '/home/u' : undefined }))
  on('process.run', (_, e) => {
    calls.push([...e.argv])
    return { value: { ...ran, isStdoutTruncated: false, isStderrTruncated: false } }
  })
  return calls
}

// A command the person typed at the prompt; the engine stamps origin and presentation.
const typed = (command: string, args: string) => ({
  command,
  args,
  origin: { kind: 'composer' as const },
  presentation: { isFullscreen: false, columns: 120 },
})

test('each command runs its dev-stack.sh subcommand, a plan path with spaces kept whole', async ($, on) => {
  const calls = engine(on)
  const cases: [string, string, string[]][] = [
    ['dev-stack-next', PLAN, ['next', PLAN]],
    ['dev-stack-next', `${PLAN} --tab`, ['next', PLAN, '--tab']],
    ['dev-stack-next', `${PLAN} --tree`, ['next', PLAN, '--tree']],
    ['dev-stack-next', `${PLAN} --md`, ['next', PLAN, '--md']],
    ['dev-stack-list', PLAN, ['stack', PLAN]],
    ['dev-stack-check', PLAN, ['check', PLAN]],
    ['dev-stack-review', `${PLAN} needs-changes`, ['review', PLAN, 'needs-changes']],
    [
      'dev-stack-stop',
      `${PLAN}  Failed fixes: 3/3 — flaky test`,
      ['stop', PLAN, 'Failed fixes: 3/3 — flaky test'],
    ],
    ['dev-stack-resume', PLAN, ['resume', PLAN]],
  ]
  for (const [command, args, argv] of cases) {
    await $.command.run(typed(command, args))
    expect(calls.pop()).toEqual(['bash', SH, ...argv])
  }
})

test('a missing argument shows usage and runs nothing', async ($, on) => {
  const calls = engine(on)
  const cases: [string, string][] = [
    ['dev-stack-next', ''],
    ['dev-stack-review', PLAN],
    ['dev-stack-review', `${PLAN} approved`],
    ['dev-stack-review', 'notaplan ready'],
    ['dev-stack-stop', PLAN],
    ['dev-stack-resume', '  '],
    ['dev-stack-next', `${PLAN} --json`],
    ['dev-stack-check', `${PLAN} extra`],
  ]
  for (const [command, args] of cases) {
    const out = await $.command.run(typed(command, args))
    expect(out.text?.startsWith(`Usage: /${command} `)).toBe(true)
  }
  expect(calls.length).toBe(0)
})

test('only a successful write tells the model', async ($, on) => {
  engine(on)
  const resumed = await $.command.run(typed('dev-stack-resume', PLAN))
  expect(resumed.context?.[0]).toContain(`cleared the stop on ${PLAN}`)
  const listed = await $.command.run(typed('dev-stack-list', PLAN))
  expect(listed.context ?? []).toEqual([])
})

test('a failed write tells the model nothing', async ($, on) => {
  engine(on, { exitCode: 1, stdout: '', stderr: 'Plan not found: x' })
  const out = await $.command.run(typed('dev-stack-resume', PLAN))
  expect(out.text).toBe('Plan not found: x')
  expect(out.context ?? []).toEqual([])
})

test("check's blocked report on stdout is shown", async ($, on) => {
  engine(on, { exitCode: 1, stdout: `PASS a\nBLOCK b\nreason\n`, stderr: '' })
  const out = await $.command.run(typed('dev-stack-check', PLAN))
  expect(out.text).toBe('PASS a\nBLOCK b\nreason')
})

test('a plan outside the repository gets a hint', async ($, on) => {
  engine(on, { exitCode: 1, stdout: '', stderr: 'Plan must be ~/work/plans/...' })
  const out = await $.command.run(typed('dev-stack-next', PLAN))
  expect(out.text).toContain("Run it from the plan's repository")
})

test('plan paths show without the plans root prefix', async ($, on) => {
  engine(on, {
    exitCode: 0,
    stdout:
      '/home/u/work/plans/repo/12_s/pr1.spec.md\tplanning\t-\treview-feature\t-\n~/work/plans/repo/12_s/pr2.spec.md\n',
    stderr: '',
  })
  const out = await $.command.run(typed('dev-stack-next', PLAN))
  expect(out.text).toBe('repo/12_s/pr1.spec.md\tplanning\t-\treview-feature\t-\nrepo/12_s/pr2.spec.md')
})

test('AI_PLANS_ROOT moves the prefix, and the format hint keeps its own', async ($, on) => {
  on('env.get', (_, e) => ({ value: { HOME: '/home/u', AI_PLANS_ROOT: '/tmp/p.x/' }[e.name] }))
  on('process.run', () => ({
    value: {
      exitCode: 1,
      stdout: '',
      stderr:
        'Plan not found: /tmp/p.x/repo/12_s/pr9.spec.md\nPlan must be ~/work/plans/<repo>/<issue>_<slug>/pr<N>.spec.md',
      isStdoutTruncated: false,
      isStderrTruncated: false,
    },
  }))
  const out = await $.command.run(typed('dev-stack-resume', PLAN))
  expect(out.text?.split('\n').slice(0, 2)).toEqual([
    'Plan not found: repo/12_s/pr9.spec.md',
    'Plan must be ~/work/plans/<repo>/<issue>_<slug>/pr<N>.spec.md',
  ])
})

test('the format hint keeps its prefix when it names the repository', async ($, on) => {
  engine(on, {
    exitCode: 1,
    stdout: '',
    stderr: 'Plan must be ~/work/plans/repo/<issue>_<slug>/pr<N>.spec.md: /home/u/work/plans/x/pr1.spec.md',
  })
  const out = await $.command.run(typed('dev-stack-next', PLAN))
  expect(out.text?.split('\n')[0]).toBe(
    'Plan must be ~/work/plans/repo/<issue>_<slug>/pr<N>.spec.md: x/pr1.spec.md',
  )
})

test('a leading @ file mention is not part of the plan path', async ($, on) => {
  const calls = engine(on)
  await $.command.run(typed('dev-stack-next', '@repo/12_s/pr1.spec.md'))
  expect(calls.pop()).toEqual(['bash', SH, 'next', '/home/u/work/plans/repo/12_s/pr1.spec.md'])
})

test('a write runs only from the user, at the terminal or through Remote Control', async ($, on) => {
  const calls = engine(on)
  const others = [
    { kind: 'plugin', name: 'other' },
    { kind: 'sdk' },
    { kind: 'scheduled-trigger' },
    { kind: 'peer' },
    { kind: 'task-notification' },
  ] as const
  const writes: [string, string][] = [
    ['dev-stack-review', `${PLAN} ready`],
    ['dev-stack-stop', `${PLAN} reason`],
    ['dev-stack-resume', PLAN],
  ]
  for (const origin of others) {
    for (const [command, args] of writes) {
      const out = await $.command.run({ ...typed(command, args), origin })
      expect(out.text).toContain("runs only from the user's own input")
      expect(out.context ?? []).toEqual([])
    }
    await $.command.run({ ...typed('dev-stack-list', PLAN), origin })
  }
  expect(calls.length).toBe(others.length)
  for (const origin of [{ kind: 'composer' }, { kind: 'bridge' }] as const) {
    const out = await $.command.run({ ...typed('dev-stack-resume', PLAN), origin })
    expect(out.context?.length).toBe(1)
  }
  expect(calls.length).toBe(others.length + 2)
})

test('a plan path as shown, relative to the plans root, is read back from it', async ($, on) => {
  const calls = engine(on)
  const out = await $.command.run(typed('dev-stack-resume', 'repo/12_s/pr1.spec.md'))
  expect(calls.pop()).toEqual(['bash', SH, 'resume', '/home/u/work/plans/repo/12_s/pr1.spec.md'])
  expect(out.context?.[0]).toContain('/home/u/work/plans/repo/12_s/pr1.spec.md')
})

test('a usage error from dev-stack.sh shows the usage line', async ($, on) => {
  engine(on, { exitCode: 2, stdout: '', stderr: 'Usage: dev-stack.sh ...' })
  const out = await $.command.run(typed('dev-stack-review', `${PLAN} ready`))
  expect(out.text).toBe('Usage: /dev-stack-review <spec file> ready|needs-changes')
})

test('reads run mid-turn and writes wait for the turn', async ($, on) => {
  const specs: { name: string; immediate: true | undefined }[] = []
  on('command.register', (_, e) => {
    specs.push({ name: e.name, immediate: e.immediate })
    return { value: { command: e.name } }
  })
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  expect(specs).toEqual([
    { name: 'dev-stack-next', immediate: true },
    { name: 'dev-stack-list', immediate: true },
    { name: 'dev-stack-check', immediate: true },
    { name: 'dev-stack-review', immediate: undefined },
    { name: 'dev-stack-stop', immediate: undefined },
    { name: 'dev-stack-resume', immediate: undefined },
  ])
})
