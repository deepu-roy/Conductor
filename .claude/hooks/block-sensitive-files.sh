#!/usr/bin/env bash
# Hook: PreToolUse on Edit|Write
# Purpose: Block writes to secret files, pipeline configs, and master skills.
# Exit 2 = block and feed error back to Claude.

set -euo pipefail

payload=$(cat)
file=$(echo "$payload" | jq -r '.tool_input.file_path // empty')

# Empty file path (e.g. tool without file_path) — allow.
[[ -z "$file" ]] && exit 0

# Normalise: strip leading ./ and absolute-path prefix beyond repo root.
file="${file#./}"

block() {
  echo "BLOCKED by block-sensitive-files: $file" >&2
  echo "Reason: $1" >&2
  echo "If this is intentional, a human must author the change." >&2
  exit 2
}

case "$file" in
  # Secrets
  *.env|*.env.*|*.pem|*.key|*.p12|*.pfx|*secret*|*secrets*|*credentials*|*.pgpass|*id_rsa*|*id_ed25519*)
    block "Looks like a secret or credential file."
    ;;
  # Pipeline configs
  .azure-pipelines/*|*/.azure-pipelines/*|azure-pipelines.yml|.github/workflows/*|*/.github/workflows/*|.gitlab-ci.yml|Jenkinsfile)
    block "CI/pipeline configuration. Infra edits require a human author."
    ;;
  # Master skills (project overrides go in shared/project/)
  shared/skills/*|*/shared/skills/*|.claude/skills/*|*/.claude/skills/*|.claude/CLAUDE.md|*/.claude/CLAUDE.md|.claude/settings.json|.claude/mcp.json)
    block "Master skills and global .claude/ config are read-only. Customize via .claude/project/."
    ;;
  # Scope-enforce rules themselves
  .claude/agents/scope-map.json|*/.claude/agents/scope-map.json|shared/agents/scope-map.json|*/shared/agents/scope-map.json)
    block "scope-map.json is protected; a subagent cannot rewrite its own scope."
    ;;
esac

exit 0
