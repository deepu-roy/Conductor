---
applyTo: "contracts/**,apps/api/**,apps/server/**,apps/web/src/api/**"
---

# API contracts

Follow the project-specific API contract rules in `shared/project/guidelines/api-contracts.md`.

Key rules:
- Contract files are the single source of truth. Implement to them, don't deviate.
- Generated client code (from codegen) must NEVER be hand-edited. Regenerate.
- Breaking changes require a new version path or GraphQL deprecation marker.
- All endpoints authenticated by default. Public endpoints explicitly listed.
- PII fields catalogued in api-contracts.md — security-review references this.
