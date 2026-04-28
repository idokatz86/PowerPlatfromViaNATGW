# End-to-End Proof Guide

This guide records the exact screenshots and evidence needed to prove that a Power Platform environment in the Europe geography exits the internet through the Azure NAT Gateway public IP attached to the delegated subnet.

For customer-facing scope boundaries, read [LIMITATIONS.md](LIMITATIONS.md). The proof is scoped to VNet-supported Power Platform workload paths, such as the custom connector path used in this repo.

## Evidence Checklist

Capture each screenshot into `docs/images/` using the suggested file names.

1. `01-azure-account.png` - Azure CLI or Azure portal showing subscription `<azure-subscription-id>`.
2. `02-resource-group.png` - Resource group `<resource-group-name>`.
3. `03-vnets.png` - Two VNets: `<west-region-vnet-name>` in West Europe and `<north-region-vnet-name>` in North Europe.
4. `04-delegated-subnet-weu.png` - West Europe subnet delegated to `Microsoft.PowerPlatform/enterprisePolicies` with NAT Gateway associated.
5. `05-delegated-subnet-neu.png` - North Europe subnet delegated to `Microsoft.PowerPlatform/enterprisePolicies` with NAT Gateway associated.
6. `06-nat-public-ip.png` - NAT Gateway outbound IP page showing the static public IP address.
7. `07-enterprise-policy.png` - Power Platform enterprise policy resource showing location `europe` and both VNet/subnet references.
8. `08-power-platform-env.png` - Power Platform admin center environment details showing region Europe and Managed Environment enabled.
9. `09-vnet-enabled.png` - Environment linked to the enterprise policy / virtual network support enabled.
10. `10-demo-call.png` - Demo app, flow, custom connector, or Dataverse plug-in triggering the outbound request.
11. `11-destination-log.png` - Destination endpoint log showing the inbound source IP.
12. `12-ip-match.png` - Side-by-side proof that destination-observed source IP equals the NAT Gateway public IP.
13. `13-second-nat-ip-match.png` - Separate proof row for the second paired-region NAT Gateway public IP, if the Power Platform runtime executes from the paired region.

## Validation Commands

Run these commands from the repository root after deployment.

```bash
./scripts/05-verify-azure-network.sh
```

Expected result:

- Both delegated subnets show `Microsoft.PowerPlatform/enterprisePolicies`.
- Both delegated subnets show a NAT Gateway resource ID.
- The static public IPs match the NAT Gateway outbound IP configuration.

Validated NAT public IPs for this deployment:

- West Europe: `<west-region-nat-ip>`
- North Europe: `<north-region-nat-ip>`

Enterprise policy ARM ID:

```text
/subscriptions/<azure-subscription-id>/resourceGroups/<resource-group-name>/providers/Microsoft.PowerPlatform/enterprisePolicies/<enterprise-policy-name>
```

## Current State

Subnet injection is enabled for Power Platform environment `<power-platform-environment-id>` at `https://<power-platform-environment-url>/`. A VNet-supported custom connector test has proven the North Europe NAT Gateway path. The West Europe paired-region NAT proof is still pending because the test runs executed from the North Europe runtime path.

## Proof Workload

Use a Power Platform workload that is supported by virtual network support. Preferred options:

1. A custom connector in the VNet-enabled environment that calls a public request-inspection endpoint.
2. A Dataverse plug-in that sends an HTTPS request to a public request-inspection endpoint.

Avoid using a plain Power Automate built-in HTTP action as the primary proof. Microsoft documentation notes that built-in HTTP actions can egress from Logic Apps or Power Automate service IPs, which makes the result ambiguous.

## Destination Endpoint Options

The cleanest proof uses a destination endpoint you control, such as an Azure Function or App Service, that records request headers and the connection source IP. Public echo services can be useful during iteration, but controlled logs are better evidence.

The active destination endpoint is an Azure Web App in a separate resource group and a region outside West Europe/North Europe:

| Item | Value |
| --- | --- |
| Resource group | `<inspection-resource-group-name>` |
| Region | `francecentral` |
| Web App | `<inspection-web-app-name>` |
| URL | `https://<inspection-web-app-host>/inspect` |

Use the custom connector proof steps in [CUSTOM-CONNECTOR-PROOF.md](CUSTOM-CONNECTOR-PROOF.md). The OpenAPI definition is [nat-proof-connector.swagger.json](../connectors/nat-proof-connector.swagger.json).

The destination log must include:

- Timestamp.
- Request path or correlation ID.
- Observed client/source IP.
- Request headers such as `x-forwarded-for` if present.

## Final Proof Statement

When complete, add the observed values below:

| Item | Value |
| --- | --- |
| West Europe NAT Gateway public IP | `<west-region-nat-ip>` |
| North Europe NAT Gateway public IP | `<north-region-nat-ip>` |
| Power Platform environment ID | `<power-platform-environment-id>` |
| Enterprise policy ARM ID | `/subscriptions/<azure-subscription-id>/resourceGroups/<resource-group-name>/providers/Microsoft.PowerPlatform/enterprisePolicies/<enterprise-policy-name>` |
| Destination observed source IP | `<north-region-nat-ip>` for run `powerplatform-test-009` |
| Result | North Europe NAT Gateway proof succeeded. West Europe proof pending. |

## Two NAT Gateway Proof Requirement

To prove both NAT Gateways, capture two separate successful Power Platform custom connector calls to the inspection endpoint:

| Required proof row | Expected destination-observed source IP | Status |
| --- | --- | --- |
| West Europe delegated subnet egress | `<west-region-nat-ip>` | Pending |
| North Europe delegated subnet egress | `<north-region-nat-ip>` | Proven by `powerplatform-test-009` |

A single connector call only proves the regional Power Platform runtime path that handled that call. If the environment only executes from one region during normal operation, the second NAT Gateway proof requires a paired-region execution path, failover event, or support-guided validation. Do not mark both as proven until the destination endpoint actually observes both public IPs.
