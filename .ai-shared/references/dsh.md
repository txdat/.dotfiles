# dsh

Rules symlink: `~/.dsh/AGENTS.md` → `~/.dotfiles/.ai-shared/CORE.md`.

**skills** — create `~/.dsh/skills/<name>/SKILL.md` from the [dsh template](#dsh-template); the harness scans the user root `~/.dsh/skills`. Take name and description from [skills](../README.md#skills). The frontmatter parser keeps `name`, `description`, `whenToUse`, `metadata`, `disable-model-invocation`, and `user-invocable`, and silently discards any other key.

## dsh template

```
---
name: <name>
description: "<description>"
user-invocable: true
---

Read <absolute-path-to-md-file> and follow all instructions exactly.
```
