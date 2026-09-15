#!/usr/bin/env bash
# Open, close, and check the service. This is the runbook for class day.
#
#   ./scripts/ops.sh status
#   ./scripts/ops.sh open   [hours]   # default 8
#   ./scripts/ops.sh close
#   ./scripts/ops.sh warm             # beat the cold start before you start
set -euo pipefail

: "${RG:=rg-frank-service}"
: "${APP:?set APP to the function app name printed by provision.sh}"

HOST=$(az functionapp show -n "$APP" -g "$RG" --query defaultHostName -o tsv)
COHORT=$(az functionapp config appsettings list -n "$APP" -g "$RG" \
  --query "[?name=='COHORT'].value|[0]" -o tsv)
OPS_TOKEN=$(az functionapp config appsettings list -n "$APP" -g "$RG" \
  --query "[?name=='OPS_TOKEN'].value|[0]" -o tsv)
URL="https://$HOST/v1/b/$COHORT"

case "${1:-status}" in
  status)
    echo "$URL"
    echo
    curl -fsS -H "x-ops: $OPS_TOKEN" "$URL" | python3 -m json.tool
    echo
    # What a student's pipeline actually sees, without printing the value.
    CODE=$(curl -s -o /dev/null -w '%{http_code}' "$URL")
    BYTES=$(curl -s "$URL" | wc -c | tr -d ' ')
    echo "anonymous GET -> HTTP $CODE, $BYTES bytes"
    [ "$CODE" = "200" ] && echo "students can deploy" || echo "students CANNOT deploy"
    ;;
  open)
    HOURS="${2:-8}"
    UNTIL=$(python3 -c "import datetime;print((datetime.datetime.now(datetime.UTC)+datetime.timedelta(hours=$HOURS)).strftime('%Y-%m-%dT%H:%M:%SZ'))")
    az functionapp config appsettings set -n "$APP" -g "$RG" \
      --settings ENABLED=true "OPEN_UNTIL=$UNTIL" -o none
    echo "open until $UNTIL (it closes itself; you do not have to remember)"
    ;;
  close)
    az functionapp config appsettings set -n "$APP" -g "$RG" --settings ENABLED=false -o none
    echo "closed"
    ;;
  warm)
    # Consumption plans cold-start. Do this before the room starts pushing.
    for i in 1 2 3; do curl -s -o /dev/null -w "  %{http_code} in %{time_total}s\n" "$URL"; done
    ;;
  *)
    echo "usage: $0 {status|open [hours]|close|warm}" >&2; exit 1 ;;
esac
