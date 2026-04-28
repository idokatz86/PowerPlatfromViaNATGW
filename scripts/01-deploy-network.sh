#!/usr/bin/env bash
set -euo pipefail

SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-152f2bd5-8f6b-48ba-a702-21a23172a224}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-ppnatgw-demo}"
LOCATION="${LOCATION:-westeurope}"
DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-ppnatgw-network-$(date +%Y%m%d%H%M%S)}"

az account set --subscription "$SUBSCRIPTION_ID"
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --tags purpose=PowerPlatformViaNATGW owner=idokatz@microsoft.com >/dev/null

echo "Running deployment what-if..."
az deployment group what-if \
  --resource-group "$RESOURCE_GROUP" \
  --template-file infra/main.bicep \
  --parameters @infra/main.parameters.json

echo "Deploying network resources..."
az deployment group create \
  --name "$DEPLOYMENT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --template-file infra/main.bicep \
  --parameters @infra/main.parameters.json \
  --query 'properties.outputs' \
  -o json | tee .azure/network-outputs.json

echo "NAT public IPs:"
az deployment group show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$DEPLOYMENT_NAME" \
  --query '{primary:properties.outputs.primaryNatPublicIp.value, secondary:properties.outputs.secondaryNatPublicIp.value}' \
  -o table
