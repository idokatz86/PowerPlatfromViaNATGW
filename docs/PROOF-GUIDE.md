# End-to-End Proof Guide

This guide records the exact screenshots and evidence needed to prove that a Power Platform environment in the Europe geography exits the internet through the Azure NAT Gateway public IP attached to the delegated subnet.

## Evidence Checklist

Capture each screenshot into `docs/images/` using the suggested file names.

1. `01-azure-account.png` - Azure CLI or Azure portal showing subscription `152f2bd5-8f6b-48ba-a702-21a23172a224`.
2. `02-resource-group.png` - Resource group `rg-ppnatgw-demo`.
3. `03-vnets.png` - Two VNets: `ppnatgw-vnet-weu` in West Europe and `ppnatgw-vnet-neu` in North Europe.
4. `04-delegated-subnet-weu.png` - West Europe subnet delegated to `Microsoft.PowerPlatform/enterprisePolicies` with NAT Gateway associated.
5. `05-delegated-subnet-neu.png` - North Europe subnet delegated to `Microsoft.PowerPlatform/enterprisePolicies` with NAT Gateway associated.
6. `06-nat-public-ip.png` - NAT Gateway outbound IP page showing the static public IP address.
7. `07-enterprise-policy.png` - Power Platform enterprise policy resource showing location `europe` and both VNet/subnet references.
8. `08-power-platform-env.png` - Power Platform admin center environment details showing region Europe and Managed Environment enabled.
9. `09-vnet-enabled.png` - Environment linked to the enterprise policy / virtual network support enabled.
10. `10-demo-call.png` - Demo app, flow, custom connector, or Dataverse plug-in triggering the outbound request.
11. `11-destination-log.png` - Destination endpoint log showing the inbound source IP.
12. `12-ip-match.png` - Side-by-side proof that destination-observed source IP equals the NAT Gateway public IP.

## Validation Commands

Run these commands from the repository root after deployment.

```bash
./scripts/05-verify-azure-network.sh
```

Expected result:

- Both delegated subnets show `Microsoft.PowerPlatform/enterprisePolicies`.
- Both delegated subnets show a NAT Gateway resource ID.
- The static public IPs match the NAT Gateway outbound IP configuration.

## Proof Workload

Use a Power Platform workload that is supported by virtual network support. Preferred options:

1. A custom connector in the VNet-enabled environment that calls a public request-inspection endpoint.
2. A Dataverse plug-in that sends an HTTPS request to a public request-inspection endpoint.

Avoid using a plain Power Automate built-in HTTP action as the primary proof. Microsoft documentation notes that built-in HTTP actions can egress from Logic Apps or Power Automate service IPs, which makes the result ambiguous.

## Destination Endpoint Options

The cleanest proof uses a destination endpoint you control, such as an Azure Function or App Service, that records request headers and the connection source IP. Public echo services can be useful during iteration, but controlled logs are better evidence.

The destination log must include:

- Timestamp.
- Request path or correlation ID.
- Observed client/source IP.
- Request headers such as `x-forwarded-for` if present.

## Final Proof Statement

When complete, add the observed values below:

| Item | Value |
| --- | --- |
| West Europe NAT Gateway public IP | Pending |
| North Europe NAT Gateway public IP | Pending |
| Power Platform environment ID | Pending |
| Enterprise policy ARM ID | Pending |
| Destination observed source IP | Pending |
| Result | Pending |
