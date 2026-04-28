# Deployment Plan: Azure Container Apps NAT Proxy Proof

Status: Validated

## 1. Goal

Deploy customer-controlled Azure Container Apps proxies that call external IP echo services from inside the existing North Europe and West Europe VNets with NAT Gateway egress, then prove the observed public source IP for each region.

## 2. Scope

- Add a small proxy API to this repository.
- Deploy it to Azure Container Apps.
- Place one Container Apps environment in a new dedicated subnet inside the existing `<north-region-vnet-name>` VNet.
- Place a second Container Apps environment in a new dedicated subnet inside the existing `<west-region-vnet-name>` VNet.
- Delegate that subnet to `Microsoft.App/environments`.
- Attach the existing North Europe NAT Gateway `<north-region-nat-gateway-name>` to the North Europe Container Apps infrastructure subnet.
- Attach the existing West Europe NAT Gateway `<west-region-nat-gateway-name>` to the West Europe Container Apps infrastructure subnet.
- Test these outbound calls through the proxy:
  - `https://api.ipify.org/?format=json`
  - `https://checkip.amazonaws.com/`
- Capture evidence and update docs.

## 3. Azure Context

- Subscription: `<azure-subscription-id>`
- Tenant: `<microsoft-entra-tenant-id>`
- Resource group: `<resource-group-name>`
- North Europe region: `northeurope`
- North Europe VNet: `<north-region-vnet-name>`
- North Europe Container Apps subnet: `snet-containerapps-proxy` (`10.43.10.0/23`)
- North Europe NAT Gateway: `<north-region-nat-gateway-name>`
- North Europe NAT public IP: `<north-region-nat-ip>`
- West Europe region: `westeurope`
- West Europe VNet: `<west-region-vnet-name>`
- West Europe Container Apps subnet: `snet-containerapps-proxy` (`10.42.10.0/23`)
- West Europe NAT Gateway: `<west-region-nat-gateway-name>`
- West Europe NAT public IP: `<west-region-nat-ip>`

## 4. Architecture

```text
Power Platform, Logic App, or browser test
  -> regional Azure Container Apps proxy public endpoint
  -> Container Apps workload subnet in existing regional VNet
  -> existing regional NAT Gateway public IP
  -> api.ipify.org / checkip.amazonaws.com
```

## 5. Deployment Steps

- Build proxy container image.
- Create resource group.
- Add new Container Apps delegated subnets to the existing North Europe and West Europe VNets.
- Attach the existing regional NAT Gateways to those subnets.
- Create Log Analytics workspaces and Container Apps environments.
- Deploy Container Apps.
- Verify `/health`, `/proxy/ipify`, and `/proxy/aws-checkip`.
- Deploy Logic App examples that call only the regional proxy endpoints.

## 6. Validation Proof

Validated on 2026-04-28.

North Europe Container Apps proxy:

- URL: `https://<north-region-proxy-host>`
- NAT Gateway public IP: `<north-region-nat-ip>`
- `/proxy/ipify` observed `<north-region-nat-ip>`, `natProof: true`
- `/proxy/aws-checkip` observed `<north-region-nat-ip>`, `natProof: true`
- Evidence: `docs/evidence/containerapps-proxy-neu-2026-04-28.json`

West Europe Container Apps proxy:

- URL: `https://<west-region-proxy-host>`
- NAT Gateway public IP: `<west-region-nat-ip>`
- `/proxy/ipify` observed `<west-region-nat-ip>`, `natProof: true`
- `/proxy/aws-checkip` observed `<west-region-nat-ip>`, `natProof: true`
- Evidence: `docs/evidence/containerapps-proxy-weu-2026-04-28.json`

Logic App examples:

- North Europe workflow `<north-region-container-app-name>-proof-neu-la` called only the North Europe proxy and observed `<north-region-nat-ip>`.
- West Europe workflow `<north-region-container-app-name>-proof-weu-la` called only the West Europe proxy and observed `<west-region-nat-ip>`.
- Evidence: `docs/evidence/logicapp-proxy-neu-2026-04-28.json` and `docs/evidence/logicapp-proxy-weu-2026-04-28.json`.

## 7. Deployment Results

Regional Container Apps proxies and Logic App examples deployed and validated.# PowerPlatfromViaNATGW Deployment Plan

Status: Azure network, enterprise policy, and Power Platform subnet injection deployed in the <tenant-display-name> tenant

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
- The active implementation uses tenant `<microsoft-entra-tenant-id>` and subscription `<azure-subscription-id>`.
- Power Platform environment `<power-platform-environment-id>` is an existing Sandbox environment in Europe.
- Power Platform tenant permissions and licenses must support Managed Environments and virtual network support.

## Current State
- GitHub repository created and scaffold pushed.
- Azure resource group, paired regional VNets, delegated subnets, NAT Gateways, and static public IPs deployed in subscription `<azure-subscription-id>`.
- Power Platform enterprise policy `<enterprise-policy-name>` created in location `europe`.
- Existing Power Platform Sandbox environment `<power-platform-environment-id>` at `https://<power-platform-environment-url>/` is visible to PAC.
- Subnet injection was enabled successfully for environment `<power-platform-environment-id>`.

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

- Azure CLI authenticated as `<user-upn>`.
- Subscription: `<azure-subscription-id>`.
- Tenant: `<microsoft-entra-tenant-id>`.
- Resource group: `<resource-group-name>`.
- West Europe NAT public IP: `<west-region-nat-ip>`.
- North Europe NAT public IP: `<north-region-nat-ip>`.
- Enterprise policy ARM ID: `/subscriptions/<azure-subscription-id>/resourceGroups/<resource-group-name>/providers/Microsoft.PowerPlatform/enterprisePolicies/<enterprise-policy-name>`.
- Power Platform environment ID: `<power-platform-environment-id>`.
- Environment URL: `https://<power-platform-environment-url>/`.
- `Enable-SubnetInjection` completed successfully for the environment.
- Destination-observed source IP proof is pending.
