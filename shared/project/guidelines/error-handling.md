# Error handling

> How errors flow in this project. Consumed by implement-slice, pr-review, security-review.

## Backend

- [NEEDS HUMAN INPUT] — e.g. "Never throw raw Exception. Use DomainException (ours)."
- Error responses use the project's standard error shape: [NEEDS HUMAN INPUT].
- Stack traces never appear in error responses.
- All errors log with structured properties — never string interpolation that hides values.

## Frontend

- [NEEDS HUMAN INPUT] — e.g. "Network errors: let the useQuery wrapper handle retry + toast."
- No silent `catch {}` blocks.
- Form validation errors surface via the form library's error state, not local useState.

## Logging

- Levels: debug / info / warn / error — agree on meanings here: [NEEDS HUMAN INPUT].
- Never log: passwords, tokens, PII fields listed in api-contracts.md.

## Retries

- Idempotent operations may retry. Non-idempotent operations do not retry without explicit design note.
- Max retries: [NEEDS HUMAN INPUT]. Backoff: [NEEDS HUMAN INPUT].
