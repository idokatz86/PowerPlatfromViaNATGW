#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

require_env SUBSCRIPTION_ID RESOURCE_GROUP
PUBLIC_IP_NAME_FILTER="${PUBLIC_IP_NAME_FILTER:-}"

set_subscription
ensure_output_dir

printf '\nDelegated subnets and NAT Gateway associations:\n'
az network vnet list -g "$RESOURCE_GROUP" --query "[].{name:name,location:location,subnets:subnets[].{name:name,prefix:addressPrefix,natGateway:natGateway.id,delegation:delegations[0].serviceName,nsg:networkSecurityGroup.id}}" -o json | tee .azure/network-validation.json

printf '\nNAT Gateway public IPs:\n'
if [[ -n "$PUBLIC_IP_NAME_FILTER" ]]; then
	az network public-ip list -g "$RESOURCE_GROUP" --query "[?contains(name, '$PUBLIC_IP_NAME_FILTER')].{name:name,location:location,ip:ipAddress,sku:sku.name}" -o table | tee .azure/nat-public-ips.txt
else
	az network public-ip list -g "$RESOURCE_GROUP" --query "[].{name:name,location:location,ip:ipAddress,sku:sku.name}" -o table | tee .azure/nat-public-ips.txt
fi
