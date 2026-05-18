---
applyTo: "**/*.{ts,tsx,js,jsx,cs,py,go,rs,java}"
---

# Coding standards

Follow the project-specific coding standards defined in `shared/project/guidelines/coding-standards.md`.

Key rules (see that file for full details):
- Function size soft limit: 50 lines. Hard limit: 100 lines.
- Parameter count soft limit: 5. Hard limit: 8.
- Every new public function has at least one unit test.
- Tests assert behaviour, not mere absence of exceptions.
- No `sleep()` in tests.
- TODOs require owner and ticket: `// TODO(WI-1234, @owner): ...`
- Explain *why* in comments, not *what*.
