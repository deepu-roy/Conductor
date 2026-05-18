---
name: security-auditor
description: Review a PR for security issues — OWASP Top 10, LLM risks, injection, secrets, auth, data exposure. Posts PR comments; never approves. Invoked in parallel during pr-review pipeline.
tools: [Read, Grep, Glob, Bash(git:*), Bash(az:*), Bash(jq:*), Bash(shared/scripts/*)]
context: fork
---

See `shared/agents/security-auditor.md` for the full checklist, hard rules, and output contract.
