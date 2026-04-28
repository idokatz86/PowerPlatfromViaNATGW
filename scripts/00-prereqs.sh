#!/usr/bin/env bash
set -euo pipefail

SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-152f2bd5-8f6b-48ba-a702-21a23172a224}"

az account set --subscription "$SUBSCRIPTION_ID"

echo "Azure account:"
az account show --query '{subscription:id,name:name,tenantId:tenantId,user:user.name}' -o table

echo "Registering required resource providers..."
az provider register --namespace Microsoft.Network --wait
az provider register --namespace Microsoft.PowerPlatform --wait

echo "Registering Power Platform enterprise policies feature if needed..."
az feature register --namespace Microsoft.PowerPlatform --name enterprisePoliciesPreview >/dev/null || true
az feature show --namespace Microsoft.PowerPlatform --name enterprisePoliciesPreview --query '{name:name,state:properties.state}' -o table || true

echo "Provider states:"
az provider show --namespace Microsoft.Network --query '{namespace:namespace,state:registrationState}' -o table
az provider show --namespace Microsoft.PowerPlatform --query '{namespace:namespace,state:registrationState}' -o table

echo "Local tools:"
printf 'az: '; command -v az
printf 'gh: '; command -v gh || true
printf 'pwsh: '; command -v pwsh || true
printf 'pac: '; command -v pac || true
