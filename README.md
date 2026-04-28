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

- Azure CLI authenticated to the target subscription.
- GitHub CLI authenticated if you want to push the repository.
- PowerShell 7 for the `Microsoft.PowerPlatform.EnterprisePolicies` module.
- Power Platform CLI (`pac`) for environment creation.
- Power Platform administrator role, Dynamics 365 administrator role, Global administrator role, or an existing eligible Europe environment created by a tenant admin.
- Azure permissions to create resource groups, VNets, public IPs, NAT Gateways, and enterprise policies.
- Capacity/license allowing a Managed Environment with Dataverse.

## Deployment Flow

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

See [docs/PROOF-GUIDE.md](docs/PROOF-GUIDE.md) for the step-by-step screenshot and evidence checklist.

## Important Notes

A normal Power Automate built-in HTTP action is not a reliable proof path. Microsoft documentation states that built-in HTTP actions can egress from Logic Apps or Power Automate service IP ranges. For this proof, use a VNet-supported custom connector or Dataverse plug-in path.

These resources incur Azure cost while deployed, especially NAT Gateway and static public IP resources. Delete the resource group after the proof if you no longer need it.
