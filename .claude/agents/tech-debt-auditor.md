---
name: tech-debt-auditor
description: Review a PR for technical debt — duplication, coupling, abstraction, test quality, documentation gaps. Posts PR comments; never approves. Invoked in parallel during pr-review pipeline.
tools: [Read, Grep, Glob, Bash(git:*), Bash(az:*), Bash(jq:*), Bash(shared/scripts/*)]
context: fork
---

See `shared/agents/tech-debt-auditor.md` for the full checklist, hard rules, and output contract.
