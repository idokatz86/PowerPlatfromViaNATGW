#!/usr/bin/env bash
set -euo pipefail

SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-3cce1c0d-4798-48da-92cd-daaf643e932c}"
RESOURCE_GROUP="${PROXY_RESOURCE_GROUP:-rg-ppnatgw-demo}"
LOCATION="${PROXY_LOCATION:-northeurope}"
VNET_NAME="${PROXY_VNET_NAME:-ppnatgw-vnet-neu}"
SUBNET_NAME="${PROXY_SUBNET_NAME:-snet-containerapps-proxy}"
SUBNET_PREFIX="${PROXY_SUBNET_PREFIX:-10.43.10.0/23}"
NAT_NAME="${PROXY_NAT_NAME:-ppnatgw-nat-neu}"
PUBLIC_IP_NAME="${PROXY_PUBLIC_IP_NAME:-ppnatgw-pip-neu}"
LOG_ANALYTICS_NAME="${PROXY_LOG_ANALYTICS_NAME:-ppnatgw-proxy-law}"
CONTAINER_ENV_NAME="${PROXY_CONTAINER_ENV_NAME:-ppnatgw-proxy-env}"
CONTAINER_APP_NAME="${PROXY_CONTAINER_APP_NAME:-ppnatgw-proxy}"
ACR_NAME="${PROXY_ACR_NAME:-ppnatgwproxyneu06311682}"
IMAGE_NAME="${PROXY_IMAGE_NAME:-ppnatgw-proxy}"
IMAGE_TAG="${PROXY_IMAGE_TAG:-$(date +%Y%m%d%H%M%S)}"
EXPECTED_NAT_IPS="${EXPECTED_NAT_IPS:-20.166.89.8,51.124.38.135}"
OUTPUT_PATH="${PROXY_OUTPUT_PATH:-.azure/container-apps-proxy.json}"

az account set --subscription "$SUBSCRIPTION_ID"

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