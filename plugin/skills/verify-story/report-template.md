# Browser verification — WI-{WI_ID}

**Generated:** {ISO_TIMESTAMP}
**Base URL:** {BASE_URL}
**Browser:** Chrome via MCP
**Run ID:** {RUN_ID}

## Summary

| Metric | Count |
|---|---|
| ACs checked | {N_CHECKED} |
| Passed | {N_PASSED} |
| Failed | {N_FAILED} |
| Blocked | {N_BLOCKED} |
| New console errors | {N_CONSOLE_ERRORS} |
| New failed network requests | {N_FAILED_REQUESTS} |

**Verdict:** ✅ READY FOR REVIEW | ⚠️ ISSUES FOUND — see details below

---

## Pre-test baseline

- Console errors on load: {BASELINE_CONSOLE_COUNT}
- Failed network requests on load: {BASELINE_NETWORK_COUNT}
- Pre-existing issues (excluded from counts): see overrides/verify-story.md

[`baseline.png`](./screenshots/baseline.png)

---

## AC results

### Slice S1: {SLICE_TITLE}

#### S1.AC1 — Given... when... then...

- **Result:** ✅ PASS / ❌ FAIL / ⏸ BLOCKED
- **Steps executed:**
  1. Navigated to `/path`
  2. Clicked `<selector>`
  3. Typed `<value>` into `<selector>`
  4. Asserted `<expected>`
- **Screenshot:** [`s1-ac1.png`](./screenshots/s1-ac1.png)
- **Notes:** _Only fill if FAIL or BLOCKED — what happened, what was expected, suspected cause._

#### S1.AC2 — Given... when... then...

- **Result:** ...

### Slice S2: {SLICE_TITLE}

#### S2.AC1 — ...

---

## Console errors during testing

Errors that appeared during AC verification (excluding baseline).

| Slice | AC | Error message | Source | Severity |
|---|---|---|---|---|
| S2 | 1 | `TypeError: Cannot read property 'id' of undefined` | `app.js:142` | error |

_If none: write "None."_

---

## Failed network requests during testing

Requests with status 4xx or 5xx that appeared during AC verification.

| Slice | AC | URL | Status | Method |
|---|---|---|---|---|
| S2 | 1 | `/api/users/me` | 401 | GET |

_If none: write "None."_

---

## Recommendation

If verdict is **READY FOR REVIEW**: All declared ACs pass in the browser. No new console errors. No failed network requests. Proceed to PR review.

If verdict is **ISSUES FOUND**: Listed below as actionable items:

1. **{slice}.{ac}** — {one-line description of what is broken and a guess at root cause}
2. ...

This skill does not attempt fixes. Surface to human for triage.