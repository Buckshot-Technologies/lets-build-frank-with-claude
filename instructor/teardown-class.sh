#!/usr/bin/env bash
# Tear down the classroom (ADR-010). Three things exist; delete all three.
#
#   ./teardown-class.sh --list      what would go (default, safe)
#   ./teardown-class.sh --confirm
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
RG="${RG:-rg-frank-class}"
MODE="${1:---list}"

SUB="$(az account show --query id -o tsv)"
echo "subscription: $SUB"; echo

echo "1. the published credential"
if [ -f .class-credential ]; then echo "   published — ./publish-credential.sh revoke kills it"
else echo "   none published (or already revoked)"; fi

echo "2. the class resource group: $RG"
if az group show --name "$RG" -o none 2>/dev/null; then
  az resource list -g "$RG" --query "[].name" -o tsv 2>/dev/null | sed 's/^/     /'
else echo "     (does not exist)"; fi

echo "3. any stray app registrations"
az ad app list --display-name "frank-class" --query "[].{id:appId,n:displayName}" -o tsv 2>/dev/null | sed 's/^/     /' || true

if [ "$MODE" != "--confirm" ]; then
  echo; echo "DRY RUN. Re-run with --confirm."; exit 0
fi

echo
[ -f .class-credential ] && ./publish-credential.sh revoke || true
az group delete --name "$RG" --yes --no-wait 2>/dev/null && echo "resource group deletion requested"
echo
echo "Deleting the app registration stops NEW tokens; already-issued Azure tokens"
echo "stay valid briefly. Deleting the resource group is the decisive step — it is"
echo "the only thing the credential could ever reach."
