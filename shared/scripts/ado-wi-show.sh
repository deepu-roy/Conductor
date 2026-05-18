#!/usr/bin/env bash
# Usage: ado-wi-show.sh <work-item-id>
# Prints the work item as JSON to stdout.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <work-item-id>" >&2
  exit 2
fi

az boards work-item show --id "$1" --output json
