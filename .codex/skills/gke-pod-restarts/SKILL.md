---
name: gke-pod-restarts
description: "Use this skill to investigate GKE incidents involving pod restart cascades, 503/504 errors, service unavailability, or CrashLoopBackOff. Triggers: 'pods keep restarting', '503/504 errors', 'service is down', 'crash loop', 'what caused the incident at <time>'. Inputs required: GCP project, cluster name+region, namespace, service/deployment names, approximate incident time + timezone. All commands are read-only. Never mutate cluster state."
model: gpt-5.3-codex
effort: medium
---

Read `~/.ai-shared/skills/gke-pod-restarts/SKILL.md` and follow all instructions exactly.
