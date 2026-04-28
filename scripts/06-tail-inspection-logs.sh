#!/usr/bin/env bash
set -euo pipefail

RESOURCE_GROUP="${RESOURCE_GROUP:-rg-ppnatgw-inspection}"
WEBAPP_NAME="${WEBAPP_NAME:-ppnatgw-inspect-frc-06311682}"

az webapp log tail \
  --resource-group "$RESOURCE_GROUP" \
  --name "$WEBAPP_NAME"
