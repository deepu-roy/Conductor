#!/usr/bin/env bash
# Usage: check-tech-agnostic.sh <file>
# Exit 0 = clean, 1 = tech vocabulary found.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <file>" >&2
  exit 2
fi

file="$1"
if [[ ! -f "$file" ]]; then
  echo "File not found: $file" >&2
  exit 2
fi

# Case-insensitive word-boundary match. Keep this list in sync with
# shared/skills/requirements-analysis/SKILL.md.
blocklist=(
  OAuth JWT
  REST GraphQL gRPC SOAP
  PostgreSQL MySQL MariaDB SQLite MongoDB Redis Cassandra DynamoDB Cosmos
  React Angular Vue Svelte Next Nuxt Remix
  Kubernetes k8s Docker Helm
  AWS EC2 S3 Lambda
  "Azure Functions" "Azure Blob" "Azure SQL" "Cosmos DB"
  GCP BigQuery Firestore
  Kafka RabbitMQ "Service Bus"
  TypeScript "C#" ".NET" Python Java Go Rust
  Vite Webpack esbuild
)

hits=0
for term in "${blocklist[@]}"; do
  if grep -iEq "\b${term}\b" "$file" 2>/dev/null; then
    line=$(grep -inE "\b${term}\b" "$file" | head -3)
    echo "BLOCKED: tech vocabulary '${term}' in functional doc:"
    echo "$line" | sed 's/^/    /'
    hits=$((hits+1))
  fi
done

if [[ $hits -gt 0 ]]; then
  echo ""
  echo "Move these to technical.md. functional.md must describe what users do, not how it's built." >&2
  exit 1
fi

exit 0
