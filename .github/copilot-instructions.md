# Copilot instructions — Global policy

This file is the equivalent of `.github/copilot-instructions.md` for GitHub Copilot. It is loaded automatically into every Copilot session in this repo.

## Core rules

- Propose, don't invent. Every persona, requirement, or technical claim must cite its source. If unknown, write `[NEEDS HUMAN INPUT]`.
- `functional.md` must be tech-agnostic. No framework, protocol, or cloud-service names. Those belong in `technical.md`.
- Never touch protected files: pipeline YAML, secrets, master skills. Hooks enforce this.
- Never approve or merge PRs. Post comments only. Humans approve.
- Every claim of "done" needs evidence: tests run, linter clean, type-check passed.
- Project overrides win. On conflict between this file and `shared/project/`, follow the project layer and log the conflict.

## Tool preferences

- Prefer CLI (`az`, `git`, `gh`, `curl`, `jq`, `yq`) over MCP.
- Never `git push --force`. Never `git commit --no-verify`.

## Output discipline

- Skills end with an explicit handoff: artifact report, open questions, transition statement.
- Subagents end with a JSON summary block the orchestrator can parse.
- If about to produce >2000 lines in one turn, stop and confirm with the human.

## Before producing any output

Every skill and agent loads in this order:

1. `shared/project/PROFILE.md` — required; abort if missing
2. `shared/project/CLAUDE.md` (if present) — project policy
3. `shared/project/overrides/<this-skill-name>.md` (if present)
4. All files in `shared/project/guidelines/`
5. Stack files in `shared/project/stacks/` matching the PROFILE

Missing optional files are expected. `PROFILE.md` is required.

## Error handling in generated code

- No empty catch blocks. No broad `except:`. No swallowed errors.
- Log with context (what was attempted, inputs — never secrets).
- Project guidelines override for idioms — see `shared/project/guidelines/error-handling.md`.

## Comments in generated code

- Explain why, not what.
- No changelog comments. Use git history.
- No TODOs without owner and ticket: `// TODO(WI-1234): ...`
