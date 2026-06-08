# Verify-story overrides

Project-specific configuration for `/verify-story`.

## URLs

```yaml
frontend_base_url: http://localhost:3000
backend_base_url:  http://localhost:5000
login_route:       /login
home_route:        /
```

## Test credentials

> **Never commit real credentials.** These are dev-environment-only test accounts.

```yaml
test_user:
  email:    test@yourproject.local
  password: "[NEEDS HUMAN INPUT]"

admin_user:
  email:    admin@yourproject.local
  password: "[NEEDS HUMAN INPUT]"
```

If the password is `[NEEDS HUMAN INPUT]`, ACs requiring this account become BLOCKED.

## Selectors for common elements

> Document the project's stable selectors so verify-story doesn't have to guess.

```yaml
selectors:
  email_field:    "input[name=email]"
  password_field: "input[name=password]"
  login_button:   "button[type=submit]"
  toast_success:  "[data-testid=toast-success]"
  toast_error:    "[data-testid=toast-error]"
  nav_user_menu:  "[data-testid=user-menu]"
```

## Seed data assumptions

> What dev data must exist for ACs to be verifiable. If missing, that AC is BLOCKED.

- `[NEEDS HUMAN INPUT — list expected seed data]`
- e.g. "At least one tenant exists with id `tenant-test-1`"
- e.g. "User `test@yourproject.local` exists with role `member`"

## Console errors to ignore (baseline noise)

Errors known to appear in dev that are not story-related.

```yaml
ignore_console_patterns:
  - "DevTools failed to load source map"
  - "React DevTools"
  - "[HMR]"
```

## Network requests to ignore

```yaml
ignore_network_patterns:
  - ".*\\.hot-update\\..*"
  - "/__webpack_hmr"
```

## Verification scope

```yaml
# Set to true to skip browser verification entirely (e.g. headless backend project)
skip_browser_verification: false

# Maximum time to wait for an AC outcome to appear, in seconds
ac_timeout_seconds: 5

# Maximum total run time in minutes (orchestrator hard cap)
max_total_minutes: 15
```
