#!/usr/bin/env bash

require_env() {
  local missing=()
  for var_name in "$@"; do
    if [[ -z "${!var_name:-}" ]]; then
      missing+=("$var_name")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    echo "Missing required environment variable(s): ${missing[*]}" >&2
    echo "Copy .env.example, fill in your customer values, then export them before running this script." >&2
    exit 1
  fi
}

ensure_output_dir() {
  mkdir -p .azure
}

set_subscription() {
  require_env SUBSCRIPTION_ID
  az account set --subscription "$SUBSCRIPTION_ID"
}