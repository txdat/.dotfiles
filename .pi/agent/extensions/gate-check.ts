/**
 * gate-check.ts — Pi port of the Claude Code gate-check.sh hooks.
 *
 * Claude Code runs `~/.dotfiles/.ai-shared/bin/gate-check.sh` before a dev:*
 * skill loads, enforcing the plan state machine and proof checks
 * (skills/dev/plan.md). Pi has no hooks and loads skills with its `read`
 * tool, so this extension gates `read` calls on a dev skill file — the
 * wrapper `~/.claude/skills/dev-<slug>/SKILL.md` or the instructions
 * `~/.dotfiles/.ai-shared/skills/dev/<slug>.md` — by feeding gate-check.sh a
 * Claude-shaped PreToolUse JSON and blocking the read when it blocks.
 * gate-check.sh alone decides which slugs are gated.
 *
 * Claude Code also runs it before its Bash, Edit, Write, and MultiEdit calls
 * and after a Bash call, which never invoke a phase: it refuses the user's
 * commands, writes to the stack log, and changes to a frozen plan. Here
 * `tool_call` on bash, edit, and write sends the same JSON and blocks the
 * call, and `tool_result` on bash sends the PostToolUse JSON and hands its
 * report to the model beside the call's own output.
 *
 * gate-check.sh resolves a `pr<N>.spec.md` plan path from the Skill tool's
 * `arguments`. Here that is the text of the assistant message that issued
 * the read when it names a plan — run-stack names each plan as it starts its
 * phase in one session — and otherwise the latest user message.
 *
 * If gate-check.sh cannot run (missing, timed out, unreadable output) the
 * call passes, as a failed Claude Code hook does, with a UI warning.
 */

import { execFile } from "node:child_process";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import { fileURLToPath } from "node:url";
import {
  isBashToolResult,
  isToolCallEventType,
  type ExtensionAPI,
  type ExtensionContext,
  type ToolCallEvent,
} from "@earendil-works/pi-coding-agent";

type Message = { role?: string; content?: unknown };
type Verdict =
  | { block: true; reason: string }
  | { block: false; error?: string; warning?: string };

const HOME = os.homedir();
const GATE_CHECK = path.join(HOME, ".dotfiles", ".ai-shared", "bin", "gate-check.sh");
const TIMEOUT_MS = 15_000;
const PLAN_MENTION = /pr\d+\.spec\.md/;

/**
 * A path as written and with symlinks resolved. Matching every form of the
 * read path against every form of a base keeps the gate on when either side
 * is reached through a symlink (a linked home or skills dir, a SKILL.md that
 * links elsewhere).
 */
function pathForms(p: string): string[] {
  let real = p;
  try {
    real = fs.realpathSync(p);
  } catch {
    // Missing file: the read will fail on its own; match the lexical path.
  }
  return real === p ? [p] : [p, real];
}

const CLAUDE_SKILLS = pathForms(path.join(HOME, ".claude", "skills"));
const AI_SHARED_DEV = pathForms(path.join(HOME, ".dotfiles", ".ai-shared", "skills", "dev"));

/**
 * Mirror Pi's path resolution (`resolveToCwd`) for read, edit, and write,
 * which it does not export.
 */
function resolveToCwd(p: string, cwd: string): string {
  if (p.startsWith("@")) p = p.slice(1);
  if (p === "~") p = HOME;
  else if (p.startsWith("~/")) p = path.join(HOME, p.slice(2));
  else if (p.startsWith("file://")) {
    try {
      p = fileURLToPath(p);
    } catch {
      // Pi rejects this URL too, so the call fails ungated either way.
    }
  }
  return path.resolve(cwd, p);
}

/** Path segments of `file` below `base`, or undefined when it is outside. */
function segmentsUnder(base: string, file: string): string[] | undefined {
  const rel = path.relative(base, file);
  if (!rel || path.isAbsolute(rel)) return undefined;
  const parts = rel.split(path.sep);
  return parts[0] === ".." ? undefined : parts;
}

/** The gate-check.sh slug for a dev skill file ("dev-review-code" → "review-code"). */
function skillSlug(file: string): string | undefined {
  for (const form of pathForms(file)) {
    for (const base of CLAUDE_SKILLS) {
      const parts = segmentsUnder(base, form);
      if (parts?.length === 2 && parts[0]!.startsWith("dev-") && parts[1] === "SKILL.md") {
        return parts[0]!.slice("dev-".length);
      }
    }
    for (const base of AI_SHARED_DEV) {
      const parts = segmentsUnder(base, form);
      if (parts?.length === 1 && parts[0]!.endsWith(".md")) return parts[0]!.slice(0, -".md".length);
    }
  }
  return undefined;
}

function textOf(message: Message): string {
  const content = message.content;
  if (typeof content === "string") return content.trim();
  if (!Array.isArray(content)) return "";
  return content
    .filter((c) => c?.type === "text" && typeof c.text === "string")
    .map((c) => c.text)
    .join("\n")
    .trim();
}

function issued(message: Message, callId: string): boolean {
  return (
    message.role === "assistant" &&
    Array.isArray(message.content) &&
    message.content.some((c) => c?.type === "toolCall" && c.id === callId)
  );
}

/**
 * The proxy for the Skill tool's arguments: the text of the assistant message
 * that issued call `callId` when it names a plan, else the latest user message
 * on the active branch.
 */
function skillArguments(ctx: ExtensionContext, callId: string, lastAssistant?: Message): string {
  let issuer = lastAssistant && issued(lastAssistant, callId) ? lastAssistant : undefined;
  let prompt = "";
  const branch = ctx.sessionManager.getBranch();
  for (let i = branch.length - 1; i >= 0 && !prompt; i--) {
    const e = branch[i]!;
    if (e.type !== "message") continue;
    if (!issuer && issued(e.message, callId)) issuer = e.message;
    if (e.message.role === "user") prompt = textOf(e.message);
  }
  const said = issuer ? textOf(issuer) : "";
  return PLAN_MENTION.test(said) ? said : prompt;
}

function runGateCheck(hookJson: string, cwd: string): Promise<Verdict> {
  return new Promise((resolve) => {
    const child = execFile(
      GATE_CHECK,
      { cwd, timeout: TIMEOUT_MS, killSignal: "SIGKILL" },
      (err, stdout, stderr) => {
        // gate-check.sh prints verdict JSON and exits 0, or prints nothing to pass:
        // continue:false blocks a PreToolUse, and decision:block reports a Bash
        // call whose changes the post-check restored.
        try {
          const out = JSON.parse(stdout) as {
            continue?: boolean;
            decision?: string;
            reason?: string;
            stopReason?: string;
          };
          if (out.continue === false) {
            return resolve({ block: true, reason: out.reason ?? out.stopReason ?? "gate-check.sh blocked" });
          }
          if (out.decision === "block") {
            return resolve({ block: false, warning: out.reason ?? "gate-check.sh restored a change to a plan" });
          }
        } catch {
          // No verdict on stdout.
        }
        if (!err) return resolve({ block: false });
        const error = err.killed ? `timed out after ${TIMEOUT_MS / 1000}s` : stderr.trim() || err.message;
        resolve({ block: false, error });
      },
    );
    // A spawn failure closes stdin early; the callback above reports it.
    child.stdin?.on("error", () => {});
    child.stdin?.end(hookJson);
  });
}

/**
 * The Claude-shaped PreToolUse JSON for a bash, edit, or write call, or
 * undefined for every other tool. Pi's edit tool applies all of a call's
 * edits, so it is the MultiEdit shape: the guard judges the whole call.
 */
function guardCall(event: ToolCallEvent, cwd: string): string | undefined {
  const base = { hook_event_name: "PreToolUse", tool_use_id: event.toolCallId, cwd };
  if (isToolCallEventType("bash", event)) {
    return JSON.stringify({ ...base, tool_name: "Bash", tool_input: { command: event.input.command } });
  }
  if (isToolCallEventType("edit", event)) {
    return JSON.stringify({
      ...base,
      tool_name: "Edit",
      tool_input: {
        file_path: resolveToCwd(event.input.path, cwd),
        edits: event.input.edits.map((e) => ({ old_string: e.oldText, new_string: e.newText })),
      },
    });
  }
  if (isToolCallEventType("write", event)) {
    return JSON.stringify({
      ...base,
      tool_name: "Write",
      tool_input: { file_path: resolveToCwd(event.input.path, cwd), content: event.input.content },
    });
  }
  return undefined;
}

export default function gateCheckExtension(pi: ExtensionAPI) {
  // Pi persists an assistant message at message_end; keep it in case a call
  // runs before the session lists it.
  let lastAssistant: Message | undefined;
  pi.on("message_end", (event) => {
    if (event.message.role === "assistant") lastAssistant = event.message as Message;
  });

  pi.on("tool_call", async (event, ctx) => {
    // Before a bash, edit, or write call: the record guard.
    if (!isToolCallEventType("read", event)) {
      const guard = guardCall(event, ctx.cwd);
      if (!guard) return;
      const verdict = await runGateCheck(guard, ctx.cwd);
      if (verdict.block) return { block: true, reason: `[gate-check.sh] ${verdict.reason}` };
      if (verdict.error) {
        ctx.ui.notify(`gate-check.sh failed, ${event.toolName} ran unguarded: ${verdict.error}`, "warning");
      }
      return;
    }

    const slug = skillSlug(resolveToCwd(event.input.path ?? "", ctx.cwd));
    if (!slug) return;

    // A call another tool made has id "<parent id>/<n>"; the root is the
    // model-issued call recorded in the transcript.
    const callId = event.toolCallId.split("/")[0]!;
    const hookJson = JSON.stringify({
      hook_event_name: "PreToolUse",
      tool_name: "Skill",
      tool_input: { skill: `dev:${slug}`, arguments: skillArguments(ctx, callId, lastAssistant) },
    });

    const verdict = await runGateCheck(hookJson, ctx.cwd);
    if (verdict.block) return { block: true, reason: `[gate-check.sh] ${verdict.reason}` };
    if (verdict.error) {
      ctx.ui.notify(`gate-check.sh failed, ${event.input.path} loaded ungated: ${verdict.error}`, "warning");
    }
  });

  // After a bash call: the plans it changed are compared with the snapshot its
  // tool_call took, and anything only dev-stack.sh or the user may change is
  // put back. The report joins the call's own output, as Claude Code's
  // PostToolUse decision does, so the model learns what was restored.
  pi.on("tool_result", async (event, ctx) => {
    if (!isBashToolResult(event)) return;
    const hookJson = JSON.stringify({
      hook_event_name: "PostToolUse",
      tool_name: "Bash",
      tool_use_id: event.toolCallId,
      cwd: ctx.cwd,
    });
    const verdict = await runGateCheck(hookJson, ctx.cwd);
    const report = (reason: string) => {
      ctx.ui.notify(`[gate-check.sh] ${reason}`, "warning");
      return { content: [...event.content, { type: "text" as const, text: `[gate-check.sh] ${reason}` }] };
    };
    if (verdict.block) return report(verdict.reason);
    if (verdict.warning) return report(verdict.warning);
    if (verdict.error) {
      ctx.ui.notify(`gate-check.sh failed, ${event.toolName} ran unguarded: ${verdict.error}`, "warning");
    }
  });
}
