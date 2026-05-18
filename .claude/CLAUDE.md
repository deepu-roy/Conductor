# CLAUDE.md — Global policy

This file is loaded at the start of every Claude Code session in this repo. It sets durable, org-wide rules. Project-specific rules live in `shared/project/CLAUDE.md` and take precedence on conflict.

## Non-negotiable rules

1. **Propose, don't invent.** Every persona, requirement, acceptance criterion, or technical claim in generated docs must cite its source (work item field, file:line, prior design). If the source is unknown, write `[NEEDS HUMAN INPUT]`. Never fabricate.
2. **Tech-agnostic functional docs.** `functional.md` must not name frameworks, protocols, or cloud services. Those belong in `technical.md`.
3. **Never touch protected files.** Pipeline YAML, secrets, and master skills are read-only to Claude. Hooks enforce this.
4. **Never approve or merge.** PR reviewer subagents post comments only. Humans approve and merge.
5. **Every claim of "done" needs evidence.** Tests run, linter clean, type-check passed — not just "looks right".
6. **Project overrides win.** On any conflict between this file and `shared/project/`, follow the project layer and log the conflict in the run trace.

## Tool preferences

- Prefer CLI (`az`, `git`, `gh`, `curl`, `jq`, `yq`) over MCP.
- Prefer `Bash` with tight whitelists over broad tool grants.
- Never use `git push --force` on any branch.
- Never `git commit` with `--no-verify`.

## Output discipline

- Skills end with an explicit handoff ritual: artifact report, open questions, transition statement.
- Subagents end with a JSON summary block the orchestrator can parse.
- If you are about to produce more than ~2000 lines of code in a single turn, stop and confirm with the human — this usually means the slice is too big.

## Error handling in generated code

- No empty catch blocks. No broad `except:` in Python. No swallowed errors.
- All errors log with context (what was being attempted, inputs, not secrets).
- Project guidelines override for specific idioms — consult `shared/project/guidelines/error-handling.md`.

## Comments in generated code

- Explain *why*, not *what*. The code shows what.
- Do not write changelog comments (`// 2026-04-24 - added X by Claude`). Use git history for that.
- Do not leave TODOs without an owner and a ticket. `// TODO(WI-1234): ...` or nothing.

## Before producing any output

Every skill, before generating its primary artifact, loads in this order:

1. `shared/project/PROFILE.md`
2. `shared/project/CLAUDE.md` (if present)
3. `shared/project/overrides/<this-skill-name>.md` (if present)
4. All files in `shared/project/guidelines/`
5. Stack files in `shared/project/stacks/` matching the PROFILE

Missing optional files are expected — continue without them. `PROFILE.md` is required; if absent, abort with "Run `/bootstrap-project` first."
