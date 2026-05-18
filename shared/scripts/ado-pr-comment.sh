#!/usr/bin/env bash
# Usage: ado-pr-comment.sh <pr-id> <status> <comment-text-or-@file>
# status: active | byDesign | closed | fixed | pending | unknown | wontFix
# If the third arg starts with '@', the rest is a file path to read.

set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <pr-id> <status> <comment-text-or-@file>" >&2
  exit 2
fi

pr="$1"
status="$2"
body="$3"

if [[ "$body" == @* ]]; then
  body_file="${body:1}"
  if [[ ! -f "$body_file" ]]; then
    echo "Comment file not found: $body_file" >&2
    exit 2
  fi
  body="$(cat "$body_file")"
fi

az repos pr thread create \
  --pull-request-id "$pr" \
  --comments "$body" \
  --status "$status" \
  --output json
