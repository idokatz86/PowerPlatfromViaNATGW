#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

require_env POWER_PLATFORM_ENVIRONMENT_ID
PAC_CLI="${PAC_CLI:-$HOME/.dotnet/tools/pac}"
CONNECTOR_NAME="${CONNECTOR_NAME:-NAT Proof Inspector}"

connector_id="${CONNECTOR_ID:-}"

if [[ -z "$connector_id" ]]; then
  connector_id="$($PAC_CLI connector list --environment "$POWER_PLATFORM_ENVIRONMENT_ID" | awk -v name="$CONNECTOR_NAME" 'index($0, name) { print $1; exit }')"
fi

if [[ -n "$connector_id" ]]; then
  echo "Updating connector $connector_id in environment $POWER_PLATFORM_ENVIRONMENT_ID"
  "$PAC_CLI" connector update \
    --environment "$POWER_PLATFORM_ENVIRONMENT_ID" \
    --connector-id "$connector_id" \
    --api-definition-file connectors/nat-proof-connector.swagger.json \
    --api-properties-file connectors/nat-proof-connector.apiProperties.json
else
  echo "Creating connector in environment $POWER_PLATFORM_ENVIRONMENT_ID"
  "$PAC_CLI" connector create \
    --environment "$POWER_PLATFORM_ENVIRONMENT_ID" \
    --api-definition-file connectors/nat-proof-connector.swagger.json \
    --api-properties-file connectors/nat-proof-connector.apiProperties.json
fi

"$PAC_CLI" connector list --environment "$POWER_PLATFORM_ENVIRONMENT_ID"