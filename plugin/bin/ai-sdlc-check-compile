#!/usr/bin/env bash
# Usage: check-compile.sh <layer> [frontend|backend|both]
# Reads compile commands from shared/project/PROFILE.md and runs them.
# Exit 0 = all passed. Exit 1 = at least one failed.

set -euo pipefail

layer="${1:-both}"
profile="shared/project/PROFILE.md"
[[ ! -f "$profile" ]] && echo "PROFILE.md not found" && exit 1

failed=0

run_compile() {
  local name="$1"
  local cmd
  cmd=$(yq -r ".gates.compile.$name // \"n/a\"" "$profile")
  [[ "$cmd" == "n/a" || -z "$cmd" ]] && echo "[$name] compile: skipped" && return 0

  echo "[$name] compiling: $cmd"
  if eval "$cmd" 2>&1; then
    echo "[$name] compile: PASSED"
  else
    echo "[$name] compile: FAILED"
    failed=1
  fi
}

case "$layer" in
  frontend) run_compile frontend ;;
  backend)  run_compile backend ;;
  both)     run_compile frontend; run_compile backend ;;
  *)        echo "Unknown layer: $layer"; exit 2 ;;
esac

exit $failed
