#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

require_env SUBSCRIPTION_ID RESOURCE_GROUP LOCATION
PARAMETERS_FILE="${PARAMETERS_FILE:-infra/main.parameters.json}"
DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-powerplatform-network-$(date +%Y%m%d%H%M%S)}"

set_subscription
ensure_output_dir

az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --tags purpose=PowerPlatformViaNATGW >/dev/null

echo "Running deployment what-if..."
az deployment group what-if \
  --resource-group "$RESOURCE_GROUP" \
  --template-file infra/main.bicep \
  --parameters @"$PARAMETERS_FILE"

echo "Deploying network resources..."
az deployment group create \
  --name "$DEPLOYMENT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --template-file infra/main.bicep \
  --parameters @"$PARAMETERS_FILE" \
  --query 'properties.outputs' \
  -o json | tee .azure/network-outputs.json

echo "NAT public IPs:"
az deployment group show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$DEPLOYMENT_NAME" \
  --query '{primary:properties.outputs.primaryNatPublicIp.value, secondary:properties.outputs.secondaryNatPublicIp.value}' \
  -o table
