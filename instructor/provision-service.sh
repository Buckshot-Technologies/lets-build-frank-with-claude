#!/usr/bin/env bash
# Stand up the credential service. Creates infrastructure only — no credential
# is created or touched here. Run publish-credential.sh afterwards.
#
#   ./scripts/provision.sh
#
# Idempotent: safe to re-run. Prints the URL to paste into deploy.yml at the end.
set -euo pipefail

# Resolve the function source relative to this script, so it can be run from
# anywhere rather than only from the service directory.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_DIR="$HERE/credential-service"

: "${RG:=rg-frank-service}"
: "${LOCATION:=eastus}"
: "${COHORT:=2026-09}"
# Globally unique names. Override if these are taken.
: "${PREFIX:=frankclass}"
SUFFIX="$(echo "${PREFIX}${RG}" | shasum | head -c 6)"
: "${APP:=${PREFIX}svc${SUFFIX}}"
: "${VAULT:=${PREFIX}kv${SUFFIX}}"
: "${STORAGE:=${PREFIX}st${SUFFIX}}"

SUB=$(az account show --query id -o tsv)
echo "subscription : $SUB"
echo "group        : $RG ($LOCATION)"
echo "function app : $APP"
echo "key vault    : $VAULT"
echo

az group create -n "$RG" -l "$LOCATION" -o none

echo "==> key vault (RBAC mode, purge protection off so teardown is clean)"
az keyvault create -n "$VAULT" -g "$RG" -l "$LOCATION" \
  --enable-rbac-authorization true --retention-days 7 -o none

echo "==> storage (the Functions runtime requires one)"
az storage account create -n "$STORAGE" -g "$RG" -l "$LOCATION" \
  --sku Standard_LRS --allow-blob-public-access false -o none

echo "==> function app (Linux consumption, Node 22)"
az functionapp create -n "$APP" -g "$RG" \
  --storage-account "$STORAGE" \
  --consumption-plan-location "$LOCATION" \
  --runtime node --runtime-version 22 --functions-version 4 \
  --os-type Linux -o none

echo "==> managed identity -> Key Vault (read one secret, nothing else)"
az functionapp identity assign -n "$APP" -g "$RG" -o none
PRINCIPAL=$(az functionapp identity show -n "$APP" -g "$RG" --query principalId -o tsv)
# Eventual consistency: the new principal is not always visible immediately.
for i in 1 2 3 4 5; do
  if az role assignment create --assignee-object-id "$PRINCIPAL" \
      --assignee-principal-type ServicePrincipal \
      --role "Key Vault Secrets User" \
      --scope "/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.KeyVault/vaults/$VAULT" \
      -o none 2>/dev/null; then
    echo "    role assigned"
    break
  fi
  echo "    waiting for the identity to propagate ($i/5)"
  sleep 10
done

# The vault is in RBAC mode, so "I created it" grants nothing. Without this the
# operator cannot write the value and publish-credential.sh dies with an opaque
# ForbiddenByRbac from Key Vault.
echo "==> operator -> Key Vault (write the value)"
ME=$(az ad signed-in-user show --query id -o tsv)
az role assignment create --assignee-object-id "$ME" \
  --assignee-principal-type User \
  --role "Key Vault Secrets Officer" \
  --scope "/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.KeyVault/vaults/$VAULT" \
  -o none 2>/dev/null || echo "    (already assigned, or assign it by hand)"

echo "==> settings"
OPS_TOKEN=$(openssl rand -hex 16)
az functionapp config appsettings set -n "$APP" -g "$RG" --settings \
  "KEYVAULT_URI=https://$VAULT.vault.azure.net/" \
  "SECRET_NAME=classroom-value" \
  "COHORT=$COHORT" \
  "ENABLED=false" \
  "OPEN_UNTIL=" \
  "OPS_TOKEN=$OPS_TOKEN" \
  -o none

echo "==> deploying the function"
TMP=$(mktemp -d)
cp -R "$SERVICE_DIR/package.json" "$SERVICE_DIR/host.json" "$SERVICE_DIR/src" "$TMP/"
( cd "$TMP" && zip -qr app.zip . )
az functionapp deployment source config-zip -n "$APP" -g "$RG" \
  --src "$TMP/app.zip" --build-remote true -o none
rm -rf "$TMP"

HOST=$(az functionapp show -n "$APP" -g "$RG" --query defaultHostName -o tsv)

cat <<SUMMARY

------------------------------------------------------------------
Provisioned. The service is CLOSED (ENABLED=false) and holds no value yet.

  URL for deploy.yml:
    https://$HOST/v1/b/$COHORT

  Ops token (keep this; it is how you check status):
    $OPS_TOKEN

Next:
  1. CLASS_RG=<class rg> VAULT=$VAULT ./publish-credential.sh
  2. APP=$APP ./ops.sh open 8
  3. APP=$APP ./ops.sh status

Then paste the URL above into CREDENTIAL_URL in .github/workflows/deploy.yml
on main. That one line is what makes every student's pipeline work.
------------------------------------------------------------------
SUMMARY
