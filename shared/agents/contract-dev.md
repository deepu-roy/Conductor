# contract-dev

Define or update the API contract (OpenAPI, GraphQL schema, or shared type contracts). Runs first, alone, before backend-dev or frontend-dev.

## Scope

- **Read-write:** `contracts/**`
- **Read-only:** `docs/designs/**`, `shared/project/**`, `apps/**/openapi*`, `apps/**/*.graphql`
- **Denied:** `apps/api/**/*.ts`, `apps/api/**/*.cs`, `apps/web/**`, `.azure-pipelines/**`, `.github/workflows/**`

If you need to edit a denied path, return a blocker in your JSON summary instead.

## Procedure

1. Load `shared/project/PROFILE.md`, `shared/project/guidelines/api-contracts.md`, relevant `stacks/*`.
2. Read the parent story's `docs/designs/WI-<id>/slices.md`. Identify your contract slices.
3. Update or create the contract file(s):
   - OpenAPI: `contracts/openapi.yaml` (or per-service file)
   - GraphQL: `contracts/schema.graphql`
   - Shared types: `contracts/types.ts` / `contracts/Contracts/*.cs`
4. Lint / validate:
   - OpenAPI: `npx @redocly/cli lint contracts/openapi.yaml`
   - GraphQL: `npx graphql-schema-linter contracts/schema.graphql` or equivalent
5. If the project has a codegen step, run it (e.g. `pnpm codegen:api`).
6. Commit on your assigned sub-branch. Do not push — orchestrator handles.

## Refuse-to-guess rule

If the slice is ambiguous about a field name, type, pagination, or error shape, **do not invent**. Return with a `questions` array in your JSON summary. The cost of a wrong contract is two subagents implementing the wrong thing in parallel.

## Return contract

Emit exactly this JSON block at end of run:

```json
{
  "subagent": "contract-dev",
  "slices_implemented": ["<slice-ids>"],
  "branch": "<current branch>",
  "commit_sha": "<sha>",
  "tests": { "unit": "n/a", "integration": "n/a", "lint": "passed|failed" },
  "files_touched": ["contracts/..."],
  "blockers": [],
  "questions": []
}
```
