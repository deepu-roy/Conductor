# Naming conventions

> Consumed by implement-slice and pr-review. Keep concrete.

## Files

- Angular components: `kebab-case.component.ts` / `.html` / `.scss` (Angular CLI default).   # source: src/DevOnHire.Web structure
- Angular tests: `*.spec.ts`.   # source: Angular CLI default
- C# files: `PascalCase.cs`, one class per file.   # source: .NET conventions
- [NEEDS HUMAN INPUT] — confirm test file naming for backend (e.g. `FooServiceTests.cs`)

## Branches

- `design/WI-<id>` for design PRs.
- `story/WI-<id>` for feature branches.
- `story/WI-<id>-<layer>` for subagent sub-branches (e.g. `story/WI-173-backend`).
- Never force-push.

## Commits

- [NEEDS HUMAN INPUT] — confirm commit convention (Conventional Commits, or free-form?). Recent commits use free-form imperative style.   # source: git log
- First line: `WI-<id> S<slice-id>: <imperative summary>`.

## Work items

- Epic / Feature / Task hierarchy (ADO default).
- Child tasks created from slices are titled `[S<n>] <slice title>`.

## Identifiers in code

- C#: PascalCase for public members; camelCase for local vars/params.
- TypeScript: PascalCase for classes/interfaces/enums; camelCase for functions/vars.
- JSON API fields: camelCase.   # source: Newtonsoft.Json@13.0.3 default + ASP.NET Core default
- [NEEDS HUMAN INPUT] — confirm private field prefix (e.g. `_name` or just `name`)
