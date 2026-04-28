# PowerPlatfromViaNATGW

End-to-end deployment assets for proving that a Power Platform environment using virtual network support exits to the internet through an Azure NAT Gateway public IP.

> The repository name intentionally follows the requested spelling: `PowerPlatfromViaNATGW`.

## Target

- Azure subscription: `3cce1c0d-4798-48da-92cd-daaf643e932c`
- Azure tenant: `0bf51094-2478-4975-9cbc-61fb8c649e62`
- Power Platform environment ID: `f021725d-8eeb-e31b-9427-7334c58a3a5b`
- Power Platform environment URL: `https://orgdb8a7af5.crm4.dynamics.com/`
- Power Platform geography: Europe
- Required Azure regions for Europe: `westeurope`, `northeurope`
- Enterprise policy location: `europe`

## Architecture

The Europe geography requires paired virtual networks/subnets. This repo creates:

- Resource group `rg-ppnatgw-demo`
- West Europe VNet `ppnatgw-vnet-weu`
- North Europe VNet `ppnatgw-vnet-neu`
- One delegated `/24` subnet per VNet: `snet-powerplatform-delegated`
- NAT Gateway on each delegated subnet
- Standard static public IP for each NAT Gateway
- VNet peering between the two regional VNets
- Power Platform enterprise policy and environment linkage scripts

## Why Two NAT Gateways?

Microsoft maps the Power Platform Europe region to both `westeurope` and `northeurope`. The enterprise policy for a two-region geography references both delegated subnets. To keep outbound egress deterministic from either regional runtime, each delegated subnet has its own NAT Gateway and static public IP.

## How Egress Is Forced

For VNet-supported Power Platform workloads, the workload container is injected into the delegated subnet and receives an IP from that subnet. Azure NAT Gateway is associated directly to that delegated subnet, so internet-destined traffic from the injected workload uses the NAT Gateway as the outbound path and is source-translated to the NAT Gateway public IP.

This only proves the VNet-injected execution path. A regular built-in Power Automate HTTP action can still egress from Logic Apps or Power Automate service IPs, so it must not be used as the final NAT proof.

## Prerequisites

### Power Platform Environment And Licensing

- The Power Platform environment must be a **Managed Environment**. Power Platform virtual network support cannot be enabled on a non-managed environment.
- The environment must be in a Power Platform geography that supports virtual network support. This demo uses Europe, which maps to Azure `westeurope` and `northeurope`.
- The Azure subscription used for the VNets, delegated subnets, and enterprise policy must be associated with the same Power Platform tenant/geography requirements.
- The environment needs Dataverse and must be eligible for custom connectors or Dataverse plug-ins, depending on the proof workload.
- Users in the environment where virtual network support is enabled need licensing that includes the required Power Platform security/governance entitlement. Microsoft documents VNet support licensing under Power Platform security and governance licensing requirements. Examples include Microsoft 365 or Office 365 A5/E5/G5, Microsoft 365 A5/E5/F5/G5 Compliance, Microsoft 365 F5 Security & Compliance, Microsoft 365 E5/F5/G5 Information Protection and Governance, or Microsoft 365 E5/F5/G5 Insider Risk Management.
- Managed Environments entitlement is included with licenses such as Power Apps Premium, Power Apps per app, Power Automate Premium, Power Automate Process, Power Automate Hosted Process, Power Automate per user/per flow, Microsoft Copilot Studio, Power Pages user licenses, and Dynamics 365 Premium/Enterprise/Team Members licenses. Confirm the exact customer entitlement with the customer's licensing team before production rollout.

### Roles And Permissions

- Azure permissions to create resource groups, VNets, subnets, subnet delegations, public IPs, NAT Gateways, VNet peerings, App Service resources, and Power Platform enterprise policy resources.
- Azure Network Contributor or equivalent custom role is recommended for the networking deployment.
- Power Platform administrator, Dynamics 365 administrator, or Global administrator role is required to create/bind the Power Platform enterprise policy and enable virtual network support.
- Environment admin rights are required for the target environment and custom connector setup.
- AWS permissions are required only if the customer will update AWS allowlists, WAF rules, API Gateway resource policies, security groups, or deploy the optional MCP ingress probe.

### Local Tooling

- Azure CLI authenticated to the target subscription.
- PowerShell 7 for the `Microsoft.PowerPlatform.EnterprisePolicies` module.
- Power Platform CLI (`pac`) authenticated to the target tenant/environment.
- `zip` and `jq` for packaging and validation scripts.
- GitHub CLI authenticated only if you want to create or push the repository from the command line.

## Deployment Flow

For a customer-facing walkthrough, start with [docs/CUSTOMER-STEP-BY-STEP.md](docs/CUSTOMER-STEP-BY-STEP.md).

To run the deployment as one guided automation, export the required values and run:

```bash
export SUBSCRIPTION_ID='<subscription-id>'
export TENANT_ID='<tenant-id>'
export POWER_PLATFORM_ENVIRONMENT_ID='<environment-id>'
./scripts/09-run-customer-automation.sh
```

The individual steps are listed below for review and troubleshooting.

```bash
./scripts/00-prereqs.sh
./scripts/01-deploy-network.sh
```

Then create the enterprise policy:

```powershell
./scripts/02-create-enterprise-policy.ps1
```

Create a Power Platform environment if one does not already exist:

```bash
./scripts/03-create-power-platform-environment.sh
```

This deployment now uses an existing Sandbox environment in the same tenant. If you need to recreate the environment later, use the values in [docs/ADMIN-HANDOFF.md](docs/ADMIN-HANDOFF.md).

Enable virtual network support for the environment:

```powershell
./scripts/04-enable-subnet-injection.ps1 -EnvironmentId 'f021725d-8eeb-e31b-9427-7334c58a3a5b'
```

Validate Azure networking:

```bash
./scripts/05-verify-azure-network.sh
```

## Proof

Use a VNet-supported Power Platform custom connector or Dataverse plug-in to call a request-inspection endpoint. The destination must observe the same source IP as the NAT Gateway public IP for the regional subnet used by the workload.

The active inspection endpoint is deployed as an Azure Web App outside the Power Platform network resource group and outside West Europe/North Europe:

```text
https://ppnatgw-inspect-frc-06311682.azurewebsites.net/inspect
```

Use [docs/CUSTOM-CONNECTOR-PROOF.md](docs/CUSTOM-CONNECTOR-PROOF.md) and [connectors/nat-proof-connector.swagger.json](connectors/nat-proof-connector.swagger.json) for the custom connector proof path.

Confirmed result: Power Platform custom connector run `powerplatform-test-009` exited through the North Europe NAT Gateway public IP `20.166.89.8`. See [docs/NAT-PROOF-RESULTS.md](docs/NAT-PROOF-RESULTS.md).

See [docs/PROOF-GUIDE.md](docs/PROOF-GUIDE.md) for the step-by-step screenshot and evidence checklist.

## Architecture And Flow

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) describes the deployed Azure/Power Platform architecture.
- [docs/APPLICATION-FLOW.md](docs/APPLICATION-FLOW.md) describes the runtime request flow and proof flow.
- [docs/AWS-MCP-INTEGRATION.md](docs/AWS-MCP-INTEGRATION.md) explains how to connect the final Power App/custom connector flow to an AWS-hosted MCP endpoint and what AWS must allow.
- [docs/LIMITATIONS.md](docs/LIMITATIONS.md) states the customer-facing limitations and expectations.
- [docs/SCENARIOS.md](docs/SCENARIOS.md) lists working scenarios versus not working or not guaranteed scenarios.
- [docs/API-IPIFY-PROOF.md](docs/API-IPIFY-PROOF.md) shows how to interpret an `api.ipify.org` proof response. In the captured demo, `api.ipify.org` returned `20.86.93.37`, so it is documented as **not a valid NAT Gateway proof** for this run.
- [docs/CONNECTOR-GATEWAY-BEHAVIOR.md](docs/CONNECTOR-GATEWAY-BEHAVIOR.md) explains why connector tests can succeed while still showing a Microsoft-managed egress IP instead of the NAT Gateway IP.
- [docs/AWS-CHECKIP-PROOF.md](docs/AWS-CHECKIP-PROOF.md) records the AWS-hosted `checkip.amazonaws.com` test. It also returned `20.86.93.37`, so AWS-side allowlisting must be validated with destination logs before assuming the NAT Gateway IPs are observed.

## AWS MCP Diagnostic Tool

If the final AWS MCP call fails, use [tools/mcp-ingress-probe](tools/mcp-ingress-probe) as a temporary AWS-side diagnostic service. It returns the source IP and forwarding headers seen by the AWS ingress path, which helps separate Azure/Power Platform egress issues from AWS WAF, security group, API Gateway, ALB, or application allowlist issues.

## Important Notes

Read [docs/LIMITATIONS.md](docs/LIMITATIONS.md) before using this design with a customer. The short version is below.
For a practical customer decision matrix, read [docs/SCENARIOS.md](docs/SCENARIOS.md).

The successful proof in this repository used a Power Platform custom connector, not the normal built-in Power Automate HTTP action.

This distinction matters:

| Workload path | Can this design force egress through the customer NAT Gateway? | Notes |
| --- | --- | --- |
| VNet-supported Power Platform custom connector | Yes | Proven by run `powerplatform-test-009`, where the destination observed `20.166.89.8`. |
| Dataverse plug-in using the VNet-supported path | Yes, expected | Use the same destination-side proof pattern to validate. |
| Built-in Power Automate HTTP action | No, not reliably | It can egress from Microsoft-managed Power Automate or Logic Apps infrastructure instead of the delegated subnet. |
| Built-in Logic Apps action | No, not by this Power Platform VNet injection design | Logic Apps has its own networking patterns; this repo does not force Logic Apps egress through this NAT Gateway. |

For the customer AWS MCP scenario, the recommended pattern is:

```text
Power App / Power Automate flow
	-> VNet-supported custom connector
	-> Power Platform delegated subnet
	-> Azure NAT Gateway public IP
	-> AWS-hosted MCP endpoint
```

The pattern to avoid for deterministic NAT egress is:

```text
Power Automate built-in HTTP action
	-> AWS-hosted MCP endpoint
```

That path does not prove or guarantee egress from the Azure NAT Gateway public IP.

These resources incur Azure cost while deployed, especially NAT Gateway and static public IP resources. Delete the resource group after the proof if you no longer need it.
