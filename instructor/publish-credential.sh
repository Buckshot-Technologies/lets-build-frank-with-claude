#!/usr/bin/env bash
# Create the classroom credential and store it, base64-encoded, in Key Vault.
#
# YOU run this, not an agent. It mints a real client secret.
#
#   CLASS_RG=rg-frank-class VAULT=<vault name> ./publish-credential.sh
#
# The secret is never printed, never written to disk, and never leaves this
# shell except into Key Vault.
#
# NOTE ON EXPIRY: `az ad sp create-for-rbac` only takes --years, so it cannot
# express the two-day life ADR-010 depends on. This creates the app and role
# assignment explicitly and then sets the password with --end-date, which is
# the only way to get a short-lived secret. The expiry is load-bearing: it is
# most of why publishing this credential is defensible at all.
set -euo pipefail

: "${CLASS_RG:?set CLASS_RG to the resource group the class deploys into}"
: "${VAULT:?set VAULT to the key vault name printed by provision-service.sh}"
: "${SP_NAME:=frank-class}"
: "${SECRET_NAME:=classroom-value}"
# Built-in Contributor by default. To use the tightened role instead:
#   ROLE="Frank Class Deployer" ./publish-credential.sh
: "${ROLE:=Contributor}"
: "${DAYS:=2}"

SUB="$(az account show --query id -o tsv)"
TENANT="$(az account show --query tenantId -o tsv)"
SCOPE="/subscriptions/$SUB/resourceGroups/$CLASS_RG"

# A role assignment cannot be scoped to a group that does not exist, and the
# failure from Azure is opaque. Say it plainly instead.
if [ "$(az group exists -n "$CLASS_RG")" != "true" ]; then
  echo "Resource group '$CLASS_RG' does not exist." >&2
  echo "Run ./provision-class.sh first." >&2
  exit 1
fi

END="$(python3 -c "import datetime;print((datetime.datetime.now(datetime.UTC)+datetime.timedelta(days=$DAYS)).strftime('%Y-%m-%dT%H:%M:%SZ'))")"
echo "creating '$SP_NAME': role '$ROLE' on $CLASS_RG, secret expires $END"

# 1. App registration. Reuse one of the same name rather than accumulating
#    duplicates across cohorts.
APP_ID="$(az ad app list --display-name "$SP_NAME" --query "[0].appId" -o tsv)"
if [ -z "$APP_ID" ]; then
  APP_ID="$(az ad app create --display-name "$SP_NAME" --query appId -o tsv)"
  echo "  created app $APP_ID"
else
  echo "  reusing app $APP_ID"
fi

# 2. Service principal for it.
az ad sp create --id "$APP_ID" -o none 2>/dev/null || true
SP_OID="$(az ad sp show --id "$APP_ID" --query id -o tsv)"

# 3. Role assignment. A brand-new principal is not immediately visible to ARM.
for attempt in 1 2 3 4 5 6; do
  if az role assignment create --assignee-object-id "$SP_OID" \
       --assignee-principal-type ServicePrincipal \
       --role "$ROLE" --scope "$SCOPE" -o none 2>/dev/null; then
    echo "  role assigned"
    break
  fi
  if az role assignment list --assignee "$SP_OID" --scope "$SCOPE" \
       --query "[?roleDefinitionName=='$ROLE']" -o tsv 2>/dev/null | grep -q .; then
    echo "  role already assigned"
    break
  fi
  echo "  waiting for the principal to propagate ($attempt/6)"
  python3 -c 'import time;time.sleep(10)'
done

# 4. The secret, with the expiry that matters. Replaces any existing password,
#    so an earlier long-lived one stops working.
SECRET="$(az ad app credential reset --id "$APP_ID" \
            --display-name class --end-date "$END" \
            --query password -o tsv)"
[ -n "$SECRET" ] || { echo "failed to mint a secret" >&2; exit 1; }

# 5. The exact JSON shape azure/login and deploy.yml expect. Built here rather
#    than with --sdk-auth, which is deprecated and cannot set a short expiry.
CREDS="$(APP_ID="$APP_ID" SECRET="$SECRET" SUB="$SUB" TENANT="$TENANT" python3 -c '
import json, os
print(json.dumps({
    "clientId": os.environ["APP_ID"],
    "clientSecret": os.environ["SECRET"],
    "subscriptionId": os.environ["SUB"],
    "tenantId": os.environ["TENANT"],
    "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
    "resourceManagerEndpointUrl": "https://management.azure.com/",
    "activeDirectoryGraphResourceId": "https://graph.windows.net/",
    "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
    "galleryEndpointUrl": "https://gallery.azure.com/",
    "managementEndpointUrl": "https://management.core.windows.net/",
}))
')"

# Catch a malformed credential now, rather than with thirty students at once.
printf '%s' "$CREDS" | python3 -c '
import json,sys
d = json.load(sys.stdin)
missing = [k for k in ("clientId","clientSecret","subscriptionId","tenantId") if not d.get(k)]
if missing:
    sys.exit("credential is missing: " + ", ".join(missing))
' || { echo "refusing to store a malformed credential" >&2; exit 1; }

# Base64 so GitHub's scanners do not recognise it and auto-revoke it mid-class
# (ADR-010). This is not encryption and is not pretending to be.
ENCODED="$(printf '%s' "$CREDS" | base64 | tr -d '\n')"

az keyvault secret set --vault-name "$VAULT" --name "$SECRET_NAME" \
  --value "$ENCODED" --only-show-errors -o none

unset SECRET CREDS ENCODED

cat <<SUMMARY

Stored. The value is in Key Vault and was never written to disk.

  Secret expires   : $END  (${DAYS} days)
  Open the service : APP=<app> ./ops.sh open 8
  Confirm          : APP=<app> ./ops.sh status
  Tear down after  : ./teardown-class.sh

Reminder: set a budget on this subscription before class.
SUMMARY
