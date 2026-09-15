#!/usr/bin/env bash
# The shared infrastructure the class deploys INTO: one resource group, one
# registry, one Container Apps environment (ADR-010). Run once per cohort.
#
#   ./scripts/provision-class.sh
#
# deploy.yml discovers the registry and the environment from the group by
# listing them, so their names do not matter — only that exactly one of each
# exists. Idempotent.
set -euo pipefail

: "${CLASS_RG:=rg-frank-class}"
: "${LOCATION:=eastus}"
: "${PREFIX:=frankclass}"
SUFFIX="$(echo "${CLASS_RG}${LOCATION}" | shasum | head -c 6)"
: "${ACR:=${PREFIX}acr${SUFFIX}}"
: "${ENV_NAME:=frank-class-env}"
: "${ENV_FALLBACKS:=eastus2 westus2 centralus westus3}"

echo "group    : $CLASS_RG ($LOCATION)"
echo "registry : $ACR"
echo "environment: $ENV_NAME"
echo

az group create -n "$CLASS_RG" -l "$LOCATION" -o none
echo "==> resource group ready"

# admin-enabled because deploy.yml reads the push password with
# `az acr credential show` when it creates a container app.
az acr create -n "$ACR" -g "$CLASS_RG" -l "$LOCATION" \
  --sku Basic --admin-enabled true -o none
echo "==> registry ready"

# ~90 seconds, and the reason it is created once for the class rather than
# thirty times (ADR-010).
#
# Regions run out of Container Apps capacity without warning — eastus had none
# on 2026-09-15 and failed with ManagedEnvironmentNoAvailableCapacityInRegion.
# Try the preferred region, then fall back. The environment does not have to
# share a region with the group or the registry.
if ! az containerapp env show -n "$ENV_NAME" -g "$CLASS_RG" -o none 2>/dev/null; then
  echo "==> creating the Container Apps environment (about 90 seconds)"
  for R in "$LOCATION" $ENV_FALLBACKS; do
    echo "    trying $R"
    az containerapp env create -n "$ENV_NAME" -g "$CLASS_RG" -l "$R" -o none 2>/dev/null || true
    if az containerapp env show -n "$ENV_NAME" -g "$CLASS_RG" -o none 2>/dev/null; then
      echo "    created in $R"
      break
    fi
    echo "    no capacity in $R"
  done
  az containerapp env show -n "$ENV_NAME" -g "$CLASS_RG" -o none 2>/dev/null || {
    echo "No Container Apps capacity in any of: $LOCATION $ENV_FALLBACKS" >&2
    echo "Set ENV_FALLBACKS to other regions and re-run." >&2
    exit 1; }
fi
echo "==> environment ready"

echo
echo "Class infrastructure is up. Next: ./provision-service.sh"
