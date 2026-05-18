---
applyTo: "**/*.{ts,tsx,js,jsx,cs,py,go,rs,java}"
---

# Error handling

Follow the project-specific error handling rules in `shared/project/guidelines/error-handling.md`.

Key rules:
- No empty catch blocks. No broad `except:` in Python. No swallowed errors.
- All errors log with structured properties — never string interpolation.
- Stack traces never appear in error responses.
- Retries only for idempotent operations.
