# PowerPlatfromViaNATGW Deployment Plan

Status: Azure network, enterprise policy, and Power Platform subnet injection deployed in the M365x06311682 tenant

## Goal
Create a public GitHub repository and an end-to-end proof that a Power Platform environment using virtual network support exits the internet through an Azure NAT Gateway public IP attached to the delegated subnet.

The intended enforcement mechanism is subnet-level NAT Gateway association. For Power Platform VNet-supported workloads injected into the delegated subnet, Azure NAT Gateway becomes the outbound path for internet-destined traffic from that subnet. NSGs alone are not sufficient because Microsoft documentation notes that traffic can otherwise still egress from Power Platform owned IP addresses.

## Scope
- Create or connect to GitHub repository: `PowerPlatfromViaNATGW`.
- Create Azure networking resources: resource group, VNet, delegated subnet, NAT Gateway, public IP, and required network configuration.
- Create or configure a Power Platform environment for virtual network support.
- Build a demo proof path where outbound traffic from Power Platform reaches an internet endpoint and the destination observes the NAT Gateway public IP.
- Capture evidence and screenshots in a step-by-step guide.

## Current Assumptions
- Public repository is acceptable.
- The active implementation uses tenant `0bf51094-2478-4975-9cbc-61fb8c649e62` and subscription `3cce1c0d-4798-48da-92cd-daaf643e932c`.
- Power Platform environment `f021725d-8eeb-e31b-9427-7334c58a3a5b` is an existing Sandbox environment in Europe.
- Power Platform tenant permissions and licenses must support Managed Environments and virtual network support.

## Current State
- GitHub repository created and scaffold pushed.
- Azure resource group, paired regional VNets, delegated subnets, NAT Gateways, and static public IPs deployed in subscription `3cce1c0d-4798-48da-92cd-daaf643e932c`.
- Power Platform enterprise policy `ppnatgw-europe-policy` created in location `europe`.
- Existing Power Platform Sandbox environment `f021725d-8eeb-e31b-9427-7334c58a3a5b` at `https://orgdb8a7af5.crm4.dynamics.com/` is visible to PAC.
- Subnet injection was enabled successfully for environment `f021725d-8eeb-e31b-9427-7334c58a3a5b`.

## Architecture
- Power Platform geography: Europe.
- Required Azure regions for Europe: `westeurope` and `northeurope`.
- Enterprise policy location: `europe`.
- Create one delegated subnet per regional VNet with delegation `Microsoft.PowerPlatform/enterprisePolicies`.
- Attach one Azure NAT Gateway and one Standard static public IP to each delegated subnet.
- Peer the two regional VNets to match the Microsoft sample topology for paired regions.
- Validate egress using a VNet-supported custom connector or Dataverse plug-in, not a plain built-in Power Automate HTTP action.

## Execution Plan
1. Confirm GitHub identity and create public repository.
2. Confirm Azure subscription and preferred region.
3. Verify required CLIs/modules and Power Platform permissions.
4. Create Azure VNet, delegated subnet, NAT Gateway, and Public IP.
5. Use the existing eligible Europe Sandbox environment.
6. Configure Power Platform virtual network support for the environment.
7. Deploy or configure a demo workload to call an external request-inspection endpoint.
8. Validate outbound source IP equals NAT Gateway public IP.
9. Capture screenshots and write end-to-end guide.

## Validation Plan
- Azure deployment validation/what-if before changes where applicable.
- Verify subnet delegation and NAT Gateway association.
- Verify Power Platform environment VNet binding.
- Verify outbound request source IP from external destination logs/echo service.
- Compare destination-observed source IP with the NAT Gateway public IP for the regional subnet used by the workload.

## Risks / Blockers
- Power Platform VNet support may require specific tenant capabilities, regions, environment types, and admin privileges.
- Power Platform environment creation/configuration is not fully covered by Azure Resource Manager and requires Power Platform Admin PowerShell and/or PAC CLI.
- Built-in Power Automate HTTP actions are not a reliable NAT proof because Microsoft documentation says those actions can egress via Logic Apps or Power Automate service IPs.
- Proof may require a reachable external endpoint that records inbound source IP.

## Section 7: Validation Proof

- Azure CLI authenticated as `ido@M365x06311682.onmicrosoft.com`.
- Subscription: `3cce1c0d-4798-48da-92cd-daaf643e932c`.
- Tenant: `0bf51094-2478-4975-9cbc-61fb8c649e62`.
- Resource group: `rg-ppnatgw-demo`.
- West Europe NAT public IP: `51.124.38.135`.
- North Europe NAT public IP: `20.166.89.8`.
- Enterprise policy ARM ID: `/subscriptions/3cce1c0d-4798-48da-92cd-daaf643e932c/resourceGroups/rg-ppnatgw-demo/providers/Microsoft.PowerPlatform/enterprisePolicies/ppnatgw-europe-policy`.
- Power Platform environment ID: `f021725d-8eeb-e31b-9427-7334c58a3a5b`.
- Environment URL: `https://orgdb8a7af5.crm4.dynamics.com/`.
- `Enable-SubnetInjection` completed successfully for the environment.
- Destination-observed source IP proof is pending.
