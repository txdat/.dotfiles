import type { Register } from 'claude-code'

const STACK = '/.dotfiles/.ai-shared/bin/dev-stack.sh'
const USAGE = 'Usage: /dev-stack-next <root spec file> [--md]'

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'dev-stack-next',
      description: 'Show the progress tree of a plan stack (dev-stack.sh next)',
      argumentHint: '<root spec file> [--md]',
      // Read-only, so it can show progress while a turn, such as run-stack, is still working.
      immediate: true,
    })
    return next(e)
  })

  // dev-stack.sh runs in the session's directory, which must be in the plan's repository.
  on('command.run', { command: 'dev-stack-next' }, async ($, e) => {
    // Everything but the --md flag is the path, so a path with spaces still works.
    const text = (e.args || '').trim()
    const view = /(^|\s)--md$/.test(text) ? '--md' : '--tree'
    const spec = text.replace(/(^|\s)--md$/, '').trim()
    if (!spec) return { text: USAGE }

    const home = await $.env.get('HOME')
    if (!home) return { text: 'dev-stack-next: HOME is not set.' }
    try {
      const ran = await $.process.run(['bash', home + STACK, 'next', spec, view])
      if (ran.exitCode === 0) return { text: ran.stdout.trimEnd() || '(no output)' }

      const err = (ran.stderr || ran.stdout).trimEnd()
      // dev-stack.sh names only the plan format or the missing repository; say what it needs from the caller.
      const hint = /Plan must be|main working-tree root/.test(err)
        ? "\nRun it from the plan's repository, with its root plan (lowest pr<N>)."
        : ''
      return { text: err + hint }
    } catch (error) {
      return { text: 'dev-stack.sh failed: ' + String((error as Error)?.message ?? error) }
    }
  })
}
