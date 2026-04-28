#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

require_env SUBSCRIPTION_ID PROXY_RESOURCE_GROUP PROXY_LOCATION PROXY_VNET_NAME PROXY_SUBNET_NAME PROXY_SUBNET_PREFIX PROXY_NAT_NAME PROXY_PUBLIC_IP_NAME PROXY_LOG_ANALYTICS_NAME PROXY_CONTAINER_ENV_NAME PROXY_CONTAINER_APP_NAME PROXY_ACR_NAME

RESOURCE_GROUP="$PROXY_RESOURCE_GROUP"
LOCATION="$PROXY_LOCATION"
VNET_NAME="$PROXY_VNET_NAME"
SUBNET_NAME="$PROXY_SUBNET_NAME"
SUBNET_PREFIX="$PROXY_SUBNET_PREFIX"
NAT_NAME="$PROXY_NAT_NAME"
PUBLIC_IP_NAME="$PROXY_PUBLIC_IP_NAME"
LOG_ANALYTICS_NAME="$PROXY_LOG_ANALYTICS_NAME"
CONTAINER_ENV_NAME="$PROXY_CONTAINER_ENV_NAME"
CONTAINER_APP_NAME="$PROXY_CONTAINER_APP_NAME"
ACR_NAME="$PROXY_ACR_NAME"
IMAGE_NAME="${PROXY_IMAGE_NAME:-powerplatform-egress-proxy}"
IMAGE_TAG="${PROXY_IMAGE_TAG:-$(date +%Y%m%d%H%M%S)}"
OUTPUT_PATH="${PROXY_OUTPUT_PATH:-.azure/container-apps-proxy.json}"

set_subscription
ensure_output_dir

az provider register --namespace Microsoft.App --wait >/dev/null
az provider register --namespace Microsoft.ContainerRegistry --wait >/dev/null
az provider register --namespace Microsoft.OperationalInsights --wait >/dev/null
az provider register --namespace Microsoft.Network --wait >/dev/null

if ! az group show --name "$RESOURCE_GROUP" >/dev/null 2>&1; then
  az group create --name "$RESOURCE_GROUP" --location "$LOCATION" >/dev/null
fi

if ! az network vnet show --resource-group "$RESOURCE_GROUP" --name "$VNET_NAME" >/dev/null 2>&1; then
  echo "Expected existing VNet '$VNET_NAME' in resource group '$RESOURCE_GROUP' was not found." >&2
  exit 1
fi

if ! az network nat gateway show --resource-group "$RESOURCE_GROUP" --name "$NAT_NAME" >/dev/null 2>&1; then
  echo "Expected existing NAT Gateway '$NAT_NAME' in resource group '$RESOURCE_GROUP' was not found." >&2
  exit 1
fi

if ! az network vnet subnet show --resource-group "$RESOURCE_GROUP" --vnet-name "$VNET_NAME" --name "$SUBNET_NAME" >/dev/null 2>&1; then
  az network vnet subnet create \
    --resource-group "$RESOURCE_GROUP" \
    --vnet-name "$VNET_NAME" \
    --name "$SUBNET_NAME" \
    --address-prefixes "$SUBNET_PREFIX" \
    --delegations Microsoft.App/environments \
    --nat-gateway "$NAT_NAME" >/dev/null
else
  az network vnet subnet update \
    --resource-group "$RESOURCE_GROUP" \
    --vnet-name "$VNET_NAME" \
    --name "$SUBNET_NAME" \
    --delegations Microsoft.App/environments \
    --nat-gateway "$NAT_NAME" >/dev/null
fi

az network vnet subnet update \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name "$SUBNET_NAME" \
  --nat-gateway "$NAT_NAME" >/dev/null

subnet_id="$(az network vnet subnet show --resource-group "$RESOURCE_GROUP" --vnet-name "$VNET_NAME" --name "$SUBNET_NAME" --query id -o tsv)"
nat_ip="$(az network public-ip show --resource-group "$RESOURCE_GROUP" --name "$PUBLIC_IP_NAME" --query ipAddress -o tsv)"
EXPECTED_NAT_IPS="${EXPECTED_NAT_IPS:-$nat_ip}"

if ! az monitor log-analytics workspace show --resource-group "$RESOURCE_GROUP" --workspace-name "$LOG_ANALYTICS_NAME" >/dev/null 2>&1; then
  az monitor log-analytics workspace create \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --workspace-name "$LOG_ANALYTICS_NAME" >/dev/null
fi

workspace_id="$(az monitor log-analytics workspace show --resource-group "$RESOURCE_GROUP" --workspace-name "$LOG_ANALYTICS_NAME" --query customerId -o tsv)"
workspace_key="$(az monitor log-analytics workspace get-shared-keys --resource-group "$RESOURCE_GROUP" --workspace-name "$LOG_ANALYTICS_NAME" --query primarySharedKey -o tsv)"

if ! az acr show --resource-group "$RESOURCE_GROUP" --name "$ACR_NAME" >/dev/null 2>&1; then
  az acr create \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --name "$ACR_NAME" \
    --sku Basic \
    --admin-enabled true >/dev/null
fi

az acr build \
  --registry "$ACR_NAME" \
  --image "$IMAGE_NAME:$IMAGE_TAG" \
  proxy-endpoint >/dev/null

if ! az containerapp env show --resource-group "$RESOURCE_GROUP" --name "$CONTAINER_ENV_NAME" >/dev/null 2>&1; then
  az containerapp env create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$CONTAINER_ENV_NAME" \
    --location "$LOCATION" \
    --infrastructure-subnet-resource-id "$subnet_id" \
    --logs-workspace-id "$workspace_id" \
    --logs-workspace-key "$workspace_key" >/dev/null
fi

acr_login_server="$(az acr show --resource-group "$RESOURCE_GROUP" --name "$ACR_NAME" --query loginServer -o tsv)"
acr_username="$(az acr credential show --resource-group "$RESOURCE_GROUP" --name "$ACR_NAME" --query username -o tsv)"
acr_password="$(az acr credential show --resource-group "$RESOURCE_GROUP" --name "$ACR_NAME" --query passwords[0].value -o tsv)"
image="$acr_login_server/$IMAGE_NAME:$IMAGE_TAG"

if az containerapp show --resource-group "$RESOURCE_GROUP" --name "$CONTAINER_APP_NAME" >/dev/null 2>&1; then
  az containerapp update \
    --resource-group "$RESOURCE_GROUP" \
    --name "$CONTAINER_APP_NAME" \
    --image "$image" \
    --set-env-vars EXPECTED_NAT_IPS="$EXPECTED_NAT_IPS" >/dev/null
else
  az containerapp create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$CONTAINER_APP_NAME" \
    --environment "$CONTAINER_ENV_NAME" \
    --image "$image" \
    --target-port 3000 \
    --ingress external \
    --registry-server "$acr_login_server" \
    --registry-username "$acr_username" \
    --registry-password "$acr_password" \
    --env-vars EXPECTED_NAT_IPS="$EXPECTED_NAT_IPS" \
    --min-replicas 1 \
    --max-replicas 1 >/dev/null
fi

fqdn="$(az containerapp show --resource-group "$RESOURCE_GROUP" --name "$CONTAINER_APP_NAME" --query properties.configuration.ingress.fqdn -o tsv)"
base_url="https://${fqdn}"

mkdir -p .azure
mkdir -p "$(dirname "$OUTPUT_PATH")"
cat > "$OUTPUT_PATH" <<EOF
{
  "resourceGroup": "$RESOURCE_GROUP",
  "location": "$LOCATION",
  "containerAppName": "$CONTAINER_APP_NAME",
  "containerAppsEnvironment": "$CONTAINER_ENV_NAME",
  "vnetName": "$VNET_NAME",
  "subnetName": "$SUBNET_NAME",
  "natGatewayName": "$NAT_NAME",
  "natPublicIpName": "$PUBLIC_IP_NAME",
  "natPublicIp": "$nat_ip",
  "url": "$base_url"
}
EOF

echo "Container Apps proxy: $base_url"
echo "Proxy NAT Gateway public IP: $nat_ip"
curl -sS "$base_url/health" | jq .
curl -sS "$base_url/proxy/ipify" | jq .
curl -sS "$base_url/proxy/aws-checkip" | jq .