---
name: verify-story
description: Verify implemented story acceptance criteria by driving a real Chrome browser via MCP. Reads ACs from slices.md, performs each Given/When/Then in the browser, screenshots the result, and writes a verification report. Run after implement-story, before PR review. Requires the app to be running locally and Chrome MCP connected.
argument-hint: "<work-item-id>"
allowed-tools: Read, Write, Bash(git:*), Bash(curl:*), Bash(yq:*), Bash(jq:*), Bash(ai-sdlc-*), mcp__chrome__navigate, mcp__chrome__screenshot, mcp__chrome__click, mcp__chrome__type, mcp__chrome__find, mcp__chrome__get_page_text, mcp__chrome__read_console_messages, mcp__chrome__read_network_requests, mcp__chrome__form_input
---

# Browser verification — WI-$1

You verify that the implementation of work item **$1** actually works in a real browser, by driving Chrome through the MCP and walking each declared acceptance criterion.

## Hard rules

1. **Load project context first.** Read `shared/project/PROFILE.md`, `shared/project/CLAUDE.md`, `shared/project/overrides/verify-story.md`, and `shared/project/guidelines/*`. Abort if PROFILE.md missing.
2. **Verify only declared ACs.** Read `docs/designs/WI-$1/slices.md`. Verify each Given/When/Then exactly. Do not test things not in the document.
3. **Screenshot every check.** Pass or fail, every AC gets a screenshot saved to `docs/designs/WI-$1/screenshots/`.
4. **Never enter real credentials.** Use only test accounts from `shared/project/overrides/verify-story.md`. If credentials missing, return BLOCKED for that AC.
5. **Do not fix failures.** Surface them to the human. Your job is to report, not to repair.
6. **Abort early if app not running.** Hit the healthcheck. If it fails, do not retry — exit with a clear message.

## Procedure

### Step 1 — Load context

Read in order:
- `shared/project/PROFILE.md`
- `shared/project/CLAUDE.md` (if present)
- `shared/project/overrides/verify-story.md` (if present)
- `shared/project/guidelines/*.md`
- `docs/designs/WI-$1/slices.md`
- `docs/designs/WI-$1/functional.md` (for context on user journeys)

Extract:
- Base URL: from `gates.healthcheck.frontend` in PROFILE.md, or default `http://localhost:3000`
- Test credentials: from `overrides/verify-story.md`
- All ACs grouped by slice from `slices.md`

### Step 2 — Confirm app is running (auto-start if needed)

Read startup config from PROFILE.md:

```bash
HEALTH_FRONTEND=$(yq -r '.gates.healthcheck.frontend // "n/a"' shared/project/PROFILE.md)
HEALTH_BACKEND=$(yq -r '.gates.healthcheck.backend // "n/a"' shared/project/PROFILE.md)
START_FRONTEND=$(yq -r '.gates.startup.frontend // "n/a"' shared/project/PROFILE.md)
START_BACKEND=$(yq -r '.gates.startup.backend // "n/a"' shared/project/PROFILE.md)
WAIT_SECS=$(yq -r '.gates.startup_wait_seconds // 15' shared/project/PROFILE.md)
```

Check backend first, then frontend. For each, if the healthcheck fails, auto-start it:

```bash
# ── Backend ──────────────────────────────────────────────────────────────────
if [[ "$HEALTH_BACKEND" != "n/a" ]]; then
  if ! eval "$HEALTH_BACKEND" 2>/dev/null; then
    echo "Backend not running — starting with: $START_BACKEND"
    eval "$START_BACKEND" &
    BACKEND_PID=$!
    echo "Waiting ${WAIT_SECS}s for backend to come up..."
    sleep "$WAIT_SECS"
    if ! eval "$HEALTH_BACKEND" 2>/dev/null; then
      echo "BLOCKED: backend failed to start. Check logs."
      kill "$BACKEND_PID" 2>/dev/null || true
      exit 1
    fi
    echo "Backend is up."
  else
    echo "Backend already running."
  fi
fi

# ── Frontend ─────────────────────────────────────────────────────────────────
if [[ "$HEALTH_FRONTEND" == "n/a" ]]; then
  echo "BLOCKED: no healthcheck configured for frontend in PROFILE.md"
  exit 1
fi

if ! eval "$HEALTH_FRONTEND" 2>/dev/null; then
  echo "Frontend not running — starting with: $START_FRONTEND"
  eval "$START_FRONTEND" &
  FRONTEND_PID=$!
  echo "Waiting ${WAIT_SECS}s for frontend to come up..."
  sleep "$WAIT_SECS"
  if ! eval "$HEALTH_FRONTEND" 2>/dev/null; then
    echo "BLOCKED: frontend failed to start. Check logs."
    kill "$FRONTEND_PID" 2>/dev/null || true
    exit 1
  fi
  echo "Frontend is up."
else
  echo "Frontend already running."
fi
```

### Step 3 — Confirm Chrome MCP available

If `mcp__chrome__navigate` is not in your available tools, abort with:

```
BLOCKED: Chrome MCP not connected.
Run: claude mcp add chrome
Then enable the Chrome extension for localhost.
```

### Step 4 — Capture baseline

Before any AC interaction, capture the clean state:

1. `mcp__chrome__navigate` → base URL
2. `mcp__chrome__read_console_messages` → save as `baseline_console`
3. `mcp__chrome__read_network_requests` → save as `baseline_network`
4. `mcp__chrome__screenshot` → save as `screenshots/baseline.png`

Note any pre-existing console errors. These will be excluded from the "new errors" count in the final report — they're not caused by this story.

### Step 5 — Authenticate if required

If `slices.md` ACs require a logged-in user, log in once at the start:

1. Navigate to login route (from `overrides/verify-story.md`)
2. `mcp__chrome__type` → email field with `test_user.email`
3. `mcp__chrome__type` → password field with `test_user.password`
4. `mcp__chrome__click` → submit
5. Verify successful redirect / logged-in state via `mcp__chrome__find` or `mcp__chrome__get_page_text`

If login fails, all subsequent ACs that require auth become BLOCKED.

### Step 6 — Verify each AC

For each slice in `slices.md`, for each AC in that slice:

```
For AC <slice-id>.<ac-num>:
  1. Read the Given / When / Then
  2. Navigate to the route implied by Given (or stay on current page)
  3. Perform the When action(s):
     - Click → mcp__chrome__click with selector
     - Type  → mcp__chrome__type with selector + text
     - Form  → mcp__chrome__form_input for multi-field
     - Wait  → 2 second pause after async actions
  4. Verify the Then outcome:
     - Element visible → mcp__chrome__find returns the element
     - Text present    → mcp__chrome__get_page_text contains the text
     - Toast / banner  → mcp__chrome__find with appropriate selector
  5. Read console for new errors → mcp__chrome__read_console_messages
  6. Read network for new failed requests → mcp__chrome__read_network_requests
  7. Screenshot → mcp__chrome__screenshot, save as
     screenshots/<slice-id>-ac<ac-num>.png
  8. Record result: PASS | FAIL | BLOCKED
```

**Result definitions:**
- **PASS** — Then outcome verified, no new console errors, no new failed network requests
- **FAIL** — Then outcome not observed within 5 seconds, OR new console error, OR new failed network request related to the AC
- **BLOCKED** — Could not reach the state needed to test (e.g. requires data that doesn't exist, requires auth that failed, requires another slice to be implemented first)

### Step 7 — Write verification report

Write to `docs/designs/WI-$1/verification.md` using the template in this skill's `report-template.md`. The orchestrator will read this file, so the structure must match.

Required top-level sections in order:
1. Header (timestamp, base URL, run ID)
2. Summary table
3. Verdict line
4. Pre-test baseline
5. AC results (grouped by slice)
6. Console errors during testing
7. Failed network requests during testing
8. Recommendation

### Step 8 — Commit the report

```bash
git add docs/designs/WI-$1/verification.md docs/designs/WI-$1/screenshots/
git commit -m "WI-$1: browser verification report"
```

Do not push — caller controls pushes.

### Step 9 — Post to PR (if PR exists)

Read the PR platform from the override file (defaults to `azure-devops`):

```bash
PR_PLATFORM=$(yq -r '.pr_platform // "azure-devops"' shared/project/overrides/verify-story.md 2>/dev/null || echo "azure-devops")
BRANCH=$(git branch --show-current)
REPORT_BODY=$(cat "docs/designs/WI-$1/verification.md")
```

**If `pr_platform: github`** — use `gh` CLI:

```bash
PR_ID=$(gh pr list --head "$BRANCH" --json number -q ".[0].number" 2>/dev/null | tr -d '\n')
if [[ -n "$PR_ID" && "$PR_ID" != "null" ]]; then
  gh pr comment "$PR_ID" --body "$REPORT_BODY" 2>/dev/null && echo "✓ Comment posted" || echo "Could not post comment"
fi
```

**If `pr_platform: azure-devops`** — use `az` CLI:

```bash
PR_ID=$(az repos pr list --source-branch "$BRANCH" \
  --query '[0].pullRequestId' -o tsv 2>/dev/null)
if [[ -n "$PR_ID" ]]; then
  ai-sdlc-pr-comment "$PR_ID" active "$REPORT_BODY"
fi
```

If no PR is found for the current branch, skip silently.

### Step 10 — Return JSON summary

Emit exactly this block as the last output (no prose after):

```json
{
  "subagent": "verify-story",
  "work_item": "$1",
  "base_url": "<url>",
  "verdict": "READY_FOR_REVIEW | ISSUES_FOUND | BLOCKED",
  "acs": {
    "checked": 0,
    "passed": 0,
    "failed": 0,
    "blocked": 0
  },
  "console_errors_new": 0,
  "failed_requests_new": 0,
  "report_path": "docs/designs/WI-$1/verification.md",
  "screenshots_path": "docs/designs/WI-$1/screenshots/",
  "blockers": [],
  "questions": []
}
```

## Skip conditions

Return early with `verdict: SKIPPED` and a reason if any of these are true:

- `gates.startup.frontend` is `n/a` in PROFILE.md (no UI to verify)
- All slices have `layer: backend` only (no user-facing change)
- PROFILE.md has `gates.skip_browser_verification: true`
- Chrome MCP not available

The skip is not a failure — emit the JSON with `verdict: SKIPPED` and the reason in `blockers[0]`.
