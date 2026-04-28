#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

set_subscription

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
