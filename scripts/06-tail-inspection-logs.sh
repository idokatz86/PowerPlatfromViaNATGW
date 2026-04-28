#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

require_env INSPECTION_RESOURCE_GROUP INSPECTION_WEBAPP_NAME

az webapp log tail \
  --resource-group "$INSPECTION_RESOURCE_GROUP" \
  --name "$INSPECTION_WEBAPP_NAME"
