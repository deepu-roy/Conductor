---
name: implement-slice
description: Implement a single slice. Used when a story has only one slice, or when a subagent is operating on a single slice within the orchestrator. Writes code, writes tests, runs tests, commits on a sub-branch.
argument-hint: "<slice-id>"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(git:*), Bash(jq:*), Bash(yq:*), Bash(shared/scripts/*)
---

# Implement one slice

Implement slice **$1**. You may be running standalone or as a subagent step.

## Hard rules

1. **Stay in scope.** Only modify paths listed as `read-write` in the slice. The scope-enforce hook blocks violations.
2. **Write tests.** Every slice has a `test_plan.unit` and usually `test_plan.integration`. Run them. Do not commit if they fail.
3. **Do not auto-install new dependencies.** If a slice requires a new package, stop and surface it as a blocker.
4. **Commit on the declared sub-branch only.** Do not push to `main`, `story/*`, or `design/*`.
5. **Return the standard JSON summary.**

## Procedure

### Step 1 — Load context

- `shared/project/PROFILE.md`
- `shared/project/overrides/implement-slice.md`
- `shared/project/guidelines/*`
- Relevant `stacks/*` per slice layer
- `docs/designs/WI-<parent>/slices.md` — find your slice by ID

### Step 2 — Understand the slice

Print (as reasoning, not output) the slice's AC, impact, risk, test plan, file scope. Confirm you understand before writing code.

### Step 3 — Implement

Write code. Keep changes within declared file scope. Follow `guidelines/*` for style, error handling, naming, testing.

### Step 4 — Write tests

- Unit tests first. One test per AC where possible.
- Integration test if the slice crosses a boundary (API, DB, file I/O).
- No vacuous tests (tests that pass without verifying behaviour).

### Step 5 — Run tests

```bash
<test_plan.unit command>
<test_plan.integration command>
```

If any fail, fix. Cap at 3 self-repair loops. If still failing, return with `blockers: ["tests failing: <summary>"]`.

### Step 6 — Compile check

Read `gates.compile.<layer>` from `shared/project/PROFILE.md`
where `<layer>` matches this slice's declared layer.
Skip if value is `n/a`.

```bash
COMPILE_CMD=$(yq -r '.gates.compile.<layer>' shared/project/PROFILE.md)
[[ "$COMPILE_CMD" == "n/a" ]] && echo "Compile check skipped" && exit 0

eval "$COMPILE_CMD" 2>&1 | tee /tmp/compile-output.txt
COMPILE_EXIT=${PIPESTATUS[0]}

if [[ $COMPILE_EXIT -ne 0 ]]; then
  # One self-repair loop for deterministic errors (missing import, wrong type)
  # Read the error, attempt fix, re-run once
  # If still failing → return blocker, do not commit
  echo "Compile failed — see /tmp/compile-output.txt"
  exit 1
fi
```

Cap self-repair at **1 loop** for compile errors only.
Do not self-repair if the same error persists after one fix attempt — return a blocker instead.

### Step 7 — Startup check

Read `gates.startup.<layer>` and `gates.healthcheck.<layer>` from PROFILE.md.
Skip entirely if either is `n/a`.

```bash
STARTUP_CMD=$(yq -r '.gates.startup.<layer>' shared/project/PROFILE.md)
HEALTH_CMD=$(yq -r '.gates.healthcheck.<layer>' shared/project/PROFILE.md)
WAIT=$(yq -r '.gates.startup_wait_seconds // 15' shared/project/PROFILE.md)

[[ "$STARTUP_CMD" == "n/a" ]] && echo "Startup check skipped" && exit 0

# Start app in background
eval "$STARTUP_CMD" &
APP_PID=$!
sleep "$WAIT"

# Healthcheck
eval "$HEALTH_CMD"
HEALTH_EXIT=$?

# Always kill the background process
kill $APP_PID 2>/dev/null
wait $APP_PID 2>/dev/null

if [[ $HEALTH_EXIT -ne 0 ]]; then
  echo "Startup check failed — app did not respond at healthcheck URL"
  # Do NOT self-repair startup failures — surface to human
  exit 1
fi

echo "Startup check passed"
```

**No self-repair for startup failures.** Add to blockers:
`"startup check failed — app unresponsive after $WAIT seconds"`.

### Step 8 — Commit

```bash
git add <files>
git commit -m "WI-<parent> S<id>: <slice title>"
```

Do not push — the orchestrator controls pushes for parallel safety.

### Step 9 — Return JSON summary

Emit exactly this block (no prose after):

```json
{
  "subagent": "<your subagent name or 'standalone'>",
  "slice": "$1",
  "branch": "<current branch>",
  "commit_sha": "<sha>",
  "tests": {
    "unit": "passed|failed",
    "integration": "passed|failed|n/a",
    "compile": "passed|failed|skipped",
    "startup": "passed|failed|skipped"
  },
  "files_touched": ["<paths>"],
  "blockers": [],
  "questions": []
}
```
