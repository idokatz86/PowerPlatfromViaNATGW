# Customer Step-By-Step Guide

This guide walks a customer through deploying and validating a proxy-enforced outbound architecture for Power Platform and Logic Apps.

The goal is not to prove that every Power Platform or Logic Apps outbound path automatically uses NAT Gateway. The goal is to create an approved path where the external destination sees only customer-controlled Azure egress IPs.

## 1. Choose The Architecture

Recommended path:

```text
Power Automate / Power Apps / Logic Apps
  -> approved proxy connector or approved proxy URL
  -> Azure proxy workload in a VNet subnet
  -> NAT Gateway or Azure Firewall
  -> external destination
```

Do not use this as the enforcement path:

```text
Power Automate built-in HTTP
  -> external destination directly
```

That direct path can work, but it is not NAT-proof because the action can run from Microsoft-managed connector infrastructure.

## 2. Confirm Prerequisites

Confirm these items before running the scripts:

| Area | Required decision |
| --- | --- |
| Azure subscription | Subscription where networking and proxy resources will be deployed. |
| Microsoft Entra tenant | Tenant associated with the target Power Platform environment. |
| Power Platform environment | Managed environment that will use the approved connector or flow pattern. |
| Geography and regions | Required Azure regions for the customer's Power Platform geography. |
| Address spaces | Non-overlapping VNet and subnet prefixes. |
| Egress control | NAT Gateway for fixed IP only, or Azure Firewall for policy and inspection. |
| Destination allowlist | AWS or external service must allow only the approved public egress IPs. |

Required local tools:

- Azure CLI
- PowerShell 7
- Power Platform CLI (`pac`)
- `jq`
- `zip`

## 3. Set Customer Values

Copy [.env.example](../.env.example), replace every placeholder, and export the values in your shell.

Do not commit populated environment files.

Minimum values:

```bash
export SUBSCRIPTION_ID='<azure-subscription-id>'
export TENANT_ID='<microsoft-entra-tenant-id>'
export POWER_PLATFORM_ENVIRONMENT_ID='<power-platform-environment-id>'
export RESOURCE_GROUP='<resource-group-name>'
export LOCATION='<primary-azure-region>'
export POLICY_NAME='<enterprise-policy-name>'
export POLICY_LOCATION='<power-platform-policy-location>'
export PARAMETERS_FILE='infra/main.parameters.json'
```

## 4. Review Network Parameters

Edit [../infra/main.parameters.json](../infra/main.parameters.json).

Set customer-specific values for:

- Resource name prefix
- Primary and secondary regions
- VNet address spaces
- Power Platform delegated subnet prefixes
- Delegated subnet name

The Power Platform delegated subnets and Container Apps proxy subnets must be separate. Container Apps environments require their own delegated subnet.

## 5. Register Providers And Deploy Network

```bash
./scripts/00-prereqs.sh
./scripts/01-deploy-network.sh
```

The network script creates paired VNets, delegated subnets, NAT Gateways, static public IPs, NSGs, and VNet peering based on the Bicep parameter file.

## 6. Create Enterprise Policy And Enable Power Platform VNet Support

Create the enterprise policy:

```powershell
pwsh -NoProfile -File ./scripts/02-create-enterprise-policy.ps1 \
  -SubscriptionId "$SUBSCRIPTION_ID" \
  -TenantId "$TENANT_ID" \
  -ResourceGroupName "$RESOURCE_GROUP" \
  -PolicyName "$POLICY_NAME" \
  -PolicyLocation "$POLICY_LOCATION" \
  -NetworkOutputsPath '.azure/network-outputs.json'
```

Enable subnet injection for the target environment:

```powershell
pwsh -NoProfile -File ./scripts/04-enable-subnet-injection.ps1 \
  -EnvironmentId "$POWER_PLATFORM_ENVIRONMENT_ID"
```

Validate the Azure network state:

```bash
./scripts/05-verify-azure-network.sh
```

## 7. Deploy The Regional Container Apps Proxy

Run this once per region with region-specific values:

```bash
export PROXY_RESOURCE_GROUP="$RESOURCE_GROUP"
export PROXY_LOCATION='<azure-region>'
export PROXY_VNET_NAME='<vnet-name>'
export PROXY_SUBNET_NAME='<container-apps-environment-subnet-name>'
export PROXY_SUBNET_PREFIX='<container-apps-environment-subnet-prefix>'
export PROXY_NAT_NAME='<nat-gateway-name>'
export PROXY_PUBLIC_IP_NAME='<nat-public-ip-resource-name>'
export PROXY_LOG_ANALYTICS_NAME='<log-analytics-workspace-name>'
export PROXY_CONTAINER_ENV_NAME='<container-apps-environment-name>'
export PROXY_CONTAINER_APP_NAME='<container-app-name>'
export PROXY_ACR_NAME='<globally-unique-acr-name>'
export PROXY_OUTPUT_PATH='.azure/container-apps-proxy-<region>.json'

./scripts/10-deploy-container-apps-proxy.sh
```

The script builds the proxy image with ACR build, deploys or updates the Container App, and tests:

- `/health`
- `/proxy/ipify`
- `/proxy/aws-checkip`

The test passes only when the returned observed IP equals the NAT Gateway public IP associated with the proxy subnet.

## 8. Configure Power Automate

Preferred option: create customer-approved custom connectors that point to the proxy endpoints.

Create or update the proxy custom connectors from the deployed proxy hosts:

```bash
export NORTH_REGION_PROXY_HOST='<first-regional-proxy-host-or-url>'
export WEST_REGION_PROXY_HOST='<second-regional-proxy-host-or-url>'
export NORTH_REGION_CONNECTOR_DISPLAY_NAME='North Region NAT Proxy'
export WEST_REGION_CONNECTOR_DISPLAY_NAME='West Region NAT Proxy'

./scripts/12-create-proxy-connectors.sh
```

Flow shape:

```text
Manual trigger or app trigger
  -> approved regional proxy custom connector
  -> validate returned observed IP
  -> continue business process
```

Acceptable alternative: use built-in HTTP only when the URI is restricted to the approved proxy hostnames.

```text
Built-in HTTP action
  -> approved proxy URL only
  -> validate returned observed IP
```

Do not let makers call AWS directly from built-in HTTP when the requirement is deterministic NAT egress.

Recommended controls:

- Put approved proxy connectors in the correct DLP connector group.
- Block, isolate, or tightly review direct HTTP usage.
- Restrict connector creation to admins.
- Use solution-aware connection references for production deployment.
- Review flow definitions for direct external URLs before release.

## 9. Configure Logic Apps

For the included Logic Apps Consumption example, provide the proxy URLs and workflow names:

```bash
export LOGIC_APP_RESOURCE_GROUP="$RESOURCE_GROUP"
export NORTH_EUROPE_PROXY_URL='<first-regional-proxy-url>'
export WEST_EUROPE_PROXY_URL='<second-regional-proxy-url>'
export NORTH_EUROPE_WORKFLOW_NAME='<workflow-name-1>'
export WEST_EUROPE_WORKFLOW_NAME='<workflow-name-2>'

./scripts/11-deploy-logicapp-proxy-example.sh
```

The example deploys workflows whose outbound HTTP actions call only the proxy endpoints.

For production, choose one of these patterns:

| Logic Apps pattern | Guidance |
| --- | --- |
| Consumption calling proxy | Simple and acceptable when all external calls are restricted to approved proxy URLs. |
| Standard with VNet integration | Better when the workflow runtime itself needs Azure networking integration. |
| APIM fronting the proxy | Better when central API policy, auth, throttling, and logging are required. |

## 10. Configure The Destination

The destination must enforce the source IP boundary.

For AWS, this may be done with one or more of:

- AWS WAF IP sets
- API Gateway resource policies
- ALB listener or security controls
- Security groups, when applicable
- Application-level source-IP validation
- Firewall or proxy policy

Allow only the customer-approved NAT Gateway or Azure Firewall public IPs. Reject every other source IP.

## 11. Capture Proof

For every approved path, capture:

| Evidence | Required result |
| --- | --- |
| Proxy `/proxy/aws-checkip` response | Observed IP equals approved public egress IP. |
| Power Automate run history | Flow calls only approved connector or proxy URL. |
| Logic App run history | Workflow calls only approved proxy URL. |
| Destination logs | External service sees only approved source IP. |
| Bypass test | Direct call is blocked by governance or rejected by destination. |

## 12. Day 2 Operations

| Area | Operational task |
| --- | --- |
| Monitoring | Alert on proxy failures, high latency, and unhealthy Container Apps revisions. |
| Logging | Retain enough Log Analytics data for incident review and customer audit needs. |
| Security | Rotate credentials and review connector, flow, and workflow ownership. |
| Governance | Periodically search for direct HTTP calls and unapproved connectors. |
| Cost | Review NAT Gateway data volume, Container Apps replicas, and Log Analytics ingestion. |
| Release management | Use immutable image tags and Container Apps revisions for rollback. |
| AWS allowlist | Keep destination allowlists synchronized with approved Azure public IPs. |
| DR planning | Decide whether regional proxies are active/active, active/passive, or proof-only. |

## 13. Cost Checklist

Estimate the following before production:

- NAT Gateway hourly and data processing charges
- Static public IP charges
- Container Apps CPU, memory, request, and replica usage
- Log Analytics ingestion and retention
- Container Registry storage and SKU
- Logic Apps action executions
- Optional APIM or Azure Firewall cost
- Operational cost for monitoring, support, and change control

## 14. Production Hardening

Before production, add:

- Authentication and authorization on the proxy
- TLS and certificate management plan
- Managed identity where possible
- APIM, Azure Front Door, or another policy layer if required
- Private build and release process
- Environment-specific configuration
- Runbooks for incident response and rollback
- Clear owner for Power Platform DLP and AWS allowlists

## 15. Cleanup After Proof

If this is only a proof, remove or disable:

- Temporary flows
- Temporary Logic Apps
- Temporary proxy apps
- Temporary public IPs and NAT Gateways
- Temporary inspection endpoints
- Generated `.azure` files that contain customer environment details