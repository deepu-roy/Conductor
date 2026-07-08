# Copilot instructions — Plugin repo contributor policy

This repo is the **Conductor plugin distribution repository**. It contains the installable plugin (`plugin/`), documentation, and marketplace manifest. It does NOT implement the SDLC workflow for itself.

## What lives here

- `plugin/` — the installable plugin (skills, agents, bin scripts, hooks, project-templates)
- `plugin/project-templates/` — files that `bootstrap-project` copies into a user's repo on first run
- `marketplace.json` — plugin registry manifest (keep in sync with `plugin/.claude-plugin/plugin.json`)
- `docs/` — design and functional documentation
- `.github/instructions/` — contributor guidelines for this repo

## Contribution rules

- **Never touch `plugin/` files without updating `plugin/.claude-plugin/plugin.json`** if you add/remove a skill, agent, or bin script.
- **Bump version** in both `plugin/.claude-plugin/plugin.json` and `marketplace.json` on every release (semver).
- **Bin scripts** must follow the `conductor-<name>` prefix convention and have `set -euo pipefail`.
- **Skills** must reference `conductor-<name>` for script calls — never `shared/scripts/`.
- **Never approve or merge PRs.** Post comments only. Humans approve.
- No `git push --force`. No `git commit --no-verify`.

## Comments in generated content

- Explain why, not what.
- No TODOs without owner and ticket: `// TODO(WI-1234): ...`
