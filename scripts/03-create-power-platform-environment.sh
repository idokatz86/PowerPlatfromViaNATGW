#!/usr/bin/env bash
set -euo pipefail

ENV_NAME="${ENV_NAME:-PowerPlatformViaNATGW}"
ENV_DOMAIN="${ENV_DOMAIN:-ppnatgw$RANDOM}"
ENV_TYPE="${ENV_TYPE:-Sandbox}"
ENV_REGION="${ENV_REGION:-europe}"
ENV_CURRENCY="${ENV_CURRENCY:-EUR}"

if ! command -v pac >/dev/null 2>&1; then
  echo "PAC CLI is required. Install it first, then rerun this script." >&2
  echo "Docs: https://learn.microsoft.com/power-platform/developer/cli/introduction" >&2
  exit 1
fi

pac auth create --name PowerPlatformViaNATGW

pac admin create \
  --name "$ENV_NAME" \
  --type "$ENV_TYPE" \
  --region "$ENV_REGION" \
  --currency "$ENV_CURRENCY" \
  --domain "$ENV_DOMAIN" \
  --async false | tee .azure/pac-admin-create.log

pac admin list --filter "$ENV_NAME" | tee .azure/pac-admin-list.log

echo "Find the Environment ID in the output above and save it:"
echo "printf '{\"environmentId\":\"<GUID>\"}\n' > .azure/environment.json"
