#!/usr/bin/env bash
set -euo pipefail

SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-152f2bd5-8f6b-48ba-a702-21a23172a224}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-ppnatgw-demo}"
SUBNET_NAME="${SUBNET_NAME:-snet-powerplatform-delegated}"

az account set --subscription "$SUBSCRIPTION_ID"

printf '\nDelegated subnets and NAT Gateway associations:\n'
az network vnet list -g "$RESOURCE_GROUP" --query "[].{name:name,location:location,subnets:subnets[].{name:name,prefix:addressPrefix,natGateway:natGateway.id,delegation:delegations[0].serviceName,nsg:networkSecurityGroup.id}}" -o json | tee .azure/network-validation.json

printf '\nNAT Gateway public IPs:\n'
az network public-ip list -g "$RESOURCE_GROUP" --query "[?contains(name, 'ppnatgw-pip')].{name:name,location:location,ip:ipAddress,sku:sku.name}" -o table | tee .azure/nat-public-ips.txt
