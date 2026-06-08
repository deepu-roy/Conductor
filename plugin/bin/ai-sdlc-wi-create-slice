#!/usr/bin/env bash
# Usage: ado-wi-create-slice.sh <parent-work-item-id> <slice-yaml-file>
# Creates a Task work item as a child of <parent-id>, using the slice YAML
# for title and description. Prints the created work item JSON.

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <parent-work-item-id> <slice-yaml-file>" >&2
  exit 2
fi

parent="$1"
yaml="$2"

if [[ ! -f "$yaml" ]]; then
  echo "Slice YAML not found: $yaml" >&2
  exit 2
fi

title=$(yq -r '.title // ""' "$yaml")
if [[ -z "$title" || "$title" == "null" ]]; then
  echo "Slice YAML missing .title" >&2
  exit 2
fi

slice_id=$(yq -r '.id // ""' "$yaml")
layer=$(yq -r '.layer // ""' "$yaml")

# Full YAML becomes the description so implement-slice can parse it back out.
description=$(printf '<pre>%s</pre>' "$(cat "$yaml")")

# Create the task.
created=$(az boards work-item create \
  --type "Task" \
  --title "[$slice_id] $title" \
  --description "$description" \
  --fields "System.Tags=ai-sdlc;layer-$layer" \
  --output json)

wi_id=$(echo "$created" | jq -r '.id')

# Link as child of parent.
az boards work-item relation add \
  --id "$wi_id" \
  --relation-type "parent" \
  --target-id "$parent" \
  --output json >/dev/null

echo "$created"
