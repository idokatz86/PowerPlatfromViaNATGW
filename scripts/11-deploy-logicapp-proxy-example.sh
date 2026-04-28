#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

require_env SUBSCRIPTION_ID LOGIC_APP_RESOURCE_GROUP NORTH_EUROPE_PROXY_URL WEST_EUROPE_PROXY_URL NORTH_EUROPE_WORKFLOW_NAME WEST_EUROPE_WORKFLOW_NAME

RESOURCE_GROUP="$LOGIC_APP_RESOURCE_GROUP"

set_subscription
ensure_output_dir

az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file infra/logicapp-proxy-example.bicep \
  --parameters \
    northEuropeProxyUrl="$NORTH_EUROPE_PROXY_URL" \
    westEuropeProxyUrl="$WEST_EUROPE_PROXY_URL" \
    northEuropeWorkflowName="$NORTH_EUROPE_WORKFLOW_NAME" \
    westEuropeWorkflowName="$WEST_EUROPE_WORKFLOW_NAME" \
  --query properties.outputs \
  -o json

mkdir -p .azure

north_url="$(az rest \
  --method post \
  --url "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Logic/workflows/$NORTH_EUROPE_WORKFLOW_NAME/triggers/manual/listCallbackUrl?api-version=2016-06-01" \
  --query value \
  -o tsv)"

west_url="$(az rest \
  --method post \
  --url "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Logic/workflows/$WEST_EUROPE_WORKFLOW_NAME/triggers/manual/listCallbackUrl?api-version=2016-06-01" \
  --query value \
  -o tsv)"

echo "Testing North Europe Logic App proxy example..."
curl -sS -X POST "$north_url" \
  -H 'content-type: application/json' \
  -d '{"runId":"logicapp-neu-proxy-proof"}'
echo

echo "Testing West Europe Logic App proxy example..."
curl -sS -X POST "$west_url" \
  -H 'content-type: application/json' \
  -d '{"runId":"logicapp-weu-proxy-proof"}'
echo

cat > .azure/logicapp-proxy-example.json <<EOF
{
  "resourceGroup": "$RESOURCE_GROUP",
  "northEuropeWorkflowName": "$NORTH_EUROPE_WORKFLOW_NAME",
  "westEuropeWorkflowName": "$WEST_EUROPE_WORKFLOW_NAME",
  "northEuropeProxyUrl": "$NORTH_EUROPE_PROXY_URL",
  "westEuropeProxyUrl": "$WEST_EUROPE_PROXY_URL"
}
EOF