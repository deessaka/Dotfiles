---
name: team
description: Orchestrate substantial development missions through the provider-neutral Team workflow, shared .team ledger, explicit tickets, evidence, review and safe handoffs. Use whenever the user asks to plan or execute substantial work, coordinate parallel agents, or track a development mission.
---

Read `~/.local/share/team/WORKFLOW.md` before operating the Team ledger. Then
read the project instructions, specs, ADRs and `.team/` state. The Team workflow
is provider-independent: use this runtime's native delegation and permission
mechanisms without changing its normal UX or claiming unavailable capabilities.

Keep the canonical ledger in the mission checkout's `.team/`; update it only
with the `team` CLI. The orchestrator owns status and integration. Give each
specialist a scoped ticket and report path; prevent concurrent edits to the same
files. Do not overwrite existing mission state. Respect real runtime sandbox and
permission controls. Never imply instruction text is a system sandbox. Require
explicit user authorization before publishing, merging, deploying, expanding
permissions or incurring new costs.
