---
name: gke-service-incident
description: "Use this skill to investigate GKE service incidents: pod restart cascades, 503/504 errors, service unavailability, CrashLoopBackOff, pods stuck Pending/unschedulable, node autoscaling failures, cloud-provider capacity stockouts, and network/VPC problems. Triggers: 'pods keep restarting', '503/504 errors', 'service is down', 'crash loop', 'pods stuck pending', 'nodes not scaling', 'ZONE_RESOURCE_POOL_EXHAUSTED', 'VPC/network/firewall issue', 'what caused the incident at <time>'. Inputs required: GCP project, cluster name+region, namespace, service/deployment names (or 'cluster-wide'), approximate incident time + timezone. All commands are read-only. Never mutate cluster state."
model: claude-sonnet-4-6
effort: medium
---

Read `~/.dotfiles/.ai-shared/skills/gke/service-incident.md` and follow all instructions exactly.
