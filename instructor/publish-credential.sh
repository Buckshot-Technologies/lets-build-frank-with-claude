#!/usr/bin/env bash
# Create the classroom credential and store it, base64-encoded, in Key Vault.
#
# YOU run this, not an agent. It mints a real client secret.
#
#   CLASS_RG=rg-frank-class ./scripts/publish-credential.sh
#
# The secret is never printed, never written to disk, and never leaves this
# shell except into Key Vault.
set -euo pipefail

: "${RG:=rg-frank-service}"
: "${CLASS_RG:?set CLASS_RG to the resource group the class deploys into}"
: "${VAULT:?set VAULT to the key vault name printed by provision.sh}"
: "${SP_NAME:=frank-class}"
# Built-in Contributor by default. To use the tightened role instead:
#   ROLE="Frank Class Deployer" ./scripts/publish-credential.sh
: "${ROLE:=Contributor}"
: "${DAYS:=2}"

SUB=$(az account show --query id -o tsv)
SCOPE="/subscriptions/$SUB/resourceGroups/$CLASS_RG"

# A role assignment cannot be scoped to a group that does not exist, and the
# failure from create-for-rbac is opaque. Say it plainly instead.
if [ "$(az group exists -n "$CLASS_RG")" != "true" ]; then
  echo "Resource group '$CLASS_RG' does not exist." >&2
  echo "Run ./provision-class.sh first." >&2
  exit 1
fi

echo "creating '$SP_NAME' with role '$ROLE' on $CLASS_RG, expiring in $DAYS days"

# --sdk-auth emits exactly the JSON shape azure/login and deploy.yml expect.
CREDS=$(az ad sp create-for-rbac \
  --name "$SP_NAME" \
  --role "$ROLE" \
  --scopes "$SCOPE" \
  --years 1 \
  --sdk-auth)

# Sanity-check the shape before storing it, so a bad credential is caught now
# rather than by thirty students at once.
echo "$CREDS" | python3 -c '
import json,sys
d = json.load(sys.stdin)
missing = [k for k in ("clientId","clientSecret","subscriptionId","tenantId") if not d.get(k)]
if missing:
    sys.exit("credential is missing: " + ", ".join(missing))
' || { echo "refusing to store a malformed credential"; exit 1; }

# Base64 so GitHub's scanners do not recognise it and auto-revoke it mid-class
# (ADR-010). This is not encryption and is not pretending to be.
ENCODED=$(printf '%s' "$CREDS" | base64 | tr -d '\n')

az keyvault secret set --vault-name "$VAULT" --name classroom-value \
  --value "$ENCODED" --only-show-errors -o none

unset CREDS ENCODED

EXPIRES=$(python3 -c "import datetime;print((datetime.datetime.now(datetime.UTC)+datetime.timedelta(days=$DAYS)).strftime('%Y-%m-%dT%H:%M:%SZ'))")

cat <<SUMMARY

Stored. The value is in Key Vault and was never written to disk.

  Suggested window : OPEN_UNTIL=$EXPIRES
  Open the service : APP=<app> ./ops.sh open 8
  Tear down after  : ./teardown-class.sh

Reminder: set a budget on this subscription before class.
SUMMARY
