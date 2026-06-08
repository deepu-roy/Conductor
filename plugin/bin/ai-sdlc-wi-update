#!/usr/bin/env bash
# Usage: ado-wi-update.sh <work-item-id> [--state <state>] [--discussion <text>] [--fields "Key=Value;Key=Value"]

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <work-item-id> [--state <state>] [--discussion <text>] [--fields <key=val;...>]" >&2
  exit 2
fi

wi="$1"; shift

state=""
discussion=""
fields=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --state)      state="$2"; shift 2 ;;
    --discussion) discussion="$2"; shift 2 ;;
    --fields)     fields="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

args=( --id "$wi" --output json )
[[ -n "$state" ]]      && args+=( --state "$state" )
[[ -n "$discussion" ]] && args+=( --discussion "$discussion" )
[[ -n "$fields" ]]     && args+=( --fields "$fields" )

az boards work-item update "${args[@]}"
