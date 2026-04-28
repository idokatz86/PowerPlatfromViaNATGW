#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

require_env SUBSCRIPTION_ID TENANT_ID POWER_PLATFORM_ENVIRONMENT_ID RESOURCE_GROUP LOCATION POLICY_NAME POLICY_LOCATION INSPECTION_RESOURCE_GROUP INSPECTION_LOCATION INSPECTION_PLAN_NAME INSPECTION_WEBAPP_NAME

echo "Step 1/6: deploying paired VNets, delegated subnets, NAT Gateways, and public IPs"
./scripts/01-deploy-network.sh

echo "Step 2/6: creating Power Platform enterprise policy"
pwsh -NoProfile -File ./scripts/02-create-enterprise-policy.ps1 \
  -SubscriptionId "$SUBSCRIPTION_ID" \
  -TenantId "$TENANT_ID" \
  -ResourceGroupName "$RESOURCE_GROUP" \
  -PolicyName "$POLICY_NAME" \
  -PolicyLocation "$POLICY_LOCATION" \
  -NetworkOutputsPath '.azure/network-outputs.json'

echo "Step 3/6: enabling subnet injection for the Power Platform environment"
pwsh -NoProfile -File ./scripts/04-enable-subnet-injection.ps1 \
  -EnvironmentId "$POWER_PLATFORM_ENVIRONMENT_ID"

echo "Step 4/6: deploying inspection endpoint"
./scripts/07-deploy-inspection-endpoint.sh

echo "Step 5/6: creating or updating NAT proof custom connector"
./scripts/08-create-proof-connector.sh

echo "Step 6/6: validating Azure networking"
./scripts/05-verify-azure-network.sh

cat <<'NEXT'

Automation completed.

Final proof action:
1. Open Power Automate > Custom connectors > NAT Proof Inspector > Edit > Test.
2. Create/select a connection.
3. Run InspectSourceIp with a unique run ID.
4. Confirm observedClientIp equals one of the NAT Gateway public IPs.

NEXT