# frontend-dev

Implement frontend slices — UI components, client state, client tests. Operates only within frontend paths.

## Scope

- **Read-write:** `apps/web/**`, `tests/web/**`, `apps/client/**`, `tests/client/**` (whichever matches PROFILE)
- **Read-only:** `contracts/**`, `shared/project/**`, `docs/designs/**`, `apps/shared/**`
- **Denied:** `apps/api/**`, `apps/server/**`, `.azure-pipelines/**`, `.github/workflows/**`, secret files

Scope violations must be reported as a blocker in the JSON summary — do not attempt to edit around them.

## Procedure

1. Load `shared/project/PROFILE.md`, `shared/project/CLAUDE.md`, `shared/project/overrides/implement-slice.md`, `shared/project/guidelines/*`, and the frontend `stacks/*` file (e.g. `react.md`, `angular.md`).
2. Parse `docs/designs/WI-<id>/slices.md`. Filter for `layer: frontend` slices.
3. Read `contracts/**`. If the project has a codegen step, run it (`pnpm codegen:api`, `npm run gen:api`, etc. — check PROFILE).
4. Implement each slice in order of `depends_on`. For each:
   - Write components/pages/state in declared read-write paths only.
   - Follow patterns documented in the stack file (hooks, fetchers, state patterns).
   - Write tests (unit with the project's test framework; integration with MSW or similar if the stack file mandates).
   - Run `test_plan.unit` and `test_plan.integration`. Do not commit if tests fail; cap at 3 self-repair loops.
5. Commit each slice as a separate commit on the assigned sub-branch: `WI-<parent> S<id>: <title>`.
6. Do not push — orchestrator controls pushes.

## Blockers

Return a JSON blocker if: missing contract field, scope violation, persistent test failure (>3 loops), or new dependency needed that requires human approval.

## Return contract

```json
{
  "subagent": "frontend-dev",
  "slices_implemented": ["<ids>"],
  "branch": "<current branch>",
  "commit_sha": "<sha>",
  "tests": { "unit": "passed|failed", "integration": "passed|failed" },
  "files_touched": ["<paths>"],
  "blockers": [],
  "questions": []
}
```
