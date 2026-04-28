# PowerPlatfromViaNATGW

Customer-ready reference implementation for deterministic outbound access from Power Platform or Logic Apps to an external service such as an AWS-hosted MCP endpoint.

The repository shows why a NAT Gateway alone is not enough for every Power Platform path, and how to enforce a customer-controlled egress hop with Azure Container Apps, NAT Gateway, Power Platform DLP, and destination-side allowlisting.

> The repository name intentionally follows the requested spelling: `PowerPlatfromViaNATGW`.

## What This Solves

Some integrations require the destination to see a fixed, customer-owned public IP. A common example is an AWS endpoint that only allows traffic from approved source IP addresses.

Azure NAT Gateway can provide fixed outbound public IPs for workloads that run in an Azure subnet. The important limitation is that not every Power Platform or Logic Apps call runs inside your subnet. A built-in Power Automate HTTP action or managed connector can egress from Microsoft-managed connector infrastructure instead of from your NAT Gateway.

The reliable pattern is to make Power Platform or Logic Apps call an approved proxy endpoint, then let that proxy make the AWS-facing request from a subnet that has NAT Gateway or Azure Firewall attached.

```text
Power Automate / Power Apps / Logic Apps
  -> approved regional proxy endpoint
  -> customer-controlled Azure workload in a VNet
  -> NAT Gateway or Azure Firewall
  -> AWS MCP endpoint or public destination
```

## Why NAT Gateway Alone Is Not Enough

NAT Gateway controls outbound SNAT for resources that actually send traffic from the associated Azure subnet.

Power Platform virtual network support can place supported Power Platform workloads into delegated subnets, but it does not transparently force every connector, built-in HTTP action, or managed service hop through that subnet. Direct public tests can succeed while the destination sees a Microsoft-managed source IP instead of the NAT Gateway IP.

For customer enforcement, three things must be true at the same time:

| Requirement | Why it matters |
| --- | --- |
| The AWS-facing request must originate from a customer-controlled Azure subnet | This is what NAT Gateway or Azure Firewall can govern. |
| Power Platform and Logic Apps must be restricted to approved proxy paths | Otherwise makers can bypass the proxy with direct HTTP or unapproved connectors. |
| The destination must deny every non-approved source IP | AWS allowlisting is the final enforcement point. |

## Reference Architecture

```text
Maker app or workflow
  -> approved custom connector or approved HTTP action URI
  -> regional Container Apps proxy
  -> proxy subnet associated with NAT Gateway
  -> external destination
```

This repo uses Azure Container Apps for the proxy because it is small, repeatable, container-native, and easy to deploy into a workload profile environment connected to a VNet. The proxy performs the outbound request and returns the destination-observed source IP for proof.

## Components And Why They Are Used

| Component | Purpose | Why it is included |
| --- | --- | --- |
| Azure Virtual Network | Hosts delegated subnets and proxy subnets | Gives the customer a network boundary that can be governed. |
| Power Platform delegated subnet | Enables supported Power Platform virtual network paths | Required for Power Platform VNet support scenarios. |
| NAT Gateway | Provides stable public outbound IPs for subnet-based traffic | Simple fixed egress for internet-bound traffic. |
| Static Public IP | The address the destination can allowlist | Gives AWS a stable source IP to trust. |
| Azure Container Apps proxy | Makes the AWS-facing request from inside the VNet | Provides deterministic egress even when Power Automate itself is not subnet-bound. |
| Azure Container Registry | Stores the proxy container image | Keeps the image in the customer's Azure boundary. |
| Log Analytics | Stores Container Apps logs | Supports day 2 diagnostics and operational review. |
| Power Platform custom connector | Gives makers a controlled action instead of arbitrary HTTP | Easier to govern with DLP and environment controls. |
| Logic Apps example | Shows the same proxy-only pattern for Logic Apps | Logic Apps also need explicit routing through the proxy unless using their own VNet-integrated hosting pattern. |

## Why Container Apps Was Chosen

Container Apps is a good default for this proof because the proxy is a small HTTP service that needs external ingress, VNet integration, simple scaling, and low operational overhead.

| Option | Pros | Cons | Good fit when |
| --- | --- | --- | --- |
| Azure Container Apps | Simple container deployment, VNet integration, scale controls, easy revision rollback | Requires Container Apps environment subnet; production ingress/auth must be designed | You need a lightweight API proxy quickly. |
| Azure API Management | Strong policy layer, auth, rate limiting, transformation, central API governance | Higher cost and more configuration; VNet mode needs planning | You need enterprise API governance or many integrations. |
| Azure Functions Premium | Good for code-first proxy logic, VNet integration, managed identity | Hosting/runtime behavior must be tuned for latency and scale | You want event/function style code with minimal container work. |
| App Service with VNet integration | Familiar web app hosting, deployment slots, easy operations | Outbound VNet/NAT behavior must be configured carefully; not as container-native | Your team already standardizes on App Service. |
| AKS | Maximum control and platform consistency for Kubernetes teams | Highest operational overhead | The customer already runs a Kubernetes platform. |
| Logic Apps Standard with VNet integration | Workflow runtime can be placed in an Azure networking model | Different architecture from Power Automate cloud flows; requires Standard hosting | The integration should be workflow-native but Azure-hosted. |
| Azure Firewall instead of NAT Gateway | Egress logging, FQDN filtering, policy, threat intelligence | More expensive and more operationally involved | The customer needs inspectable outbound policy, not only stable SNAT. |

## Customer Step-By-Step

### 1. Confirm The Required Decisions

Before deployment, the customer must choose:

| Decision | Customer input |
| --- | --- |
| Azure subscription and tenant | Where the Azure resources will be deployed. |
| Power Platform environment | Existing managed environment or a new environment. |
| Power Platform geography | Determines the required paired Azure regions. |
| Regional VNet address spaces | Must not overlap with existing networks. |
| Public egress strategy | NAT Gateway for fixed IP only, or Azure Firewall for inspection and policy. |
| Proxy runtime | Container Apps by default, or APIM/Functions/App Service/AKS/Logic Apps Standard. |
| AWS enforcement point | WAF, API Gateway resource policy, ALB, security group, firewall, or application allowlist. |

### 2. Configure Local Tools

Install or validate:

- Azure CLI
- PowerShell 7
- Power Platform CLI (`pac`)
- `jq`
- `zip`
- Docker tooling only if the customer wants to build images locally; the provided script uses ACR build.

Authenticate to Azure and Power Platform using the customer's tenant and environment.

### 3. Provide Customer Values

Copy [.env.example](.env.example), fill in customer-specific values, and export them in the shell that will run the scripts. Do not commit a populated `.env` file.

At minimum, provide:

```bash
export SUBSCRIPTION_ID='<azure-subscription-id>'
export TENANT_ID='<microsoft-entra-tenant-id>'
export POWER_PLATFORM_ENVIRONMENT_ID='<power-platform-environment-id>'
export RESOURCE_GROUP='<resource-group-name>'
export LOCATION='<primary-azure-region>'
export POLICY_NAME='<enterprise-policy-name>'
export POLICY_LOCATION='<power-platform-policy-location>'
```

### 4. Review Network Parameters

Edit [infra/main.parameters.json](infra/main.parameters.json) for the customer's naming prefix, regions, VNet address spaces, and delegated subnet prefixes.

The delegated Power Platform subnets and the Container Apps proxy subnets must be different subnets. Do not reuse the Power Platform delegated subnet for the Container Apps environment.

### 5. Deploy The Network And Enterprise Policy

Run provider registration and network deployment:

```bash
./scripts/00-prereqs.sh
./scripts/01-deploy-network.sh
```

Create the Power Platform enterprise policy:

```powershell
pwsh -NoProfile -File ./scripts/02-create-enterprise-policy.ps1 \
  -SubscriptionId "$SUBSCRIPTION_ID" \
  -TenantId "$TENANT_ID" \
  -ResourceGroupName "$RESOURCE_GROUP" \
  -PolicyName "$POLICY_NAME" \
  -PolicyLocation "$POLICY_LOCATION" \
  -NetworkOutputsPath '.azure/network-outputs.json'
```

Enable virtual network support for the target Power Platform environment:

```powershell
pwsh -NoProfile -File ./scripts/04-enable-subnet-injection.ps1 \
  -EnvironmentId "$POWER_PLATFORM_ENVIRONMENT_ID"
```

Validate the Azure side:

```bash
./scripts/05-verify-azure-network.sh
```

### 6. Deploy Regional Proxies

Run [scripts/10-deploy-container-apps-proxy.sh](scripts/10-deploy-container-apps-proxy.sh) once per required region. Set the `PROXY_*` variables for the region before each run.

Example shape:

```bash
export PROXY_RESOURCE_GROUP="$RESOURCE_GROUP"
export PROXY_LOCATION='<azure-region>'
export PROXY_VNET_NAME='<vnet-name>'
export PROXY_SUBNET_NAME='<container-apps-subnet-name>'
export PROXY_SUBNET_PREFIX='<container-apps-subnet-prefix>'
export PROXY_NAT_NAME='<nat-gateway-name>'
export PROXY_PUBLIC_IP_NAME='<nat-public-ip-resource-name>'
export PROXY_LOG_ANALYTICS_NAME='<log-analytics-workspace-name>'
export PROXY_CONTAINER_ENV_NAME='<container-apps-environment-name>'
export PROXY_CONTAINER_APP_NAME='<container-app-name>'
export PROXY_ACR_NAME='<globally-unique-acr-name>'
export PROXY_OUTPUT_PATH='.azure/container-apps-proxy-<region>.json'

./scripts/10-deploy-container-apps-proxy.sh
```

The script outputs the proxy URL and verifies `/health`, `/proxy/ipify`, and `/proxy/aws-checkip`.

### 7. Create Power Platform Connectors Or Restrict Built-In HTTP

Preferred Power Automate pattern:

```text
Power Automate flow
  -> approved custom connector for the regional proxy
  -> proxy
  -> NAT Gateway
  -> AWS
```

Alternative Power Automate pattern:

```text
Power Automate built-in HTTP action
  -> approved regional proxy URL only
  -> proxy
  -> NAT Gateway
  -> AWS
```

Do not approve this pattern as NAT-controlled:

```text
Power Automate built-in HTTP action
  -> AWS directly
```

It can work functionally while the destination sees a Microsoft-managed source IP instead of the customer NAT IP.

To generate and create/update the two proxy custom connectors from the deployed proxy hosts:

```bash
export NORTH_REGION_PROXY_HOST='<first-regional-proxy-host-or-url>'
export WEST_REGION_PROXY_HOST='<second-regional-proxy-host-or-url>'
export NORTH_REGION_CONNECTOR_DISPLAY_NAME='North Region NAT Proxy'
export WEST_REGION_CONNECTOR_DISPLAY_NAME='West Region NAT Proxy'

./scripts/12-create-proxy-connectors.sh
```

The script writes generated connector definitions under `.azure/generated-connectors`, which is ignored by Git.

### 8. Deploy Logic Apps Examples

For Logic Apps Consumption examples that call only approved proxies:

```bash
export LOGIC_APP_RESOURCE_GROUP="$RESOURCE_GROUP"
export NORTH_EUROPE_PROXY_URL='<first-regional-proxy-url>'
export WEST_EUROPE_PROXY_URL='<second-regional-proxy-url>'
export NORTH_EUROPE_WORKFLOW_NAME='<workflow-name-1>'
export WEST_EUROPE_WORKFLOW_NAME='<workflow-name-2>'

./scripts/11-deploy-logicapp-proxy-example.sh
```

For production Logic Apps, either enforce proxy-only HTTP targets or use Logic Apps Standard with VNet integration and its own NAT/Azure Firewall egress design.

### 9. Enforce The Boundary

Power Platform and Logic Apps enforcement is an architecture and governance task, not just a network setting.

| Layer | Required action |
| --- | --- |
| Power Platform DLP | Allow approved proxy connectors; block or isolate direct HTTP and unapproved connectors where possible. |
| Environment governance | Restrict who can create connectors, flows, connection references, and solutions. |
| Workflow review | Reject flows or Logic Apps that call AWS/public destinations directly. |
| Proxy security | Add APIM, OAuth, mTLS, managed identity, API keys, or equivalent production access control. |
| Azure governance | Use Azure Policy, IaC review, tags, and RBAC to control proxy/network changes. |
| AWS enforcement | Allow only the customer-approved NAT or firewall public IPs. Deny all other source IPs. |

### 10. Prove It

For every region and path, capture destination-observed evidence:

- Proxy response from `/proxy/aws-checkip`
- AWS endpoint logs or WAF/API Gateway/ALB logs
- Power Automate run history or custom connector test result
- Logic App run history when Logic Apps are in scope

The proof passes only when the destination sees the approved NAT or firewall public IP.

## Limitations

- NAT Gateway does not control traffic that is not sent from an associated Azure subnet.
- Power Automate built-in HTTP direct-to-AWS is not a NAT Gateway proof path.
- Managed connector paths can succeed while using Microsoft-managed egress IPs.
- The proxy is an explicit hop, not transparent interception.
- Customers must enforce DLP, environment controls, and AWS allowlisting to prevent bypass.
- Container Apps external ingress should be protected before production use.
- NAT Gateway gives fixed SNAT but does not provide FQDN filtering or detailed egress policy. Use Azure Firewall if those controls are required.
- Region pairing and Power Platform geography requirements must be reviewed for the customer's tenant.

## Cost Considerations

Costs vary by region and usage. Estimate with the Azure Pricing Calculator before production. The main cost drivers are:

| Resource | Cost driver | Notes |
| --- | --- | --- |
| NAT Gateway | Hourly charge plus processed data | One per egress subnet/region in this design. |
| Public IP | Hourly static IP charge | Required for stable allowlisting. |
| Container Apps | vCPU/memory, replicas, requests, environment profile | Keep minimum replicas low for proof; size for production latency and availability. |
| Log Analytics | Ingested logs and retention | Tune retention and sampling. |
| Container Registry | SKU and storage | Basic is usually enough for proof; production may require network/private access controls. |
| Logic Apps | Trigger/action executions | Consumption examples are inexpensive for proof but can grow with volume. |
| API Management or Azure Firewall, if used | Capacity/SKU/hourly and data processing | Higher cost, stronger governance and inspection. |

For proofs, delete unused resource groups and stop unused flows after capture. For production, budget for high availability, logging retention, monitoring, and security controls.

## Day 2 Operations

| Area | What to operate |
| --- | --- |
| Egress IP drift | Monitor NAT public IP resources and AWS allowlists. Treat public IP changes as a change-controlled event. |
| Proxy health | Monitor `/health`, Container Apps revision health, replica count, latency, and error rate. |
| Logs | Review Container Apps logs, Log Analytics retention, and failed upstream calls. |
| Security | Rotate proxy credentials, review DLP policies, audit connector and flow creators. |
| Cost | Review NAT Gateway data volume, Container Apps replica sizing, and Log Analytics ingestion. |
| Releases | Use Container Apps revisions for rollback. Promote image tags through environments. |
| Governance | Periodically search for direct HTTP calls to AWS/public endpoints and remove bypass paths. |
| Disaster recovery | Decide whether both paired regions are active/active, active/passive, or proof-only. |

## Repository Map

| Path | Purpose |
| --- | --- |
| [infra/main.bicep](infra/main.bicep) | Deploys paired VNets, delegated Power Platform subnets, NAT Gateways, public IPs, NSGs, and peering. |
| [proxy-endpoint](proxy-endpoint) | Container Apps proxy source code. |
| [scripts](scripts) | Customer-run automation. Values come from exported environment variables. |
| [connectors](connectors) | Custom connector OpenAPI definitions and API properties. Update hosts before customer use. |
| [docs/CUSTOMER-STEP-BY-STEP.md](docs/CUSTOMER-STEP-BY-STEP.md) | Detailed customer runbook. |
| [docs/REGIONAL-PROXY-ENFORCEMENT.md](docs/REGIONAL-PROXY-ENFORCEMENT.md) | Enforcement model and controls. |
| [docs/POWER-AUTOMATE-E2E-RESULTS.md](docs/POWER-AUTOMATE-E2E-RESULTS.md) | Validation example showing custom connector, built-in HTTP direct, and built-in HTTP via proxy behavior. |

## Public Repo Safety

- Do not commit populated `.env` files.
- Do not commit signed callback URLs, bearer tokens, client secrets, or generated deployment outputs.
- Treat files under `docs/evidence` as example validation captures. Replace them with customer-approved evidence before sharing externally.
- Review connector definitions and proxy hostnames before customer deployment.