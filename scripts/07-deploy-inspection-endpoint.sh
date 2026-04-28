#!/usr/bin/env bash
set -euo pipefail

SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-3cce1c0d-4798-48da-92cd-daaf643e932c}"
INSPECTION_RESOURCE_GROUP="${INSPECTION_RESOURCE_GROUP:-rg-ppnatgw-inspection}"
INSPECTION_LOCATION="${INSPECTION_LOCATION:-francecentral}"
INSPECTION_PLAN_NAME="${INSPECTION_PLAN_NAME:-ppnatgw-inspection-free-francecentral}"
INSPECTION_WEBAPP_NAME="${INSPECTION_WEBAPP_NAME:-ppnatgw-inspect-frc-06311682}"
INSPECTION_SKU="${INSPECTION_SKU:-F1}"

az account set --subscription "$SUBSCRIPTION_ID"
az group create --name "$INSPECTION_RESOURCE_GROUP" --location "$INSPECTION_LOCATION" >/dev/null

if ! az appservice plan show --name "$INSPECTION_PLAN_NAME" --resource-group "$INSPECTION_RESOURCE_GROUP" >/dev/null 2>&1; then
  az appservice plan create \
    --name "$INSPECTION_PLAN_NAME" \
    --resource-group "$INSPECTION_RESOURCE_GROUP" \
    --location "$INSPECTION_LOCATION" \
    --sku "$INSPECTION_SKU" >/dev/null
fi

if ! az webapp show --name "$INSPECTION_WEBAPP_NAME" --resource-group "$INSPECTION_RESOURCE_GROUP" >/dev/null 2>&1; then
  az webapp create \
    --name "$INSPECTION_WEBAPP_NAME" \
    --resource-group "$INSPECTION_RESOURCE_GROUP" \
    --plan "$INSPECTION_PLAN_NAME" \
    --runtime "NODE:20-lts" >/dev/null
fi

az webapp config appsettings set \
  --name "$INSPECTION_WEBAPP_NAME" \
  --resource-group "$INSPECTION_RESOURCE_GROUP" \
  --settings SCM_DO_BUILD_DURING_DEPLOYMENT=true WEBSITE_NODE_DEFAULT_VERSION='~20' >/dev/null

(cd proof-endpoint && zip -r ../.azure/proof-endpoint.zip . >/dev/null)

az webapp deploy \
  --name "$INSPECTION_WEBAPP_NAME" \
  --resource-group "$INSPECTION_RESOURCE_GROUP" \
  --src-path .azure/proof-endpoint.zip \
  --type zip \
  --timeout 600 >/dev/null

az webapp restart --name "$INSPECTION_WEBAPP_NAME" --resource-group "$INSPECTION_RESOURCE_GROUP" >/dev/null

echo "Inspection endpoint: https://${INSPECTION_WEBAPP_NAME}.azurewebsites.net/inspect"
curl -sS "https://${INSPECTION_WEBAPP_NAME}.azurewebsites.net/inspect?run=deployment-smoke" | jq '{timestamp,observedClientIp,rawObservedClientIp,appServiceClientIp,path}'