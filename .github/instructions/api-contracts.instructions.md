---
applyTo: "plugin/.claude-plugin/plugin.json,marketplace.json"
---

# Plugin manifest rules

- `plugin/.claude-plugin/plugin.json` is the single source of truth for plugin metadata.
- `marketplace.json` at repo root must stay in sync with `plugin.json` version and capabilities.
- Bump `version` in both files on every release (semver).
- Do not add capabilities to `plugin.json` without a corresponding implementation in `plugin/skills/`, `plugin/agents/`, or `plugin/bin/`.
