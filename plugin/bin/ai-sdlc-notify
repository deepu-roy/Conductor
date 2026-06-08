#!/usr/bin/env bash
# Usage: notify.sh <message...>
# Reads orchestration.notifications from shared/project/PROFILE.md.
# Supports type: slack | teams | webhook
# Fails quietly if not configured.

set -euo pipefail

profile="shared/project/PROFILE.md"
msg="$*"

if [[ -z "$msg" ]]; then
  echo "Usage: $0 <message>" >&2
  exit 2
fi

if [[ ! -f "$profile" ]]; then
  echo "PROFILE.md not found; skipping notification." >&2
  exit 0
fi

notif_type=$(yq -r '.orchestration.notifications.type // ""' "$profile" 2>/dev/null || echo "")
webhook_url=$(yq -r '.orchestration.notifications.webhook_url // ""' "$profile" 2>/dev/null || echo "")

if [[ -z "$notif_type" || -z "$webhook_url" || "$webhook_url" == "null" || "$webhook_url" == *"NEEDS HUMAN INPUT"* ]]; then
  echo "Notifications not configured; skipping." >&2
  exit 0
fi

case "$notif_type" in
  slack)
    channel=$(yq -r '.orchestration.notifications.channel // ""' "$profile" 2>/dev/null || echo "")
    payload=$(jq -n --arg t "$msg" --arg c "$channel" \
      'if $c != "" then {text: $t, channel: $c} else {text: $t} end')
    curl -sS -X POST -H 'Content-type: application/json' \
      --data "$payload" "$webhook_url" >/dev/null
    echo "Slack notification sent."
    ;;
  teams)
    payload=$(jq -n --arg t "$msg" '{"@type":"MessageCard","@context":"https://schema.org/extensions","text":$t}')
    curl -sS -X POST -H 'Content-type: application/json' \
      --data "$payload" "$webhook_url" >/dev/null
    echo "Teams notification sent."
    ;;
  webhook)
    payload=$(jq -n --arg t "$msg" '{text: $t, timestamp: (now | todate)}')
    curl -sS -X POST -H 'Content-type: application/json' \
      --data "$payload" "$webhook_url" >/dev/null
    echo "Webhook notification sent."
    ;;
  *)
    echo "Unknown notification type: $notif_type" >&2
    exit 1
    ;;
esac
