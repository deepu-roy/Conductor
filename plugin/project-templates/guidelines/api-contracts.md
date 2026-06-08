# API contracts

> Consumed by contract-dev, backend-dev, frontend-dev, security-review. Keep concrete.

## Contract location

- [NEEDS HUMAN INPUT] — e.g. "OpenAPI at `contracts/openapi.yaml`. One file for all services."

## Contract format

- [NEEDS HUMAN INPUT] — OpenAPI 3.x / GraphQL SDL / shared types (`contracts/types.ts`, `contracts/Contracts/*.cs`)

## Codegen

- [NEEDS HUMAN INPUT] — e.g. "Frontend: `pnpm codegen:api` generates `apps/web/src/api/generated.ts`. Backend: `dotnet run --project tools/ContractGen`."
- Generated files must NEVER be hand-edited. Regenerate.

## Versioning

- Breaking changes require a new version path (`/v2/...`) or GraphQL deprecation marker.
- Contract changes require an ADR if they break existing consumers.

## Field conventions

- [NEEDS HUMAN INPUT] — e.g. "camelCase in JSON. ISO-8601 for dates. All money as integer cents."
- Pagination: [NEEDS HUMAN INPUT] — cursor-based or offset-based, agreed per project.
- Error shape: [NEEDS HUMAN INPUT] — standard problem-details object, or project-specific.

## PII catalog

> List fields that are PII. Security-review references this.

- [NEEDS HUMAN INPUT] — e.g. `user.email`, `user.phone`, `user.fullName`, `billing.address.*`

## Auth

- All endpoints are authenticated by default. Public endpoints are listed explicitly:
- [NEEDS HUMAN INPUT] — e.g. `GET /health`, `POST /auth/login`
