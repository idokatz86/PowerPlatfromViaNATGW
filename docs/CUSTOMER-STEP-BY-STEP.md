# Customer Step-By-Step Guide

This guide shows how to reproduce the Power Platform outbound NAT proof in a customer tenant.

## Goal

Power Platform traffic from a VNet-supported workload should reach an external service using the public IP of the Azure NAT Gateway attached to the delegated subnet.

The proof is valid only when the destination service observes the NAT Gateway public IP in the inbound request.

Before starting, read [LIMITATIONS.md](LIMITATIONS.md), [SCENARIOS.md](SCENARIOS.md), and [REGIONAL-PROXY-ENFORCEMENT.md](REGIONAL-PROXY-ENFORCEMENT.md). The most important limitation is that this design does not transparently force every outbound action through NAT Gateway. For deterministic AWS-bound traffic, use the customer-controlled regional proxy pattern and block direct bypass paths with governance and AWS allowlists.

## Required Access

| Area | Required access |
| --- | --- |
| Azure subscription | Contributor or equivalent rights to create resource groups, VNets, subnets, NAT Gateways, public IPs, App Service, and provider registrations |
| Power Platform tenant | Power Platform administrator, Dynamics 365 administrator, or Global administrator for enterprise policy/environment binding |
| Power Platform environment | Existing eligible environment in the same geography and tenant, or rights to create one |
| Local tools | Azure CLI, PowerShell 7, Power Platform CLI (`pac`), zip, jq |

## 1. Authenticate

```bash
az login --tenant <tenant-id> --use-device-code --allow-no-subscriptions
az account set --subscription <subscription-id>
pac auth create --name <profile-name> --tenant <tenant-id> --deviceCode
```

Confirm the context:

```bash
az account show --query '{user:user.name, subscription:id, tenantId:tenantId}' -o json
pac auth list
```

## 2. Configure The Deployment

Export the required values before running the scripts:

```bash
export SUBSCRIPTION_ID='<subscription-id>'
export TENANT_ID='<tenant-id>'
export RESOURCE_GROUP='rg-ppnatgw-demo'
export POWER_PLATFORM_ENVIRONMENT_ID='<environment-id>'
export POLICY_NAME='ppnatgw-europe-policy'
export POLICY_LOCATION='europe'
```

For Europe, the paired Azure regions are `westeurope` and `northeurope`. If the customer uses a different Power Platform geography, update the Bicep parameters and enterprise policy location to the geography's supported Azure region pair.

## 3. Deploy Azure Networking

```bash
./scripts/01-deploy-network.sh
```

The script deploys:

- Two VNets in the required paired regions.
- One delegated subnet per VNet.
- NAT Gateway on each delegated subnet.
- Static Standard public IP for each NAT Gateway.
- VNet peering between the regional VNets.

## 4. Create The Power Platform Enterprise Policy

```bash
pwsh -NoProfile -File ./scripts/02-create-enterprise-policy.ps1 \
  -SubscriptionId "$SUBSCRIPTION_ID" \
  -TenantId "$TENANT_ID" \
  -ResourceGroupName "$RESOURCE_GROUP" \
  -PolicyName "$POLICY_NAME" \
  -PolicyLocation "$POLICY_LOCATION" \
  -NetworkOutputsPath '.azure/network-outputs.json'
```

This writes `.azure/enterprise-policy.json` with the policy ARM ID and subnet references.

## 5. Enable Subnet Injection On The Environment

```bash
pwsh -NoProfile -File ./scripts/04-enable-subnet-injection.ps1 \
  -EnvironmentId "$POWER_PLATFORM_ENVIRONMENT_ID"
```

This writes `.azure/subnet-injection-enabled.json`.

## 6. Deploy The Inspection Endpoint

```bash
./scripts/07-deploy-inspection-endpoint.sh
```

The endpoint returns and logs the destination-observed source IP.

Default URL for this demo:

```text
https://ppnatgw-inspect-frc-06311682.azurewebsites.net/inspect
```

## 7. Create Or Update The Custom Connector

```bash
./scripts/08-create-proof-connector.sh
```

The connector calls the inspection endpoint with no authentication. For production, replace this proof connector with the real customer connector and its required authentication.

## 8. Run The Proof Test

Open Power Automate:

```text
Custom connectors > NAT Proof Inspector > Edit > Test
```

Create a connection, enter a unique `run` value, and select **Test operation**.

The result is valid when the response contains:

```json
{
  "observedClientIp": "<nat-gateway-public-ip>",
  "appServiceClientIp": "<nat-gateway-public-ip>:<port>",
  "headers": {
    "x-ms-subnet-delegation-enabled": "true"
  }
}
```

## 9. Validate Logs

```bash
./scripts/06-tail-inspection-logs.sh
```

or download logs and search for the run ID:

```bash
az webapp log download \
  --name "$INSPECTION_WEBAPP_NAME" \
  --resource-group "$INSPECTION_RESOURCE_GROUP" \
  --log-file /tmp/ppnatgw-inspection.zip
```

## 10. Deploy The Regional Proxy Pattern

Use this when the customer needs AWS to see a deterministic source IP for Power Platform or Logic Apps traffic.

North Europe:

```bash
./scripts/10-deploy-container-apps-proxy.sh
```

West Europe:

```bash
PROXY_LOCATION=westeurope \
PROXY_VNET_NAME=ppnatgw-vnet-weu \
PROXY_SUBNET_PREFIX=10.42.10.0/23 \
PROXY_NAT_NAME=ppnatgw-nat-weu \
PROXY_PUBLIC_IP_NAME=ppnatgw-pip-weu \
PROXY_LOG_ANALYTICS_NAME=ppnatgw-proxy-law-weu \
PROXY_CONTAINER_ENV_NAME=ppnatgw-proxy-env-weu \
PROXY_CONTAINER_APP_NAME=ppnatgw-proxy-weu \
PROXY_ACR_NAME=ppnatgwproxyweu06311682 \
PROXY_OUTPUT_PATH=.azure/container-apps-proxy-weu.json \
./scripts/10-deploy-container-apps-proxy.sh
```

The proof is valid when both `api.ipify.org` and `checkip.amazonaws.com` return the regional NAT Gateway IP. This demo proved:

| Region | Expected and observed IP |
| --- | --- |
| North Europe | `20.166.89.8` |
| West Europe | `51.124.38.135` |

See [CONTAINER-APPS-PROXY-PROOF.md](CONTAINER-APPS-PROXY-PROOF.md).

## 11. Create Power Automate And Logic App Examples

Create the regional Power Platform custom connectors from:

- [../connectors/containerapps-proxy-neu.swagger.json](../connectors/containerapps-proxy-neu.swagger.json)
- [../connectors/containerapps-proxy-weu.swagger.json](../connectors/containerapps-proxy-weu.swagger.json)

Then build a flow that calls only `NEU NAT Proxy` or `WEU NAT Proxy`. See [POWER-AUTOMATE-PROXY-EXAMPLE.md](POWER-AUTOMATE-PROXY-EXAMPLE.md).

Deploy the Logic App example:

```bash
./scripts/11-deploy-logicapp-proxy-example.sh
```

See [LOGIC-APP-PROXY-EXAMPLE.md](LOGIC-APP-PROXY-EXAMPLE.md).

## 12. Enforce The Customer Boundary

Use all of these controls together:

| Control | Required customer action |
| --- | --- |
| Power Platform DLP | Allow only approved proxy custom connectors for this scenario; block or isolate built-in HTTP/direct connectors. |
| Environment governance | Restrict who can create custom connectors and flows in the production environment. |
| Proxy security | Add APIM, OAuth, mTLS, API key, or equivalent production authentication. |
| AWS allowlist | Allow only `20.166.89.8` and `51.124.38.135` for this integration path. |
| Bypass test | Confirm a direct call that does not use the proxy is blocked by DLP or rejected by AWS. |

## Current Demo Result

The current demo proved the North Europe NAT Gateway path:

```text
observedClientIp = 20.166.89.8
x-ms-subnet-delegation-enabled = true
```

See [NAT-PROOF-RESULTS.md](NAT-PROOF-RESULTS.md).

The regional proxy pattern proved both Europe NAT Gateway IPs:

```text
North Europe proxy -> 20.166.89.8
West Europe proxy  -> 51.124.38.135
```

## Important Limitations

- Full limitation details are documented in [LIMITATIONS.md](LIMITATIONS.md).
- Working versus not working examples are documented in [SCENARIOS.md](SCENARIOS.md).
- A single custom connector call proves only the Power Platform regional runtime path that handled that call.
- The Power Platform inspection endpoint proof currently proves North Europe. The customer-controlled proxy proof validates both North Europe and West Europe.
- Built-in Power Automate HTTP actions are not a clean proof path because they can egress from shared Power Automate/Logic Apps infrastructure.
- The proxy pattern is an explicit API hop, not transparent interception. Direct bypass paths must be blocked by DLP/governance and by AWS deny-by-default allowlisting.
- The proof endpoint uses `client-ip` as the primary observed source because Azure App Service sets that header to the client IP observed by the destination front end.