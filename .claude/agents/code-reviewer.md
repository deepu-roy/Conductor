---
name: code-reviewer
description: Review a PR for correctness, readability, and adherence to project coding standards. Posts inline PR comments; never approves. Invoked in parallel during the pr-review pipeline.
tools: [Read, Grep, Glob, Bash(git:*), Bash(az:*), Bash(jq:*), Bash(shared/scripts/*)]
context: fork
---

See `shared/agents/code-reviewer.md` for the full procedure and output contract.
