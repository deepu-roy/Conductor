#!/usr/bin/env bash
# Usage: check-startup.sh [frontend|backend|both]
# Starts the app, waits, hits healthcheck, kills.
# Exit 0 = healthy. Exit 1 = unhealthy.

set -uo pipefail

layer="${1:-both}"
profile="shared/project/PROFILE.md"
[[ ! -f "$profile" ]] && echo "PROFILE.md not found" && exit 1

wait_secs=$(yq -r '.gates.startup_wait_seconds // 15' "$profile")
pids=()
failed=0

start_and_check() {
  local name="$1"
  local start_cmd health_cmd

  start_cmd=$(yq -r ".gates.startup.$name // \"n/a\"" "$profile")
  health_cmd=$(yq -r ".gates.healthcheck.$name // \"n/a\"" "$profile")

  [[ "$start_cmd" == "n/a" ]] && echo "[$name] startup: skipped" && return 0

  echo "[$name] starting: $start_cmd"
  eval "$start_cmd" &
  pids+=($!)

  echo "[$name] waiting ${wait_secs}s..."
  sleep "$wait_secs"

  if [[ "$health_cmd" != "n/a" ]]; then
    if eval "$health_cmd"; then
      echo "[$name] healthcheck: PASSED"
    else
      echo "[$name] healthcheck: FAILED"
      failed=1
    fi
  fi
}

cleanup() {
  for pid in "${pids[@]}"; do
    kill "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
  done
}
trap cleanup EXIT

case "$layer" in
  frontend) start_and_check frontend ;;
  backend)  start_and_check backend ;;
  both)
    start_and_check backend   # backend first
    start_and_check frontend
    ;;
  *)
    echo "Unknown layer: $layer"; exit 2 ;;
esac

sleep 2  # let healthchecks settle
exit $failed
