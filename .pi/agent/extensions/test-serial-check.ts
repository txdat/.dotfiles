/**
 * test-serial-check.ts — Pi port of the Claude Code test-serial-check.sh hook.
 *
 * Claude Code runs `~/.dotfiles/.ai-shared/bin/test-serial-check.sh` before a
 * Bash call; it denies a command that names jest without --runInBand
 * (.ai-shared/CODING.md#tests). Here `tool_call` on bash feeds the script the
 * same Claude-shaped PreToolUse JSON and blocks the call when it denies.
 *
 * If the script cannot run (missing, timed out, unreadable output) the call
 * passes, as a failed Claude Code hook does, with a UI warning.
 */

import { execFile } from "node:child_process";
import * as os from "node:os";
import * as path from "node:path";
import { isToolCallEventType, type ExtensionAPI } from "@earendil-works/pi-coding-agent";

type Verdict = { deny: true; reason: string } | { deny: false; error?: string };

const CHECK = path.join(os.homedir(), ".dotfiles", ".ai-shared", "bin", "test-serial-check.sh");
const TIMEOUT_MS = 10_000;

function runCheck(hookJson: string, cwd: string): Promise<Verdict> {
  return new Promise((resolve) => {
    const child = execFile(CHECK, { cwd, timeout: TIMEOUT_MS, killSignal: "SIGKILL" }, (err, stdout, stderr) => {
      // The script prints a deny decision and exits 0, or prints nothing to pass.
      if (!err && !stdout.trim()) return resolve({ deny: false });
      try {
        const out = JSON.parse(stdout) as {
          decision?: string;
          reason?: string;
          hookSpecificOutput?: { permissionDecision?: string; permissionDecisionReason?: string };
        };
        if (out.hookSpecificOutput?.permissionDecision === "deny" || out.decision === "deny") {
          return resolve({
            deny: true,
            reason: out.hookSpecificOutput?.permissionDecisionReason ?? out.reason ?? "test-serial-check.sh denied",
          });
        }
      } catch {
        // No verdict on stdout.
      }
      const error = err?.killed
        ? `timed out after ${TIMEOUT_MS / 1000}s`
        : stderr.trim() || err?.message || `unreadable output: ${stdout.trim()}`;
      resolve({ deny: false, error });
    });
    // A spawn failure closes stdin early; the callback above reports it.
    child.stdin?.on("error", () => {});
    child.stdin?.end(hookJson);
  });
}

export default function testSerialCheckExtension(pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    if (!isToolCallEventType("bash", event)) return;
    const hookJson = JSON.stringify({
      hook_event_name: "PreToolUse",
      tool_name: "Bash",
      tool_use_id: event.toolCallId,
      tool_input: { command: event.input.command },
      cwd: ctx.cwd,
    });
    const verdict = await runCheck(hookJson, ctx.cwd);
    if (verdict.deny) return { block: true, reason: `[test-serial-check.sh] ${verdict.reason}` };
    if (verdict.error) ctx.ui.notify(`test-serial-check.sh failed, bash ran unchecked: ${verdict.error}`, "warning");
  });
}
