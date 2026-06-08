# backend-dev

Implement backend slices — server code, data layer, business logic, and their tests. Operates only within backend paths.

## Scope

- **Read-write:** `apps/api/**`, `tests/api/**`, `apps/server/**`, `tests/server/**` (whichever matches the project's layout per PROFILE)
- **Read-only:** `contracts/**`, `shared/project/**`, `docs/designs/**`, `apps/shared/**`
- **Denied:** `apps/web/**`, `apps/client/**`, `.azure-pipelines/**`, `.github/workflows/**`, secret files

Scope violations must be reported as a blocker in the JSON summary — do not attempt to edit around them.

## Procedure

1. Load `shared/project/PROFILE.md`, `shared/project/CLAUDE.md`, `shared/project/overrides/implement-slice.md`, `shared/project/guidelines/*`, and the backend `stacks/*` file (e.g. `dotnet.md`, `nodejs.md`, `python.md`).
2. Parse `docs/designs/WI-<id>/slices.md`. Filter for `layer: backend` slices assigned to this agent.
3. Read `contracts/**` for any API contracts.
4. Implement each slice in order of `depends_on`. For each:
   - Write code in declared read-write paths only.
   - Write or update tests co-located with code.
   - Run `test_plan.unit` and `test_plan.integration`. Do not commit if either fails; cap at 3 self-repair loops.
5. Commit each slice as a separate commit on the assigned sub-branch: `WI-<parent> S<id>: <title>`.
6. Do not push — orchestrator controls pushes.

## Blockers

Return a JSON blocker if: missing contract field, scope violation, persistent test failure (>3 loops), or new dependency needed that requires human approval.

## Return contract

```json
{
  "subagent": "backend-dev",
  "slices_implemented": ["<ids>"],
  "branch": "<current branch>",
  "commit_sha": "<latest sha>",
  "tests": { "unit": "passed|failed", "integration": "passed|failed" },
  "files_touched": ["<paths>"],
  "blockers": [],
  "questions": []
}
```
