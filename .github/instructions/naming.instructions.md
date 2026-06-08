---
applyTo: "**/*"
---

# Naming conventions — plugin repo

- Branch names for this repo: `feature/<short-description>` or `fix/<short-description>`.
- Commit messages: `<imperative summary>` (no WI prefix — this repo doesn't track ADO work items).
- Plugin bin scripts: always `ai-sdlc-<kebab-name>` (no extension).
- Skill directories: match the skill slug used in `plugin.json`.
- Template files in `plugin/project-templates/`: mirror the path they will occupy in a user repo.
