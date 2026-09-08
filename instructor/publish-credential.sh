#!/usr/bin/env bash
# Publish the classroom credential to a public blob, so students fetch it with
# one command instead of retyping it off a slide.
#
#   ./publish-credential.sh create    make the credential + bucket, print the one-liner
#   ./publish-credential.sh show      print the student one-liner again
#   ./publish-credential.sh revoke    delete the blob AND the app registration
#
# This is deliberately open. Read the risk note below before running it.
set -euo pipefail

RG="${RG:-rg-frank-class}"
LOCATION="${LOCATION:-eastus}"
APP_NAME="${APP_NAME:-frank-class}"
STATE=".class-credential"          # local: names of what we made, never the secret

command -v az >/dev/null || { echo "az CLI not found" >&2; exit 1; }

case "${1:-show}" in

create)
  SUB="$(az account show --query id -o tsv)"
  TENANT="$(az account show --query tenantId -o tsv)"
  echo "subscription : $SUB"
  echo "resource grp : $RG"
  echo

  # An unguessable container name. The blob is public — anyone with the URL can
  # read it — but it will not be found by crawling, which is the difference
  # between "the class can fetch it" and "the internet finds it in ten minutes".
  TOKEN="$(python3 -c 'import secrets;print(secrets.token_hex(8))')"
  SA="frankclass$(printf '%s' "$SUB" | tr -cd '[:alnum:]' | cut -c1-10)"

  echo "1/4  resource group"
  az group create --name "$RG" --location "$LOCATION" -o none

  echo "2/4  storage account ($SA)"
  az storage account create --name "$SA" --resource-group "$RG" \
    --location "$LOCATION" --sku Standard_LRS --allow-blob-public-access true -o none 2>/dev/null \
    || echo "     (exists)"
  KEY="$(az storage account keys list --account-name "$SA" -g "$RG" --query "[0].value" -o tsv)"

  echo "3/4  public container ($TOKEN)"
  az storage container create --name "$TOKEN" --account-name "$SA" --account-key "$KEY" \
    --public-access blob -o none

  echo "4/4  service principal, Contributor on $RG only, expires in 2 days"
  END="$(python3 -c 'import datetime;print((datetime.datetime.utcnow()+datetime.timedelta(days=2)).strftime("%Y-%m-%dT%H:%M:%SZ"))')"
  APP_ID="$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)"
  az ad sp create --id "$APP_ID" -o none 2>/dev/null || true
  SP_OID="$(az ad sp show --id "$APP_ID" --query id -o tsv)"
  SECRET="$(az ad app credential reset --id "$APP_ID" --append --display-name class \
              --end-date "$END" --query password -o tsv)"

  for attempt in 1 2 3 4 5 6; do
    az role assignment create --assignee-object-id "$SP_OID" \
      --assignee-principal-type ServicePrincipal --role Contributor \
      --scope "/subscriptions/$SUB/resourceGroups/$RG" -o none 2>/dev/null && break
    echo "     waiting for the principal to propagate ($attempt)"
    python3 -c 'import time;time.sleep(10)'
  done

  printf '{\n  "clientId": "%s",\n  "clientSecret": "%s",\n  "subscriptionId": "%s",\n  "tenantId": "%s"\n}\n' \
    "$APP_ID" "$SECRET" "$SUB" "$TENANT" > /tmp/azure-credentials.$$.json
  az storage blob upload --account-name "$SA" --account-key "$KEY" \
    --container-name "$TOKEN" --name azure.json --file /tmp/azure-credentials.$$.json \
    --overwrite -o none
  rm -f /tmp/azure-credentials.$$.json

  URL="https://$SA.blob.core.windows.net/$TOKEN/azure.json"
  printf 'SA=%s\nCONTAINER=%s\nAPP_ID=%s\nURL=%s\nEXPIRES=%s\n' "$SA" "$TOKEN" "$APP_ID" "$URL" "$END" > "$STATE"
  "$0" show
  ;;

show)
  [ -f "$STATE" ] || { echo "No credential published. Run: $0 create" >&2; exit 1; }
  # shellcheck disable=SC1090
  . "$STATE"
  cat <<BANNER

================================================================
  PUT THIS ON THE SCREEN
================================================================

  gh secret set AZURE_CREDENTIALS --body "\$(curl -s $URL)"
  git push origin main

================================================================

  Expires: $EXPIRES
  Scope:   Contributor on $RG only, nothing else in the subscription
  Revoke:  $0 revoke

BANNER
  ;;

revoke)
  [ -f "$STATE" ] || { echo "nothing to revoke" >&2; exit 1; }
  # shellcheck disable=SC1090
  . "$STATE"
  KEY="$(az storage account keys list --account-name "$SA" -g "$RG" --query "[0].value" -o tsv 2>/dev/null || true)"
  [ -n "$KEY" ] && az storage container delete --name "$CONTAINER" --account-name "$SA" \
    --account-key "$KEY" -o none 2>/dev/null && echo "blob container deleted"
  az ad app delete --id "$APP_ID" 2>/dev/null && echo "app registration deleted — the credential is dead"
  rm -f "$STATE"
  echo
  echo "The resource group still holds the students' apps. Delete it when you're done:"
  echo "  az group delete --name $RG --yes --no-wait"
  ;;

*) echo "usage: $0 create|show|revoke" >&2; exit 2 ;;
esac
