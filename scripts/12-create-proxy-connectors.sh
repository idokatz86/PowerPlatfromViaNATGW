#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

require_env POWER_PLATFORM_ENVIRONMENT_ID NORTH_REGION_PROXY_HOST WEST_REGION_PROXY_HOST

PAC_CLI="${PAC_CLI:-$HOME/.dotnet/tools/pac}"
NORTH_REGION_CONNECTOR_DISPLAY_NAME="${NORTH_REGION_CONNECTOR_DISPLAY_NAME:-North Region NAT Proxy}"
WEST_REGION_CONNECTOR_DISPLAY_NAME="${WEST_REGION_CONNECTOR_DISPLAY_NAME:-West Region NAT Proxy}"
GENERATED_CONNECTOR_DIR="${GENERATED_CONNECTOR_DIR:-.azure/generated-connectors}"

normalize_host() {
  local value="$1"
  value="${value#https://}"
  value="${value#http://}"
  value="${value%%/*}"
  printf '%s' "$value"
}

generate_connector_definition() {
  local template_path="$1"
  local output_path="$2"
  local host="$3"
  local title="$4"

  node -e '
const fs = require("fs");
const [templatePath, outputPath, host, title] = process.argv.slice(1);
const swagger = JSON.parse(fs.readFileSync(templatePath, "utf8"));
swagger.host = host;
swagger.info.title = title;
fs.writeFileSync(outputPath, JSON.stringify(swagger, null, 2) + "\n");
' "$template_path" "$output_path" "$host" "$title"
}

upsert_connector() {
  local display_name="$1"
  local definition_path="$2"
  local api_properties_path="$3"
  local connector_id

  connector_id="$($PAC_CLI connector list --environment "$POWER_PLATFORM_ENVIRONMENT_ID" | awk -v name="$display_name" 'index($0, name) { print $1; exit }')"

  if [[ -n "$connector_id" ]]; then
    echo "Updating connector '$display_name' ($connector_id)"
    "$PAC_CLI" connector update \
      --environment "$POWER_PLATFORM_ENVIRONMENT_ID" \
      --connector-id "$connector_id" \
      --api-definition-file "$definition_path" \
      --api-properties-file "$api_properties_path"
  else
    echo "Creating connector '$display_name'"
    "$PAC_CLI" connector create \
      --environment "$POWER_PLATFORM_ENVIRONMENT_ID" \
      --api-definition-file "$definition_path" \
      --api-properties-file "$api_properties_path"
  fi
}

mkdir -p "$GENERATED_CONNECTOR_DIR"

north_host="$(normalize_host "$NORTH_REGION_PROXY_HOST")"
west_host="$(normalize_host "$WEST_REGION_PROXY_HOST")"
north_definition="$GENERATED_CONNECTOR_DIR/north-region-proxy.swagger.json"
west_definition="$GENERATED_CONNECTOR_DIR/west-region-proxy.swagger.json"

generate_connector_definition \
  connectors/containerapps-proxy-neu.swagger.json \
  "$north_definition" \
  "$north_host" \
  "$NORTH_REGION_CONNECTOR_DISPLAY_NAME"

generate_connector_definition \
  connectors/containerapps-proxy-weu.swagger.json \
  "$west_definition" \
  "$west_host" \
  "$WEST_REGION_CONNECTOR_DISPLAY_NAME"

upsert_connector \
  "$NORTH_REGION_CONNECTOR_DISPLAY_NAME" \
  "$north_definition" \
  connectors/containerapps-proxy.apiProperties.json

upsert_connector \
  "$WEST_REGION_CONNECTOR_DISPLAY_NAME" \
  "$west_definition" \
  connectors/containerapps-proxy.apiProperties.json

"$PAC_CLI" connector list --environment "$POWER_PLATFORM_ENVIRONMENT_ID"