# Coding standards

> This file is consumed by master skills (requirements-analysis, implement-slice, pr-review, tech-debt-review). Write what is specific to this project. Keep it short — every rule has a maintenance cost.

## Naming

- [NEEDS HUMAN INPUT] — e.g. "PascalCase for C# classes, camelCase for TS functions, kebab-case for file names"

## Function size

- Soft limit: 50 lines. Hard limit: 100 lines (review-blocker).

## Parameter count

- Soft limit: 5 parameters. Hard limit: 8.

## Tests

- Every new public function has at least one unit test.
- Tests assert behaviour, not mere absence of exceptions.
- No `sleep()` in tests — use deterministic waits.

## Imports / module boundaries

- [NEEDS HUMAN INPUT] — list any cross-boundary rules (e.g. "web cannot import from api/")

## Comments

- Explain why, not what.
- TODOs require owner and ticket: `// TODO(WI-1234, @alice): ...`

## Project-specific patterns

- [NEEDS HUMAN INPUT]
