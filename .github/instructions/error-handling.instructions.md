---
applyTo: "plugin/bin/**"
---

# Error handling — plugin repo

For shell scripts in `plugin/bin/`:
- Always `set -euo pipefail`. Fail loudly — never silently ignore errors.
- Print a clear message to stderr before exiting non-zero: `echo "ERROR: <what failed>" >&2`.
- Use `exit 1` for user errors, `exit 2` for hook-block signals (per Claude Code convention).
