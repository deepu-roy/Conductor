#!/usr/bin/env bash
# Usage: create-pr.sh --title <title> --body <body-or-@file> --branch <branch> [--base <base-branch>]
# Reads orchestration.repo_host from shared/project/PROFILE.md.
# Supports repo_host: github | azure-repos

set -euo pipefail

profile="shared/project/PROFILE.md"
title=""
body=""
branch=""
base="main"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title)  title="$2";  shift 2 ;;
    --body)   body="$2";   shift 2 ;;
    --branch) branch="$2"; shift 2 ;;
    --base)   base="$2";   shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$title" || -z "$branch" ]] && echo "Usage: $0 --title <t> --body <b> --branch <br> [--base <base>]" >&2 && exit 2

body_text="$body"
if [[ "$body" == @* ]]; then
  body_file="${body:1}"
  [[ ! -f "$body_file" ]] && echo "Body file not found: $body_file" >&2 && exit 2
  body_text="$(cat "$body_file")"
fi

if [[ ! -f "$profile" ]]; then
  echo "PROFILE.md not found; defaulting to github repo_host." >&2
  repo_host="github"
else
  repo_host=$(yq -r '.orchestration.repo_host // "github"' "$profile" 2>/dev/null || echo "github")
fi

case "$repo_host" in
  github)
    gh pr create \
      --title "$title" \
      --body "$body_text" \
      --head "$branch" \
      --base "$base"
    ;;
  azure-repos)
    az repos pr create \
      --title "$title" \
      --description "$body_text" \
      --source-branch "$branch" \
      --target-branch "$base" \
      --output json
    ;;
  *)
    echo "Unknown repo_host: $repo_host (expected github | azure-repos)" >&2
    exit 1
    ;;
esac
