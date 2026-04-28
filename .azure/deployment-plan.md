# PowerPlatfromViaNATGW Deployment Plan

Status: Approved for scaffold; pending approval for paid Azure resource creation

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
- The existing signed-in Microsoft/Azure account should be used.
- The subscription and region must be confirmed before resource creation.
- Power Platform tenant permissions and licenses must support Managed Environments and virtual network support.

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
5. Configure Power Platform virtual network support for the environment.
6. Deploy or configure a demo app/flow to call an external echo endpoint.
7. Validate outbound source IP equals NAT Gateway public IP.
8. Capture screenshots and write end-to-end guide.

## Validation Plan
- Azure deployment validation/what-if before changes where applicable.
- Verify subnet delegation and NAT Gateway association.
- Verify Power Platform environment VNet binding.
- Verify outbound request source IP from external destination logs/echo service.
- Compare destination-observed source IP with the NAT Gateway public IP for the regional subnet used by the workload.

## Risks / Blockers
- Power Platform VNet support may require specific tenant capabilities, regions, environment types, and admin privileges.
- Power Platform environment creation/configuration is not fully covered by Azure Resource Manager and requires Power Platform Admin PowerShell and/or PAC CLI. Local machine currently has Azure CLI and GitHub CLI, but not PowerShell, PAC CLI, or dotnet.
- Built-in Power Automate HTTP actions are not a reliable NAT proof because Microsoft documentation says those actions can egress via Logic Apps or Power Automate service IPs.
- Proof may require a reachable external endpoint that records inbound source IP.

## Section 7: Validation Proof
Pending.
