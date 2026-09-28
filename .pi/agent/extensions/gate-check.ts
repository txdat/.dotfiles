/**
 * gate-check.ts — Pi port of the Claude Code PreToolUse gate-check hook.
 *
 * Claude Code fires `~/.dotfiles/.ai-shared/bin/gate-check` (a PreToolUse
 * hook) whenever a dev:* skill is invoked, enforcing the plan state machine
 * (planning → approved → in-progress → implemented → reviewed → published)
 * and the plan's AC/TC/Step graph, issue link, review marker, and worktree.
 *
 * Pi has no hooks, so this extension re-implements the same firing point:
 * it intercepts `read` calls that load a dev-* skill — either the SKILL.md
 * wrapper (`~/.claude/skills/dev-<slug>/SKILL.md`) or the real instructions
 * (`~/.dotfiles/.ai-shared/skills/dev/<slug>.md`) — feeds the hook script a
 * Claude-Code-shaped PreToolUse JSON, and blocks the read when the gate
 * fails. The latest user message stands in for the Claude Skill tool's
 * `arguments` field, which is where gate-check resolves `docs/plans/<file>.md`
 * and fix-bug's diagnose/execute mode.
 *
 * Semantics match Claude Code: a failing gate blocks skill loading, and the
 * block reason tells the model what prerequisite to satisfy first.
 */

import { spawn } from "node:child_process";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import {
  isToolCallEventType,
  type ExtensionAPI,
  type ExtensionContext,
} from "@earendil-works/pi-coding-agent";

const HOME = os.homedir();
const GATE_CHECK = path.join(HOME, ".dotfiles", ".ai-shared", "bin", "gate-check");

// Canonicalise base paths once so matching is robust regardless of whether
// the model reads through the ~/.claude/skills symlink or the real directory.
const CLAUDE_SKILLS = path.join(HOME, ".claude", "skills");
const AI_SHARED_DEV = path.join(HOME, ".dotfiles", ".ai-shared", "skills", "dev");
const CLAUDE_SKILLS_REAL = (() => { try { return fs.realpathSync(CLAUDE_SKILLS); } catch { return CLAUDE_SKILLS; } })();
const AI_SHARED_DEV_REAL = (() => { try { return fs.realpathSync(AI_SHARED_DEV); } catch { return AI_SHARED_DEV; } })();

function expandHome(p: string): string {
  if (p === "~") return HOME;
  if (p.startsWith("~/")) return path.join(HOME, p.slice(2));
  return p;
}

/**
 * Map a skill file path to its gate-check slug (e.g. "dev-execute-feature" →
 * "execute-feature"). Returns undefined for non-dev skills (handoff,
 * gke-inspect-incident, ...) which have no gates.
 */
function skillSlugFromPath(filePath: string): string | undefined {
  let real: string;
  try {
    real = fs.realpathSync(path.resolve(expandHome(filePath)));
  } catch {
    // File may not exist yet (read tool fires before the actual I/O);
    // fall back to the lexical path.
    real = path.resolve(expandHome(filePath));
  }

  // ~/.claude/skills/dev-<slug>/SKILL.md (or its resolved symlink target).
  for (const base of [CLAUDE_SKILLS_REAL, CLAUDE_SKILLS]) {
    if (real.startsWith(base + path.sep)) {
      const parts = path.relative(base, real).split(path.sep);
      if (parts.length === 2 && parts[0].startsWith("dev-") && parts[1] === "SKILL.md") {
        return parts[0].slice(4);
      }
      return undefined;
    }
  }

  // ~/.dotfiles/.ai-shared/skills/dev/<slug>.md.
  for (const base of [AI_SHARED_DEV_REAL, AI_SHARED_DEV]) {
    if (real.startsWith(base + path.sep)) {
      const rel = path.relative(base, real);
      if (!rel.includes(path.sep) && rel.endsWith(".md")) {
        const slug = rel.slice(0, -3);
        return slug === "README" ? undefined : slug;
      }
      return undefined;
    }
  }

  return undefined;
}

/** Latest user message text — the proxy for the Skill tool's arguments. */
function latestUserPrompt(ctx: ExtensionContext): string {
  const entries = ctx.sessionManager?.getEntries() ?? [];
  for (let i = entries.length - 1; i >= 0; i--) {
    const e = entries[i];
    if (e.type === "message" && e.message.role === "user") {
      for (const c of e.message.content) {
        if (c.type === "text" && c.text.trim()) return c.text.trim();
      }
    }
  }
  return "";
}

function runGateCheck(
  hookJson: string,
  cwd: string,
): Promise<{ blocked: boolean; reason?: string }> {
  return new Promise((resolve) => {
    const child = spawn(GATE_CHECK, [], { cwd, stdio: ["pipe", "pipe", "ignore"] });
    let stdout = "";
    child.stdout.on("data", (d: Buffer) => (stdout += d.toString()));
    let settled = false;
    const done = (blocked: boolean, reason?: string) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      child.kill("SIGKILL");
      resolve({ blocked, reason });
    };
    const timer = setTimeout(() => done(false, "gate-check timed out"), 15000);
    child.on("error", (err) => done(false, `gate-check failed: ${err.message}`));
    child.on("close", () => {
      clearTimeout(timer);
      if (settled) return;
      settled = true;
      try {
        const out = JSON.parse(stdout) as {
          continue?: boolean;
          reason?: string;
          stopReason?: string;
        };
        if (out.continue === false) {
          resolve({
            blocked: true,
            reason: out.reason ?? out.stopReason ?? "gate-check blocked",
          });
        } else {
          resolve({ blocked: false });
        }
      } catch {
        resolve({ blocked: false });
      }
    });
    child.stdin.write(hookJson);
    child.stdin.end();
  });
}

export default function gateCheckExtension(pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    if (!isToolCallEventType("read", event)) return;
    const slug = skillSlugFromPath(event.input.path ?? "");
    if (!slug) return;

    const hookJson = JSON.stringify({
      hook_event_name: "PreToolUse",
      tool_name: "Skill",
      tool_input: { skill: `dev:${slug}`, arguments: latestUserPrompt(ctx) },
    });

    const result = await runGateCheck(hookJson, ctx.cwd);
    if (result.blocked) {
      return { block: true, reason: `[gate-check] ${result.reason}` };
    }
  });
}
